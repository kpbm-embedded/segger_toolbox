#!/usr/bin/env python3
"""cmsim: run a Cortex-M ELF without a probe and look at it the way SEGGER's host tools do.

Used by the examples and templates of 32_12_segger (run inside `./segger-box shell` or `run`).
It is a test aid, not a board model: flash and RAM come from the ELF's load segments (plus
--ram for the stack), there are no peripherals and no interrupts. What it does model:

  * SEGGER RTT: finds the control block (symbol _SEGGER_RTT, else the "SEGGER RTT" ID in RAM),
    drains the up buffers and fills down buffers like J-Link does (read/write offsets).
  * ITM stimulus ports (SWO): writes to 0xE0000000 + 4*n are captured per port.
  * DWT->CYCCNT counts executed instructions (timestamps for SystemView).
  * a GDB remote-protocol server (`gdbserver`) with J-Link style `monitor` commands and the
    RTT telnet port (like JLinkGDBServer: 2331 for GDB, 19021 for RTT), so GDB scripts and
    RTT clients can be tested against the simulator.

Commands:
  cmsim.py run ELF [--max-insn N] [--down TEXT] [--down-after TEXT] [--channel N] [--itm] [--json]
  cmsim.py info ELF                      RTT control block, vector table, load segments
  cmsim.py gdbserver ELF [--port 2331] [--rtt-port 19021] [--max-insn N]
  cmsim.py ihex FILE.hex                 print the address ranges of an Intel HEX file
Exit codes: 0 ok (firmware reached BKPT #0 or the instruction budget with --allow-timeout),
1 firmware fault / BKPT #n>0 / no RTT block when asked, 2 usage error.
"""
import argparse
import json
import os
import socket
import struct
import sys
import threading

from elftools.elf.elffile import ELFFile
from unicorn import (UC_ARCH_ARM, UC_HOOK_INTR, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_HOOK_CODE,
                     UC_MODE_MCLASS, UC_MODE_THUMB, Uc, UcError)
from unicorn.arm_const import (UC_ARM_REG_LR, UC_ARM_REG_PC, UC_ARM_REG_R0, UC_ARM_REG_SP, UC_ARM_REG_XPSR)

PAGE = 0x1000
PPB_BASE, PPB_SIZE = 0xE0000000, 0x100000
ITM_PORTS = 0xE0000000          # 32 stimulus ports, 4 bytes each
DWT_CYCCNT = 0xE0001004
RTT_ID = b"SEGGER RTT"
DEBUG = bool(os.environ.get("CMSIM_DEBUG"))


def align_down(x, a=PAGE):
    return x & ~(a - 1)


def align_up(x, a=PAGE):
    return (x + a - 1) & ~(a - 1)


class Firmware:
    """ELF load segments, symbols and the vector table."""

    def __init__(self, path):
        self.path = path
        self.segments = []      # (load address, data, memsize)
        self.symbols = {}
        with open(path, "rb") as f:
            elf = ELFFile(f)
            if elf["e_machine"] != "EM_ARM":
                raise SystemExit(f"cmsim: {path} is not an Arm ELF ({elf['e_machine']})")
            for seg in elf.iter_segments():
                if seg["p_type"] == "PT_LOAD" and seg["p_memsz"]:
                    self.segments.append((seg["p_paddr"], seg.data(), seg["p_memsz"], seg["p_vaddr"]))
            symtab = elf.get_section_by_name(".symtab")
            if symtab:
                for s in symtab.iter_symbols():
                    if s.name:
                        self.symbols[s.name] = (s["st_value"], s["st_size"])
            self.entry = elf["e_entry"]
            vt = next((elf.get_section_by_name(n) for n in (".isr_vector", ".vectors", ".vector_table")
                       if elf.get_section_by_name(n)), None)
            self.vector_base = vt["sh_addr"] if vt else min(p for p, d, m, v in self.segments if d)

    def sym(self, name):
        v = self.symbols.get(name)
        return v[0] if v else None


