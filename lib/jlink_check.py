#!/usr/bin/env python3
"""jlink_check: offline checks of J-Link files (no probe, nothing is run against a target).

  jlink_check.py commander FILE.jlink [--flash BASE:SIZE] [--files-exist]
      every line a known J-Link Commander command, ends with exit/qc, load addresses inside the flash range,
      referenced files exist (relative to the script's folder or the current one)
  jlink_check.py jlinkscript FILE.JLinkScript [--cc arm-none-eabi-gcc]
      only known hook functions are defined, and the file compiles (syntax) as C with lib/jlinkscript_api.h
  jlink_check.py ozone FILE.jdebug [--cc arm-none-eabi-gcc]
      Ozone project script: known actions (Project.*, File.*, Target.*, Elf.*, Util.*, Exec.*, Debug.*),
      known hook functions, compiles as C after `Group.Action (` -> `Group_Action(`; File.Open targets exist
Exit codes: 0 ok, 1 problems found (listed), 2 usage error.
"""
import argparse
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
HEX = r"0x[0-9a-fA-F]+"
COMMANDS = [
    r"r", r"h", r"g", r"s", r"q", r"qc", r"exit", r"connect", r"erase( %s %s)?" % (HEX, HEX), r"sleep \d+",
    r"speed (\d+|auto|adaptive)", r"device \S+", r"si (SWD|JTAG|1|0)", r"rx \d+", r"rnh",
    r"loadfile \S+( %s)?" % HEX, r"loadbin \S+,? ?%s" % HEX, r"verifybin \S+,? ?%s" % HEX,
    r"savebin \S+ %s %s" % (HEX, HEX), r"mem(8|16|32)? %s,? ?(%s|\d+)" % (HEX, HEX),
    r"w(1|2|4) %s,? ?%s" % (HEX, HEX), r"exec \S.*", r"wreg \S+,? ?%s" % HEX, r"regs", r"setpc %s" % HEX,
]
KNOWN = re.compile("^(" + "|".join(COMMANDS) + ")$", re.I)
HOOKS = {"ConfigTargetSettings", "InitTarget", "SetupTarget", "ResetTarget", "AfterResetTarget", "InitEMU",
         "HandleBeforeFlashProg", "HandleAfterFlashProg", "OnTraceStop", "OnTraceStart"}


def commander(path, flash, files_exist):
    errs = []
    lines = [ln.strip() for ln in open(path) if ln.strip() and not ln.strip().startswith("//")]
    for ln in lines:
        if not KNOWN.match(ln):
            errs.append(f"unknown command: {ln}")
    if not lines or lines[-1].lower() not in ("exit", "qc", "q"):
        errs.append("does not end with exit/qc (J-Link Commander would wait for input)")
    lo, size = flash or (None, None)
    for ln in lines:
        m = re.match(r"(loadbin|verifybin|erase|loadfile) (\S+?),? ?(%s)?(?: (%s))?$" % (HEX, HEX), ln, re.I)
        if not m:
            continue
        cmd, arg, addr = m.group(1).lower(), m.group(2), m.group(3)
        if cmd in ("loadbin", "verifybin") and lo is not None:
            a = int(addr, 0)
            fsize = 0
            f = resolve(path, arg)
            if f:
                fsize = os.path.getsize(f)
            if not (lo <= a and a + fsize <= lo + size):
                errs.append(f"{ln}: 0x{a:08x}+{fsize} outside flash 0x{lo:08x}+{size}")
        if files_exist and cmd in ("loadbin", "verifybin", "loadfile") and not resolve(path, arg):
            errs.append(f"{ln}: file not found")
    return errs


def resolve(script, arg):
    for base in (os.path.dirname(os.path.abspath(script)), os.getcwd()):
        p = os.path.join(base, arg)
        if os.path.isfile(p):
            return p
    return None


def jlinkscript(path, cc):
    errs = []
    text = open(path).read()
    for name in re.findall(r"^\s*(?:int|void|U32)\s+([A-Za-z_]\w*)\s*\(\s*void\s*\)\s*\{", text, re.M):
        if name not in HOOKS and not name.startswith("_"):
            errs.append(f"{name}(): not a J-Link hook (helpers should start with '_')")
    cmd = [cc, "-x", "c", "-std=c99", "-fsyntax-only", "-Wall", "-Werror=implicit-function-declaration",
           "-include", os.path.join(HERE, "jlinkscript_api.h"), path]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        errs.append("syntax check failed:\n" + r.stderr.strip())
    return errs


