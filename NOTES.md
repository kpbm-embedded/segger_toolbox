# 32_12_segger: notes

## 2026-10-25: created
- New ID in the Box tool style (launcher `segger-box`, `lib/boxtool.bash` copied unchanged from
  32_10_qemu, md5 b938d4f9...; pixi binary copied from the same v0.81.0 pin).
- Versions read from the public download page (GET only): J-Link V9.88, Ozone V3.50b, SystemView
  V4.10b. The page embeds JSON per file (`md5checksum`, `size`, `date`, `license_agreement`);
  the J-Link pack needs the licence form (`accept_license_agreement=accepted`, `submit`), Ozone and
  SystemView are served directly (checked with `curl --max-filesize 3000000`, which aborted before
  the body: no proprietary binary was downloaded).
- Nothing was accepted or downloaded for the user. The licensed install is tested end to end with a
  fixture tarball over `file://` through the `SEGGER_BOX_*` test hooks (tests/test_install_logic.sh).
- boxtool's `cmd_install` rejects unknown options, so `install` is intercepted in `lib/segger.bash`
  (`boxt_main_segger`) instead of changing boxtool.bash.
- No Arm toolchain here: the RTT/SystemView checks are `-fsyntax-only` with the host clang/cc and
  SKIP until the pack (which carries SEGGER's target sources) is installed.
- Results: doctor 8 ok / 4 warnings (licensed packages not installed, udev) / 0 failed; examples test
  4/4 ok (2 report SKIP inside); test_dry_run 35/35 (incl. install-logic 15/15, shellcheck 10 files);
  test_smoke 1 ok, 7 skipped, 0 failed.

## 2026-10-25: script style pass (00_09_meta/04_agents/script_style.md)
- lib/boxtool.bash replaced by the cleaned shared version (md5 0c5ba426..., same as 32_06..32_10):
  usage errors exit 2, help has examples + environment sections.
- Tool lib: usage problems via `usage_error` (exit 2); tool-specific environment variables and
  examples added to the help text; `[ ]` -> `[[ ]]` in the lib, tests and example scripts
  (POSIX `sh` launcher and `#!/bin/sh` fixtures unchanged); dead code removed.
- The licence refusal now exits 2 (usage error) instead of 3.

## 2026-10-25: readability pass 2 (script_style.md, scripts/README)
- lib/boxtool.bash (reference `00_09_meta/05_policy/templates/tool/lib/boxtool.bash`, synced to all 24 copies):
  `where`/`status`/`doctor`/`bootstrap`/`relocate` reject extra arguments (exit 2); colour only on a terminal
  and never with `NO_COLOR`; help lists `NO_COLOR`.
- examples/jlink_scripts: `| grep -q` under pipefail -> here-string.
- README: exit codes, `BOX_INTEGRATION` and `NO_COLOR` rows. Backups:
  `00_09_meta/02_logs/config_backups/2026_10_25_readability2_embedded_tools/`.

## 2026-10-29: examples and templates without a probe, GitHub-ready repo
- Open parts installed by `bootstrap` (`config/pins.tsv`, new): xPack arm-none-eabi-gcc 15.2.1-1.1 (same pin and
  sha256 as 32_18_rtos; the tarball was copied from its cache, not re-downloaded), SEGGER's RTT V8.58.0 and
  SystemView V4.10 target sources from github.com/SEGGERMicro (BSD-style licence, pinned by commit + sha256).
  New `pixi.toml`/`pixi.lock`: Python 3.12, make, pyelftools, unicorn 2.1.4. The licensed packages are unchanged
  (still only with `install --accept-license`; not installed here).
- `lib/cmsim.py`: runs a Cortex-M ELF in unicorn (flash/RAM from the load segments, stack below the initial MSP),
  reads/writes RTT buffers like J-Link, captures ITM stimulus ports, counts DWT CYCCNT, and serves the GDB remote
  protocol with J-Link-style `monitor` replies plus an RTT telnet port. `lib/jlink_check.py` +
  `lib/jlinkscript_api.h`: offline checks of Commander scripts, `.JLinkScript` (compiled as C) and Ozone projects.
- 12 new examples: rtt_sim_boards, rtt_console_sim, rtt_fixed_address, itm_swo_sim, systemview_sim,
  gdbserver_sim, rtt_telnet_sim, multi_image_sim, ozone_project_check, jlinkscript_syntax,
  production_flash_plan, plan_weact_boards. rtt_blackpill and systemview_blackpill now use the pinned sources
  and run instead of SKIP.
- 10 new templates: rtt_firmware, rtt_console, itm_swo, systemview_app, multi_image, gdb_jlink, rtt_telnet_client,
  ozone_project, jlink_script_h7, production_flash. All 12 are instantiated and built/checked in test_smoke.sh.
- `config/boards.tsv`: WeAct G431/H562/H743, Pico 2 (RP2350_M33_0), nice!nano nRF52840 (app at 0x26000); ESP32-C3
  and CH32V003 as not supported. Device names not checked against JLinkExe (no pack, no probe).
- Problems found: an empty `.data` keeps its RAM address as LMA in GNU ld 2.45, so `objcopy -O binary` wrote a
  400 MB file from 0x08000000 to 0x20000000; the linker scripts set `AT(_sidata)` and the bin rules leave out an
  empty `.data`. RTT V8.58 defines its buffer counts in `SEGGER_RTT_ConfDefaults.h`, after SystemView V4.10 checks
  them (`#error ... has to be > 1`): passed with -D; `RTT_USE_ASM=0` (the ARMv7-M assembly file is not built).
  Cortex-M0+ has no DWT: SystemView gets a software timestamp there. GDB resumes after a `T05swbreak` stop that is
  not its own breakpoint (endless loop): cmsim reports a firmware BKPT as `S05`. qRcmd needs `O<hex>` + `OK`.
  The RP2040 linker script starts at 0x10000100 (boot2) and the ELF header lands in the first load segment: cmsim
  takes the vector table from `.isr_vector`, not the lowest load address.
- git: `.gitignore` strict (env, caches, installs, downloads, build output, licence records); the root entries
  have no trailing slash so a symlinked `cache` (fresh-clone check) is ignored too. Fresh clone (BOX_INTEGRATION=0,
  cache linked): bootstrap ok, doctor 14 ok / 4 warn / 0 failed, smoke 12 ok / 6 skip, dry run 36/36, examples 16/16.
- Results: doctor 17 ok / 4 warn / 0 failed; examples 16/16; smoke 12 ok / 6 skip (licensed binaries); dry run
  36/36 (install logic 15/15, shellcheck 25 files clean); `box scripts check 32_12` clean.

## 2026-10-29: Rust, Zig and BEAM (addendum)
- Toolchains reached, not copied (`sibling_id`, as in 32_30): 32_17_embedded_rust (`rust-box cargo`, `defmt-print`),
  32_24_microzig (`microzig-box zig`), 32_29_atomvm (`atomvm-box build|avm|where`). Doctor reports each; examples exit 3
  and smoke tests skip when one is missing.
- Rust: template `rust_defmt_rtt` + example `rust_defmt_rtt_sim`. The crates (defmt 1.2, defmt-rtt 1.3.1, panic-probe,
  cortex-m-rt) are already in 32_17's registry cache, so `cargo build --offline` works; Cargo.lock is shipped in the
  template. cmsim got `--raw-out` for binary channels; defmt-print decodes them (levels, derive(Format), trace! filtered).
- Zig: template `zig_rtt_firmware` + example `zig_rtt_gdb_sim`. Zig 0.17 has no `@cImport` (moved to the build system)
  and ships no libc headers for freestanding Arm: the RTT C files are compiled by the pinned arm-none-eabi-gcc, Zig
  declares the three functions `extern` and links (memcpy from its compiler_rt). ReleaseSmall strips symbols: `-fno-strip`.
  lld does not search -L for `INCLUDE`: the Makefile writes a linker script with the full memory.ld path. The gdb_jlink
  check now accepts `main.main` and a breakpoint after main's prologue.
- BEAM: template `atomvm_pico_jlink` + example `atomvm_pico_jlink` (Erlang app run on the host AtomVM, Pico images for
  J-Link). Found: the AtomVM 0.6.6 Pico VM reads lib.avm at 0x10100000 and main.avm at 0x10180000 (constants in the
  image, and the upstream atomvmlib .uf2 is at 0x10100000); the VM itself ends at 0x1008e800. 32_29's `plan`/`build`
  use 0x10080000/0x10100000 (an app .uf2 there would overwrite the lib): reported, not changed (other ID).
  atomvmlib 0.6.6 has no `lists:sum/1`.
- Results: doctor 17 ok (3 of them the sibling IDs) / 4 warn / 0 failed; examples 19/19; smoke 15 ok / 6 skip (licensed binaries).