class Sim:
    """unicorn Cortex-M with RTT, ITM and CYCCNT."""

    def __init__(self, fw, ram=None, also=()):
        self.fw = fw
        extra = [seg for f in also for seg in Firmware(f).segments]     # more images (bootloader + app)
        self.uc = Uc(UC_ARCH_ARM, UC_MODE_THUMB | UC_MODE_MCLASS)
        regions = []
        for paddr, data, memsz, vaddr in fw.segments + extra:
            for a in {paddr, vaddr}:
                regions.append((align_down(a), align_up(a + max(memsz, len(data)))))
        msp = next(struct.unpack("<I", d[fw.vector_base - a:fw.vector_base - a + 4])[0]
                   for a, d, m, v in fw.segments if a <= fw.vector_base < a + len(d))
        regions.append((align_down(msp - 0x10000), align_up(msp)))     # the stack below the initial MSP
        for spec in ram or []:
            base, size = (int(x, 0) for x in spec.split(":"))
            regions.append((align_down(base), align_up(base + size)))
        self.regions = self._merge(regions)
        for lo, hi in self.regions:
            self.uc.mem_map(lo, hi - lo)
        for paddr, data, memsz, vaddr in fw.segments + extra:
            if data:
                self.uc.mem_write(paddr, data)      # load image (LMA); the startup code copies .data
        self.uc.mem_map(PPB_BASE, PPB_SIZE)
        self.itm = {}
        self.insn = 0
        self.stop_reason = None
        self.bkpt = None
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self._ppb_write, begin=ITM_PORTS, end=ITM_PORTS + 0x7F)
        self.uc.hook_add(UC_HOOK_MEM_READ, self._ppb_read, begin=ITM_PORTS, end=DWT_CYCCNT + 3)
        self.uc.hook_add(UC_HOOK_INTR, self._intr)
        self.breakpoints = set()
        self._bp_hook = None
        msp = struct.unpack("<I", self.uc.mem_read(fw.vector_base, 4))[0]
        reset = struct.unpack("<I", self.uc.mem_read(fw.vector_base + 4, 4))[0]
        self.reset_vector = (msp, reset)
        self.reset()

    @staticmethod
    def _merge(regions):
        out = []
        for lo, hi in sorted(regions):
            if out and lo <= out[-1][1]:
                out[-1] = (out[-1][0], max(out[-1][1], hi))
            else:
                out.append((lo, hi))
        return out

    def reset(self):
        msp, reset = self.reset_vector
        self.uc.reg_write(UC_ARM_REG_SP, msp)
        self.uc.reg_write(UC_ARM_REG_LR, 0xFFFFFFFF)
        self.uc.reg_write(UC_ARM_REG_XPSR, 0x01000000)
        self.uc.reg_write(UC_ARM_REG_PC, reset | 1)
        self.stop_reason = None
        self.bkpt = None

    # -- peripherals --
    def _ppb_write(self, uc, access, addr, size, value, user):
        port = (addr - ITM_PORTS) // 4
        data = value.to_bytes(4, "little")[:size]
        self.itm.setdefault(port, bytearray()).extend(data)

    def _ppb_read(self, uc, access, addr, size, value, user):
        if addr < ITM_PORTS + 0x80:
            uc.mem_write(addr & ~3, struct.pack("<I", 1))   # stimulus port FIFO always ready
        elif addr == DWT_CYCCNT:
            uc.mem_write(addr, struct.pack("<I", (self.insn * 2) & 0xFFFFFFFF))

    def _intr(self, uc, intno, user):
        pc = uc.reg_read(UC_ARM_REG_PC)
        try:
            op = struct.unpack("<H", uc.mem_read(pc & ~1, 2))[0]
        except UcError:
            op = 0
        if op & 0xFF00 == 0xBE00:            # BKPT #imm
            self.bkpt = op & 0xFF
            self.stop_reason = f"bkpt #{self.bkpt}"
        else:
            self.stop_reason = f"exception {intno} at 0x{pc:08x}"
        uc.emu_stop()

    def _code(self, uc, address, size, user):
        if address in self.breakpoints and address != self._resume_pc:
            self.stop_reason = "breakpoint"
            uc.emu_stop()
        self._resume_pc = None

    def set_breakpoints(self, bps):
        self.breakpoints = set(bps)
        if self._bp_hook is None:
            self._bp_hook = self.uc.hook_add(UC_HOOK_CODE, self._code)

    def pc(self):
        return self.uc.reg_read(UC_ARM_REG_PC)

    def step(self, count):
        """Run up to count instructions; returns the number of instructions run (approximate on stops)."""
        self.stop_reason = None
        self._resume_pc = self.pc() & ~1
        start = self.pc() | 1
        try:
            self.uc.emu_start(start, 0xFFFFFFFF, count=count)
        except UcError as e:
            self.stop_reason = f"fault: {e} at 0x{self.pc():08x}"
        self.insn += count
        return count

    # -- RTT --
    rtt_fixed = None

    def rtt_base(self):
        a = self.rtt_fixed if self.rtt_fixed is not None else self.fw.sym("_SEGGER_RTT")
        if a is not None:
            return a
        for lo, hi in self.regions:
            mem = bytes(self.uc.mem_read(lo, hi - lo))
            i = mem.find(RTT_ID)
            if i >= 0:
                return lo + i
        return None

    def rtt_layout(self):
        base = self.rtt_base()
        if base is None:
            return None
        raw = bytes(self.uc.mem_read(base, 24))
        if not raw.startswith(RTT_ID):
            return None        # not initialised yet (SEGGER_RTT_Init writes the ID last)
        nup, ndown = struct.unpack("<ii", raw[16:24])
        bufs = []
        for i in range(nup + ndown):
            a = base + 24 + 24 * i
            name_p, buf_p, size, wr, rd, flags = struct.unpack("<IIIIII", self.uc.mem_read(a, 24))
            bufs.append({"dir": "up" if i < nup else "down", "index": i if i < nup else i - nup, "addr": a,
                         "name": self.cstr(name_p), "buffer": buf_p, "size": size, "wroff": wr, "rdoff": rd,
                         "flags": flags})
        return {"address": base, "max_up": nup, "max_down": ndown, "buffers": bufs}

    def cstr(self, p, limit=64):
        if not p:
            return ""
        try:
            return bytes(self.uc.mem_read(p, limit)).split(b"\0")[0].decode("latin-1")
        except UcError:
            return "?"

    def rtt_read(self, channel):
        lay = self.rtt_layout()
        if not lay or channel >= lay["max_up"]:
            return b""
        b = lay["buffers"][channel]
        if not b["size"]:
            return b""
        rd, wr, size = b["rdoff"], b["wroff"], b["size"]
        if wr >= rd:
            out = bytes(self.uc.mem_read(b["buffer"] + rd, wr - rd))
        else:
            out = bytes(self.uc.mem_read(b["buffer"] + rd, size - rd)) + bytes(self.uc.mem_read(b["buffer"], wr))
        self.uc.mem_write(b["addr"] + 16, struct.pack("<I", wr))   # RdOff = WrOff, like the host
        return out

    def rtt_write(self, channel, data):
        lay = self.rtt_layout()
        if not lay or channel >= lay["max_down"]:
            return 0
        b = lay["buffers"][lay["max_up"] + channel]
        rd, wr, size = b["rdoff"], b["wroff"], b["size"]
        n = 0
        for byte in data:
            nxt = (wr + 1) % size
            if nxt == rd:
                break
            self.uc.mem_write(b["buffer"] + wr, bytes([byte]))
            wr = nxt
            n += 1
        self.uc.mem_write(b["addr"] + 12, struct.pack("<I", wr))   # WrOff
        return n