OZONE_ACTIONS = {
    "Project.SetDevice": "const char *", "Project.SetHostIF": "const char *, const char *",
    "Project.SetTargetIF": "const char *", "Project.SetTIFSpeed": "const char *",
    "Project.AddSvdFile": "const char *", "Project.AddPathSubstitute": "const char *, const char *",
    "Project.SetOSPlugin": "const char *", "Project.SetTraceSource": "const char *",
    "Project.SetJLinkScript": "const char *", "File.Open": "const char *", "Util.Log": "const char *",
    "Util.Error": "const char *, int", "Target.ReadU32": "unsigned int", "Target.WriteU32": "unsigned int, unsigned int",
    "Target.SetReg": "const char *, unsigned int", "Target.GetReg": "const char *",
    "Elf.GetBaseAddr": "void", "Elf.GetEntryPointPC": "void", "Elf.GetEntryFuncPC": "void",
    "Exec.Reset": "void", "Debug.Halt": "void", "Debug.Continue": "void", "Target.LoadMemory": "const char *, unsigned int",
}
OZONE_HOOKS = {"OnProjectLoad", "TargetReset", "BeforeTargetReset", "AfterTargetReset", "TargetDownload",
               "BeforeTargetDownload", "AfterTargetDownload", "BeforeTargetConnect", "AfterTargetConnect",
               "BeforeTargetDisconnect", "AfterTargetDisconnect", "AfterTargetHalt", "BeforeTargetResume"}


def ozone(path, cc):
    errs = []
    text = open(path).read()
    used = set(re.findall(r"\b([A-Z][a-z]+\.\w+)\s*\(", text))
    for u in sorted(used - set(OZONE_ACTIONS)):
        errs.append(f"{u}: action not in the checked list (see the Ozone manual, add it to jlink_check.py)")
    for name in re.findall(r"^\s*void\s+(\w+)\s*\(\s*void\s*\)", text, re.M):
        if name not in OZONE_HOOKS:
            errs.append(f"{name}(): not an Ozone event hook")
    proj = os.path.dirname(os.path.abspath(path))
    for f in re.findall(r'File\.Open\s*\(\s*"([^"]+)"', text):
        f = f.replace("$(ProjectDir)", proj)
        if not os.path.isfile(f):
            errs.append(f"File.Open: {f} not found")
    decl = "".join(f"unsigned int {k.replace('.', '_')}({v});\n" for k, v in OZONE_ACTIONS.items())
    c = re.sub(r"\b([A-Z][a-z]+)\.(\w+)\s*\(", r"\1_\2(", text)
    r = subprocess.run([cc, "-x", "c", "-std=c99", "-fsyntax-only", "-Wall", "-Werror=implicit-function-declaration",
                        "-"], input=decl + c, capture_output=True, text=True)
    if r.returncode:
        errs.append("syntax check failed:\n" + r.stderr.strip())
    return errs


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("commander")
    c.add_argument("file")
    c.add_argument("--flash", help="BASE:SIZE, e.g. 0x08000000:0x80000")
    c.add_argument("--files-exist", action="store_true")
    j = sub.add_parser("jlinkscript")
    j.add_argument("file")
    j.add_argument("--cc", default="arm-none-eabi-gcc")
    o = sub.add_parser("ozone")
    o.add_argument("file")
    o.add_argument("--cc", default="arm-none-eabi-gcc")
    a = p.parse_args()
    if a.cmd == "commander":
        flash = tuple(int(x, 0) for x in a.flash.split(":")) if a.flash else None
        errs = commander(a.file, flash, a.files_exist)
    elif a.cmd == "ozone":
        errs = ozone(a.file, a.cc)
    else:
        errs = jlinkscript(a.file, a.cc)
    for e in errs:
        print(f"{a.file}: {e}")
    if not errs:
        print(f"ok {a.cmd} {a.file}")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