def split_terminals(data):
    """SEGGER_RTT_SetTerminal()/TerminalOut() mark a terminal switch with 0xFF + '0'..'9'/'A'..'F'."""
    out, term, i = {}, 0, 0
    while i < len(data):
        if data[i] == 0xFF and i + 1 < len(data):
            term = int(chr(data[i + 1]), 16)
            i += 2
            continue
        out.setdefault(term, bytearray()).append(data[i])
        i += 1
    return {k: bytes(v) for k, v in out.items()}


def cmd_run(a):
    fw = Firmware(a.elf)
    sim = Sim(fw, a.ram, a.also or ())
    if a.rtt_elf:
        sim.rtt_fixed = Firmware(a.rtt_elf).sym("_SEGGER_RTT")
    up = {}
    pending = b"".join(t.encode().decode("unicode_escape").encode("latin-1") for t in (a.down or []))
    chunk, done = 2000, 0
    while done < a.max_insn:
        done += sim.step(min(chunk, a.max_insn - done))
        lay = sim.rtt_layout()
        if lay:
            for ch in range(lay["max_up"]):
                d = sim.rtt_read(ch)
                if d:
                    up.setdefault(ch, bytearray()).extend(d)
            if pending and up.get(0):      # type like a user: only after the firmware said something
                pending = pending[sim.rtt_write(0, pending):]
        if sim.stop_reason:
            break
    reason = sim.stop_reason or "instruction budget used up"
    lay = sim.rtt_layout()
    if a.raw_out:              # binary channel data (defmt frames, SystemView packets) for host decoders
        with open(a.raw_out, "wb") as f:
            f.write(bytes(up.get(a.channel, b"")))
    if a.json:
        print(json.dumps({"stop": reason, "instructions": done, "rtt": lay,
                          "up": {k: v.decode("latin-1") for k, v in up.items()},
                          "itm": {k: v.decode("latin-1") for k, v in sim.itm.items()}}, indent=1))
    else:
        if a.terminals:
            for t, d in sorted(split_terminals(bytes(up.get(a.channel, b""))).items()):
                sys.stdout.write(f"[terminal {t}]\n{d.decode('latin-1')}")
        elif a.itm:
            for port, d in sorted(sim.itm.items()):
                if all(32 <= c < 127 or c in (9, 10, 13) for c in d):
                    sys.stdout.write(f"[ITM port {port}]\n{d.decode('latin-1')}")
                else:      # binary samples: 32-bit little-endian words
                    words = [int.from_bytes(d[i:i + 4], "little") for i in range(0, len(d) - 3, 4)]
                    sys.stdout.write(f"[ITM port {port}]\n" + " ".join(f"0x{w:08x}" for w in words) + "\n")
        else:
            sys.stdout.write(bytes(up.get(a.channel, b"")).decode("latin-1"))
        sys.stdout.flush()
        print(f"[cmsim] stop: {reason} after ~{done} instructions", file=sys.stderr)
    if sim.bkpt == 0:
        return 0
    if sim.stop_reason is None and a.allow_timeout:
        return 0
    return 1


def cmd_info(a):
    fw = Firmware(a.elf)
    sim = Sim(fw, a.ram)
    msp, reset = sim.reset_vector
    print(f"elf            {a.elf}")
    print(f"vector table   0x{fw.vector_base:08x}  initial MSP 0x{msp:08x}  reset 0x{reset:08x}")
    for paddr, data, memsz, vaddr in fw.segments:
        print(f"load segment   LMA 0x{paddr:08x} VMA 0x{vaddr:08x} file {len(data):6d} mem {memsz:6d}")
    base = fw.sym("_SEGGER_RTT")
    if base is None:
        print("_SEGGER_RTT    not found (no RTT in this image)")
        return 1
    print(f"_SEGGER_RTT    0x{base:08x} size {fw.symbols['_SEGGER_RTT'][1]}")
    sim.step(a.max_insn)       # let SEGGER_RTT_Init run
    lay = sim.rtt_layout()
    if not lay:
        print("RTT block      not initialised within the instruction budget")
        return 1
    print(f"RTT block      up {lay['max_up']} down {lay['max_down']}")
    for b in lay["buffers"]:
        print(f"  {b['dir']:4} {b['index']}  name {b['name']!r:14} buffer 0x{b['buffer']:08x} size {b['size']}")
    return 0


# ---------- GDB remote serial protocol (subset JLinkGDBServer users rely on) ----------
def checksum(s):
    return f"{sum(s.encode('latin-1')) & 0xFF:02x}"


class GdbServer:
    MONITOR = {
        "reset": "Resetting target", "halt": "Halting target CPU...", "go": "", "speed": "Target interface speed set",
        "flash erase": "Flash erase: O.K.", "semihosting enable": "Semi-hosting enabled",
        "regs": None, "exec": "Executed", "endian little": "Target endianness set to little endian",
        "flash device": "Selecting device", "flash breakpoints": "Flash breakpoints enabled", "clrbp": "",
        "SWO EnableTarget": "SWO enabled", "rtt": "",
    }

    def __init__(self, fw, ram, port, rtt_port, max_insn):
        self.fw, self.port, self.rtt_port, self.max_insn = fw, port, rtt_port, max_insn
        self.sim = Sim(fw, ram)
        self.bps = set()
        self.lock = threading.Lock()
        self.rtt_clients = []
        self.running = False
        self.flash_writes = 0

    # registers r0..r12, sp, lr, pc, then xpsr at index 25 for the classic arm target
    def regs(self):
        from unicorn.arm_const import (UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3, UC_ARM_REG_R4, UC_ARM_REG_R5,
                                       UC_ARM_REG_R6, UC_ARM_REG_R7, UC_ARM_REG_R8, UC_ARM_REG_R9, UC_ARM_REG_R10,
                                       UC_ARM_REG_R11, UC_ARM_REG_R12)
        ids = [UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3, UC_ARM_REG_R4, UC_ARM_REG_R5,
               UC_ARM_REG_R6, UC_ARM_REG_R7, UC_ARM_REG_R8, UC_ARM_REG_R9, UC_ARM_REG_R10, UC_ARM_REG_R11,
               UC_ARM_REG_R12, UC_ARM_REG_SP, UC_ARM_REG_LR, UC_ARM_REG_PC]
        return ids

    def read_regs(self):
        vals = [self.sim.uc.reg_read(r) for r in self.regs()]
        vals[15] &= ~1
        out = "".join(struct.pack("<I", v).hex() for v in vals)
        out += "x" * 8 * 3 * 8 + "x" * 8          # f0-f7 (12 bytes each, unavailable) + fps
        out += struct.pack("<I", self.sim.uc.reg_read(UC_ARM_REG_XPSR)).hex()
        return out

    def handle(self, pkt):
        sim = self.sim
        if pkt.startswith("qSupported"):
            return "PacketSize=4000;qXfer:features:read-;swbreak+"
        if pkt == "?":
            return "S05"
        if pkt in ("qAttached",):
            return "1"
        if pkt.startswith("qC"):
            return ""
        if pkt.startswith("qfThreadInfo") or pkt.startswith("qsThreadInfo"):
            return "l"
        if pkt.startswith("H"):
            return "OK"
        if pkt == "g":
            return self.read_regs()
        if pkt.startswith("p"):
            n = int(pkt[1:], 16)
            if n < 16:
                v = sim.uc.reg_read(self.regs()[n]) & (~1 if n == 15 else 0xFFFFFFFF)
                return struct.pack("<I", v).hex()
            if n == 25:
                return struct.pack("<I", sim.uc.reg_read(UC_ARM_REG_XPSR)).hex()
            return "xxxxxxxx"
        if pkt.startswith("P"):
            n, v = pkt[1:].split("=")
            n = int(n, 16)
            if n < 16:
                sim.uc.reg_write(self.regs()[n], struct.unpack("<I", bytes.fromhex(v))[0] | (1 if n == 15 else 0))
            return "OK"
        if pkt.startswith("m"):
            addr, ln = (int(x, 16) for x in pkt[1:].split(","))
            try:
                return bytes(sim.uc.mem_read(addr, ln)).hex()
            except UcError:
                return "E01"
        if pkt.startswith("M"):
            head, data = pkt[1:].split(":")
            addr, _ = (int(x, 16) for x in head.split(","))
            try:
                sim.uc.mem_write(addr, bytes.fromhex(data))
                self.flash_writes += 1
                return "OK"
            except UcError:
                return "E01"
        if pkt.startswith("Z0") or pkt.startswith("Z1"):
            self.bps.add(int(pkt.split(",")[1], 16))
            return "OK"
        if pkt.startswith("z0") or pkt.startswith("z1"):
            self.bps.discard(int(pkt.split(",")[1], 16))
            return "OK"
        if pkt.startswith("qRcmd,"):
            cmd = bytes.fromhex(pkt[6:]).decode()
            return self.monitor(cmd)
        if pkt.startswith("vCont?"):
            return "vCont;c;s"
        if pkt.startswith("vCont;c") or pkt == "c":
            return self.cont()
        if pkt.startswith("vCont;s") or pkt == "s":
            sim.step(1)
            return "S05"
        if pkt.startswith("vMustReplyEmpty"):
            return ""
        if pkt == "k" or pkt == "D":
            return "OK"
        return ""

    def monitor(self, cmd):
        word = cmd.strip()
        if word.startswith("reset"):
            self.sim.reset()
        hit = next((v for k, v in self.MONITOR.items() if word.startswith(k)), None)
        if word == "regs":
            hit = f"PC = {self.sim.pc() & ~1:08X}"
        if hit is None and not any(word.startswith(k) for k in self.MONITOR):
            hit = f"Unknown monitor command '{word}' (cmsim)"
        # console output packets ("O" + hex text), then the final OK
        return (["O" + (hit + "\n").encode().hex()] if hit else []) + ["OK"]

    def cont(self):
        sim = self.sim
        sim.set_breakpoints(self.bps)
        done = 0
        while done < self.max_insn:
            done += sim.step(2000)
            self.pump_rtt()
            if sim.stop_reason:
                break
        if sim.stop_reason == "breakpoint":
            return "T05swbreak:;"        # one of GDB's breakpoints
        if sim.bkpt is not None:
            return "S05"                 # BKPT in the firmware: SIGTRAP (swbreak would make GDB resume)
        if sim.stop_reason:
            return "S0b"   # SIGSEGV: fault
        return "S02"       # SIGINT: budget used up, target "halted"

    def pump_rtt(self):
        data = self.sim.rtt_read(0)
        if data:
            for c in list(self.rtt_clients):
                try:
                    c.sendall(data)
                except OSError:
                    self.rtt_clients.remove(c)

    def rtt_server(self):
        srv = socket.create_server(("127.0.0.1", self.rtt_port))
        srv.settimeout(0.5)
        while True:
            try:
                c, _ = srv.accept()
            except socket.timeout:
                continue
            c.sendall(b"SEGGER J-Link V9.88 - Real time terminal output (cmsim)\r\n")
            self.rtt_clients.append(c)

    def serve(self):
        if self.rtt_port:
            threading.Thread(target=self.rtt_server, daemon=True).start()
        srv = socket.create_server(("127.0.0.1", self.port))
        print(f"[cmsim] GDB server listening on 127.0.0.1:{self.port} (RTT telnet {self.rtt_port})", flush=True)
        conn, _ = srv.accept()
        buf = b""
        while True:
            d = conn.recv(4096)
            if not d:
                break
            buf += d
            while True:
                if buf[:1] in (b"+", b"-"):
                    buf = buf[1:]
                    continue
                if buf[:1] == b"\x03":
                    buf = buf[1:]
                    conn.sendall(b"$S02#b5")
                    continue
                s = buf.find(b"$")
                e = buf.find(b"#", s)
                if s < 0 or e < 0 or len(buf) < e + 3:
                    break
                body = buf[s + 1:e]
                buf = buf[e + 3:]
                conn.sendall(b"+")
                if body.startswith(b"X"):
                    head, data = body[1:].split(b":", 1)
                    addr, _ = (int(x, 16) for x in head.split(b","))
                    raw = bytearray()
                    i = 0
                    while i < len(data):
                        if data[i] == 0x7D:
                            raw.append(data[i + 1] ^ 0x20)
                            i += 2
                        else:
                            raw.append(data[i])
                            i += 1
                    if raw:
                        self.sim.uc.mem_write(addr, bytes(raw))
                        self.flash_writes += 1
                    reply = "OK"
                else:
                    pkt = body.decode("latin-1")
                    reply = self.handle(pkt)
                    if pkt in ("k", "D"):
                        conn.sendall(f"${reply}#{checksum(reply)}".encode())
                        conn.close()
                        print(f"[cmsim] GDB detached; {self.flash_writes} memory writes", flush=True)
                        self.pump_rtt()
                        return 0
                if DEBUG:
                    print(f"[cmsim] <- {body[:60]!r} -> {str(reply)[:60]}", file=sys.stderr, flush=True)
                for r in (reply if isinstance(reply, list) else [reply]):
                    conn.sendall(f"${r}#{checksum(r)}".encode("latin-1"))
        return 0


def cmd_gdbserver(a):
    return GdbServer(Firmware(a.elf), a.ram, a.port, a.rtt_port, a.max_insn).serve()


def cmd_ihex(a):
    ranges, base, cur = [], 0, None
    with open(a.file) as f:
        for line in f:
            line = line.strip()
            if not line.startswith(":"):
                continue
            raw = bytes.fromhex(line[1:])
            if sum(raw) & 0xFF:
                print(f"bad checksum: {line}", file=sys.stderr)
                return 1
            n, addr, typ = raw[0], (raw[1] << 8) | raw[2], raw[3]
            if typ == 4:
                base = int.from_bytes(raw[4:6], "big") << 16
            elif typ == 2:
                base = int.from_bytes(raw[4:6], "big") << 4
            elif typ == 0:
                a0 = base + addr
                if cur and cur[1] == a0:
                    cur[1] = a0 + n
                else:
                    cur = [a0, a0 + n]
                    ranges.append(cur)
    for lo, hi in ranges:
        print(f"0x{lo:08x}-0x{hi:08x} {hi - lo}")
    return 0


def main(argv=None):
    p = argparse.ArgumentParser(prog="cmsim.py", description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("elf")
    r.add_argument("--max-insn", type=int, default=2_000_000)
    r.add_argument("--ram", action="append", help="extra RAM base:size (stack, heap)")
    r.add_argument("--also", action="append", help="load another ELF too (e.g. the app next to a bootloader)")
    r.add_argument("--rtt-elf", help="take the RTT control block symbol from this ELF (default: the first)")
    r.add_argument("--down", action="append", help="text for RTT down channel 0 (\\n escapes; sent after the first output, as fast as the buffer drains)")
    r.add_argument("--channel", type=int, default=0)
    r.add_argument("--terminals", action="store_true", help="split channel output by virtual terminal")
    r.add_argument("--itm", action="store_true", help="print ITM stimulus port output instead of RTT")
    r.add_argument("--json", action="store_true")
    r.add_argument("--raw-out", help="also write the raw bytes of --channel to this file (e.g. for defmt-print)")
    r.add_argument("--allow-timeout", action="store_true")
    i = sub.add_parser("info")
    i.add_argument("elf")
    i.add_argument("--ram", action="append")
    i.add_argument("--max-insn", type=int, default=200_000)
    g = sub.add_parser("gdbserver")
    g.add_argument("elf")
    g.add_argument("--ram", action="append")
    g.add_argument("--port", type=int, default=2331)
    g.add_argument("--rtt-port", type=int, default=19021)
    g.add_argument("--max-insn", type=int, default=5_000_000)
    h = sub.add_parser("ihex")
    h.add_argument("file")
    a = p.parse_args(argv)
    return {"run": cmd_run, "info": cmd_info, "gdbserver": cmd_gdbserver, "ihex": cmd_ihex}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
