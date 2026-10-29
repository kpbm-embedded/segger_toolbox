# 32_12_segger - SEGGER J-Link, Ozone and SystemView

SEGGER's J-Link Software & Documentation Pack (JLinkExe, JLinkGDBServer, RTT Viewer/Logger/Client), Ozone and
SystemView, pinned and unpacked into this folder (no system install, no sudo). Use it to flash, debug and trace
STM32, RP2040/RP2350 and nRF52840 boards through a J-Link probe, with printed flash/debug plans for your boards,
RTT/SWO/SystemView firmware templates and J-Link/GDB/Ozone script templates.

Without a probe (and without the licensed packages), `bootstrap` installs the open parts: a pinned
arm-none-eabi-gcc/gdb, SEGGER's BSD-licensed RTT and SystemView target sources, and `lib/cmsim.py`, which runs the
firmware in the unicorn emulator and reads RTT, ITM/SWO and SystemView data the way J-Link does, and serves a
GDB port with J-Link-style `monitor` replies plus the RTT telnet port. Examples and templates are tested that way.

**These packages are proprietary.** Nothing here downloads them until you read the terms and run
`./segger-box install --accept-license`. `bootstrap` never fetches them (they are in `config/licensed.tsv`).

Status: **working without a probe; licensed tools need user action** (licence not accepted, SEGGER packages not
installed; doctor 17 ok / 4 warn / 0 failed, examples 16/16, templates 12/12, smoke 12 ok / 6 skip, dry run 36/36,
2026-10-29). Launcher: `./segger-box`.

## What's included

| Component | Version | Notes |
|---|---|---|
| J-Link Software & Documentation Pack (incl. RTT Viewer) | V9.88 (2026-10-22) | `JLink_Linux_V988_x86_64.tgz`, 89.9 MB; md5 `8752fae1ab5c0254c73380035b16f53e`; free for J-Link owners |
| Ozone | V3.50b (2026-09-24) | `Ozone_Linux_V350b_x86_64.tgz`, 28.7 MB; md5 `c9cb3aaa76adecaecbb6b59a9697a318` |
| SystemView | V4.10b (2026-05-19) | `SystemView_Linux_V410b_x86_64.tgz`, 10.1 MB; md5 `f24b6f4050356972d101c00017d2f84b`; free for non-commercial use |
| xPack arm-none-eabi-gcc (gcc, binutils, gdb) | 15.2.1-1.1 | open; `config/pins.tsv`, sha256 from xPack's `.sha` files; installed by `bootstrap` |
| SEGGER RTT target sources | V8.58.0 (commit 4d8feab) | open (BSD-style `LICENSE.md`); GitHub `SEGGERMicro/RTT`, sha256 pinned; `$SEGGER_RTT_DIR` |
| SEGGER SystemView target sources | V4.10 (commit 7cff780) | open (BSD-style); GitHub `SEGGERMicro/SystemView`, sha256 pinned; `$SEGGER_SYSVIEW_DIR` |
| pixi env: Python 3.12, make 4.4, pyelftools 0.33, unicorn 2.1.4 | pixi.lock | host helpers `lib/cmsim.py`, `lib/jlink_check.py` |
| pixi | 0.81.0 | sha256 pinned in the launcher |

Versions checked 2026-10-25 on the SEGGER download page. Only Linux x86_64 tarballs are pinned. All three come from
`https://www.segger.com/downloads/jlink/<file>`. SEGGER publishes an md5 per file but no sha256: `install` checks the
md5 and records a sha256 on the first download in `config/pins.local.tsv` (trust on first use); later installs
compare against it and abort on a mismatch. An HTML page instead of an archive also aborts.

## Quick start

```sh
cd "$BOX_SEGGER"                       # or: cd $BOX/30_39_tools/32_embedded/32_12_segger
./segger-box bootstrap                 # open parts only: pixi env, arm-none-eabi-gcc/gdb, RTT + SystemView sources
./segger-box doctor && ./segger-box examples test   # everything that works without a probe
./segger-box licence                   # licence URLs + what was accepted on this machine
./segger-box install --accept-license  # YOU accept: downloads, verifies, unpacks (without the flag: exit 2)
./segger-box doctor && ./segger-box list       # health checks, J-Links on USB
./segger-box plan blackpill_f411 fw.hex        # PRINTS the commands, runs nothing
```

With the Box shell set up once (`box shell install --apply`), the `segger-box` shim works from any folder,
and `box test|doctor|status segger` run this launcher (`box clean segger` is a dry run until `--apply`).
Standalone (no Box, or `BOX_INTEGRATION=0`), `./segger-box` keeps its output in this folder.

Only the J-Link pack: `./segger-box install --accept-license --only jlink`.

## Commands

Global option: `--dry-run` / `-n` prints what a command would do. Exit codes: 0 ok, 1 failure, 2 usage error (unknown command or option, or arguments given to `where`, `status`, `doctor`, `bootstrap` or `relocate`), 3 not applicable. `help` ends with this tool's own examples and variables (`tool examples`, `tool environment`).

| Command | What it does | Example |
|---|---|---|
| `bootstrap` | pinned pixi + env + core downloads (arm-none-eabi-gcc, SEGGER RTT/SystemView sources; never the licensed packages) | `./segger-box bootstrap` |
| `install [--no-demos]` | bootstrap + demo downloads + the licensed packages, only with `--accept-license` | `./segger-box install` |
| `install --accept-license [--only jlink,ozone,systemview]` | you accept SEGGER's terms; downloads the pinned Linux x86_64 .tgz | `./segger-box install --accept-license --only jlink` |
| `licence` | licence URLs and what has been accepted on this machine | `./segger-box licence` |
| `update [--check\|--env]` | `--check`: pins vs upstream (xPack release, RTT/SystemView tags; SEGGER has no release API for the licensed packages, so those are bumped by hand in `config/licensed.tsv`); `--env`: re-solve the pixi env | `./segger-box update --check` |
| `clean [--all] [--yes]` | move build/log output (`--all`: + install/, .pixi, native/, downloads) to the Trash; dry run unless `--yes` | `./segger-box --dry-run clean --all` |
| `status`, `where`, `doctor` | versions and sizes, paths, health checks (exit 1 on failure) | `./segger-box doctor` |
| `shell [-- cmd ...]`, `run <cmd> [args]` | bash / one command with the tools on PATH | `./segger-box shell` |
| `list` | read-only: J-Links on USB (`lsusb 1366:*`); J-Link Commander is not run, it may update probe firmware | `./segger-box list` |
| `boards` | owned boards to J-Link device names (`config/boards.tsv`) | `./segger-box boards` |
| `plan <board> [fw.elf\|.hex\|.bin]` | PRINT JLinkExe / JLinkGDBServer / RTT commands, runs nothing | `./segger-box plan all fw.elf` |
| `jlink`, `gdbserver`, `rtt`, `rtt-logger`, `rtt-client`, `ozone`, `systemview [args]` | the installed SEGGER tools (fail cleanly when not installed) | `./segger-box gdbserver -device STM32F411CE -if SWD` |
| `test [--all]` | `tests/test_smoke.sh`; `--all` adds the dry-run test and examples test | `./segger-box test` |
| `new <kind> <name> [--dir D] [--force]` | project from `templates/` (12 kinds, see below) | `./segger-box new rtt_firmware my_fw` |
| `examples list \| run <ex> [args] \| build [ex...] \| test [ex...]` | list, run, build or test the examples | `./segger-box examples test` |
| `native [--print]` | write `native/{native.zsh,native.bash,bin/}` | `./segger-box native` |
| `relocate` | after moving the folder: re-create the pixi env, rewrite `native/` | `./segger-box relocate` |
| `pack [--with-cache] [--out F]` | tarball of this folder for another machine; do not hand the licensed tgz to others | `./segger-box pack --out /tmp/s.tgz` |
| `help`, `-h`, `--help` | the command list | `./segger-box help` |

What `install --accept-license` does:

1. appends `accepted_by=<user>@<host>`, `accepted_at=<time>` and the package/licence URLs to `config/local-licence.txt`;
2. downloads each pinned `.tgz` to `cache/downloads/` (offline reinstall afterwards);
3. checks the md5 against SEGGER's value and the sha256 against the TOFU pin;
4. unpacks to `install/<pkg>-<version>/` with a link `install/<pkg>` (no `/opt`, no udev, no sudo);
5. writes the `native/` wrappers.

`plan` prints a J-Link Commander script (`r`, `h`, `loadfile`/`loadbin` + `verifybin`, `r`, `g`, `exit`), the
`JLinkExe -device ... -CommanderScript` line, the GDB server line (port 2331), the RTT logger line and GUI hints.

| Board (`plan` name) | J-Link device | Interface | Notes |
|---|---|---|---|
| BlackPill STM32F411CE (`blackpill_f411`) | `STM32F411CE` | SWD 4000 kHz | flash base 0x08000000 for `.bin` |
| Raspberry Pi Pico RP2040 (`pico_rp2040`) | `RP2040_M0_0` | SWD multi-drop, core 0 | use `.elf`/`.hex`; a raw `.bin` needs boot2 at 0x10000000 |
| ESP32-S3 DevKitC-1 (`esp32s3_devkitc`) | not supported | - | use its built-in USB-JTAG with OpenOCD-esp32 or esptool |
| Arduino Nano ATmega328P (`arduino_nano`) | not supported | - | AVR: avrdude via the bootloader or an ISP programmer |
| WeAct STM32G431 (`weact_g431`) | `STM32G431CB` | SWD 4000 kHz | flash base 0x08000000 |
| WeAct STM32H562 (`weact_h562`) | `STM32H562RG` | SWD 4000 kHz | Cortex-M33 |
| WeAct STM32H743 (`weact_h743`) | `STM32H743VI` | SWD 4000 kHz | debug in low-power modes: `templates/jlink_script_h7` |
| Raspberry Pi Pico 2 RP2350 (`pico2_rp2350`) | `RP2350_M33_0` | SWD, Arm core 0 | use `.elf`/`.hex` (IMAGE_DEF block) |
| nice!nano / Pro Micro nRF52840 (`nicenano_nrf52840`) | `nRF52840_xxAA` | SWD (pads) | app at 0x26000 after SoftDevice + UF2 bootloader; a full erase removes them |
| ESP32-C3 SuperMini (`esp32c3_supermini`) | not in this table | - | built-in USB-Serial/JTAG with OpenOCD-esp32 / esptool |
| CH32V003 (`ch32v003`) | not supported | - | single-wire SDI: WCH-LinkE with wlink/minichlink |

The device names of the new rows follow SEGGER's naming; they were not checked against JLinkExe's device list
here (pack not installed, no probe).

## Examples and templates

`./segger-box examples list`, then `examples test` (hardware-free: firmware runs in cmsim, scripts are checked
offline, J-Link commands are only printed or dry-run; nothing needs the licensed pack or a probe).

| Example | Board | What it shows | Without the pack |
|---|---|---|---|
| `plan_boards` | all four | plans for every owned board, unsupported boards explained | runs |
| `jlink_scripts` | BlackPill F411, Pico RP2040 | Commander script + `.JLinkScript` from the template, validated, never run | runs |
| `rtt_blackpill` | BlackPill F411 | `templates/rtt_app` syntax-checked against SEGGER's RTT sources | runs |
| `systemview_blackpill` | BlackPill F411 | `SEGGER_SYSVIEW_Conf_box.h` (100 MHz DWT timestamp, RAM base) checked against SystemView target sources | runs |
| `rtt_sim_boards` | F411, G431, H562, H743, RP2040, RP2350, nRF52840 | `rtt_firmware` built for 7 boards, run in cmsim, RTT channel 0 read like J-Link | simulated |
| `rtt_console_sim` | WeAct G431 | RTT down channel input + virtual terminal 1 (`rtt_console`) | simulated |
| `rtt_fixed_address` | BlackPill F411 | control block in section `.rtt`: address from nm/readelf/map, `-RTTAddress` / `SetRTTAddr` commands | checked, not run |
| `itm_swo_sim` | F411, H743 | printf over ITM port 0 + words on port 1 (`itm_swo`), SWO viewer line | simulated |
| `systemview_sim` | F411, RP2040, H562 | SystemView without an OS (`systemview_app`), "SysView" RTT stream checked | simulated |
| `gdbserver_sim` | WeAct H743 | `gdb_jlink` script run by the pinned gdb against cmsim's GDB server (load, compare-sections, break main, monitor) | simulated |
| `rtt_telnet_sim` | nice!nano | CI flow: GDB runs the target, `rtt_telnet_client` reads the RTT telnet port and waits for a line | simulated |
| `multi_image_sim` | BlackPill F411 | bootloader + app (`multi_image`): layout, merged image, hand-over in cmsim | simulated |
| `ozone_project_check` | BlackPill F411 | `ozone_project` .jdebug checked offline against a built ELF | checked, Ozone not run |
| `jlinkscript_syntax` | F411, H743 | .JLinkScript templates syntax-checked as C (`lib/jlinkscript_api.h`); a broken one must fail | checked, not run |
| `production_flash_plan` | BlackPill F411 | per-unit Commander scripts + serial records (`production_flash`), JLinkExe line as dry run | checked, not run |
| `plan_weact_boards` | G431, H562, H743, Pico 2, nice!nano | plans + Commander scripts checked; ESP32-C3 and CH32V003 explained | prints only |

SEGGER's RTT/SystemView target sources are not copied into this ID: `bootstrap` fetches them pinned from SEGGER's
GitHub repositories (BSD-style licence). "Simulated" means the firmware ran in `lib/cmsim.py` (unicorn: CPU and
memory, no peripherals, no interrupts): the RTT/ITM/SystemView protocol and the GDB flow are tested, the probe,
SWD/SWO wiring and real flash programming are not.

Templates (`./segger-box new <kind> <name> [--dir D]`):

- `rtt_app`: `main.c` (RTT printf/keys), `rtt_conf_box.h` (buffer sizes, mode), `Makefile` (`make check` unpacks RTT from the installed pack, or set `RTT_DIR=...`), README.
- `jlink_script`: `<name>.jlink` (Commander flash script) + `<name>.JLinkScript` (hooks), README.
- `rtt_firmware`: bare-metal RTT firmware (startup, linker script, `board.mk` for 7 boards); `make`, `make sim`, `make info`.
- `rtt_console`: line console over RTT down channel 0, warnings on virtual terminal 1; `make sim` types commands.
- `itm_swo`: printf over SWO (ITM port 0) + 32-bit samples (port 1), TPIU/ITM set up by hand; `make sim`, `make swo-plan`.
- `systemview_app`: SystemView without an OS (DWT timestamps; software ticks on Cortex-M0+); `make check`.
- `multi_image`: bootloader (0x08000000) + app (0x08008000), merged `.bin`, Commander script; `make check`, `make sim`.
- `gdb_jlink`: GDB command file for JLinkGDBServer; `check.sh fw.elf` runs it against cmsim's GDB server.
- `rtt_telnet_client`: Python RTT client for CI (port 19021, `--expect`/`--fail`, log); `--selftest`.
- `ozone_project`: Ozone `.jdebug` (device, SWD, SVD, ELF, SP/PC after download); `check.sh fw.elf` checks it offline.
- `jlink_script_h7`: H743 `.JLinkScript` (DBGMCU_CR: debug in Sleep/Stop/Standby) + Commander script; `check.sh`.
- `production_flash`: per-unit programming (firmware + CRC'd serial record), `make check`, `make program` (dry run).

Firmware templates build with `segger-box run make -C <name> [BOARD=...]` (the launcher puts the pinned
toolchain on PATH and sets `SEGGER_RTT_DIR`, `SEGGER_SYSVIEW_DIR`, `SEGGER_BOX_ROOT`).

## Configuration and environment variables

| Variable | Default | Meaning |
|---|---|---|
| `BOXT_OUT` | same ID path on idisk03, else the ID folder | output root (`build/`, `log/`); also settable in `config/local.env` |
| `BOXT_JOBS` | 8 (maximum) | parallel jobs |
| `BOXT_MIN_FREE_GB` / `BOXT_RAM_WAIT_MAX` | 8 / 3600 | pause builds while less RAM is free / give up after N seconds |
| `BOXT_NET_TIMEOUT` | 3600 | seconds for one download |
| `BOXT_PLATFORM` | detected (`linux-x64`) | override the platform |
| `GITHUB_TOKEN` | unset | optional; lifts the GitHub API limit for `update --check` |
| `BOX_INTEGRATION` | 1 | `0` = standalone: ignore `$BOX`/`$BOX_V3`, keep output in this folder |
| `NO_COLOR` | unset | set to print plain text (colour is only used on a terminal anyway) |
| `SEGGER_BOX_LICENSED_TSV` | `config/licensed.tsv` | licensed pin list (tests point it at fixtures) |
| `SEGGER_BOX_TOFU_TSV` | `config/pins.local.tsv` | trust-on-first-use sha256 pins |
| `SEGGER_BOX_LICENCE_RECORD` | `config/local-licence.txt` | your acceptance record |
| `SEGGER_BOX_INSTALL_DIR` / `SEGGER_BOX_DOWNLOAD_DIR` | `install/` / `cache/downloads` | where packages are unpacked / downloaded |
| `BOX_NATIVE_OFF_SEGGER` | unset | `1` skips native mode for one shell (old name `SEGGER_BOX_NATIVE_OFF` still honoured) |
| `BOX_SEGGER` | set by `box_env.sh` | path of this ID, used by the native snippet |
| `SEGGER_RTT_DIR` / `SEGGER_SYSVIEW_DIR` | `install/rtt`, `install/systemview-src` | set by the launcher (`shell`, `run`, examples): SEGGER's target sources for the firmware templates |
| `SEGGER_BOX_ROOT` | this ID | set by the launcher; templates find `lib/cmsim.py` and `lib/jlink_check.py` through it |
| `CMSIM_DEBUG` | unset | `1`: `lib/cmsim.py gdbserver` prints every GDB packet |

## Where files go

| What | Where |
|---|---|
| Source, launcher, examples, templates, `config/` | this ID |
| Tools (after install) | `install/`: open parts 1.1 GB (arm-gcc 1.1 GB, RTT 0.2 MB, SystemView sources 1.8 MB); licensed J-Link ~250 MB, Ozone ~80 MB, SystemView ~30 MB (estimated; not installed); `.bin/` (77 MB pinned pixi), `.pixi/` (81 MB env) |
| Cache | `cache/downloads` (xPack gcc 291 MB + two source archives; the three licensed tgz 129 MB after install), `cache/pixi` (pixi packages); `CACHEDIR.TAG` |
| Build output and logs | `$BOX_V3/30_39_tools/32_embedded/32_12_segger/{build,log}` (0.1 MB) |
| Your records | `config/pins.local.tsv`, `config/local-licence.txt` (written by install, gitignored) |

ID size now: 1.8 GB (install 1.1 GB, cache 0.5 GB, env and pixi 0.2 GB; the committed sources are well under 1 MB).

## Native mode

`./segger-box native` writes `native/native.{zsh,bash}` and wrappers in `native/bin`: `JLinkExe`, `JLinkGDBServer`,
`JLinkRTTViewer`, `JLinkRTTLogger`, `JLinkRTTClient`, `ozone`, `systemview` (through the launcher, so they fail
cleanly before install). Load it in every shell (zsh, bash, fish) with `box native enable segger --apply`: it runs
`./segger-box native` when the files are missing and rebuilds `box_env.d/native.*` (without `--apply` it only shows
the plan; `box native disable segger --apply` undoes it). `BOX_NATIVE_OFF_SEGGER=1` skips it for one shell (the old
`SEGGER_BOX_NATIVE_OFF` still works for now). Without Box, source `native/native.zsh` or `native/native.bash` from
your shell rc.

## Tests

```sh
./segger-box test --all          # smoke + dry-run + examples
tests/test_dry_run.sh            # every command in --dry-run + install logic on fixtures + shellcheck
tests/test_install_logic.sh      # licence gate, POST, md5, TOFU sha256, unpack, plan (no SEGGER binaries)
tests/test_smoke.sh              # installed binaries + all 12 templates generated and built/checked (SKIP for licensed parts)
```

Last known (2026-10-29): doctor 17 ok / 4 warn (licensed packages, udev) / 0 fail; examples 16/16; smoke 12 ok
(all 12 templates) / 6 skip (licensed binaries); dry-run 36/36 (incl. install logic 15/15 on a fixture, shellcheck).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `install` exits 2 and prints URLs | expected without `--accept-license`; read the terms, then pass the flag |
| md5 or sha256 mismatch on install | aborts and keeps the `.part` file for inspection; if SEGGER re-released the file, update `config/licensed.tsv` deliberately |
| Download returns an HTML page | SEGGER's form changed; install aborts. Download by hand into `cache/downloads/` |
| `doctor` warns about udev; only root sees the J-Link | install the udev rules (below), then re-plug the probe |
| `jlink`/`rtt` tools say "not installed" | run `install --accept-license` first |
| `rtt_blackpill` / `systemview_blackpill` report SKIP | RTT/SystemView sources missing: `./segger-box bootstrap` |
| a firmware example fails with `cmsim ... fault` | the image touched memory cmsim does not map (a peripheral); cmsim has CPU, flash, RAM, ITM and DWT only |
| `examples test` fails on `rtt_telnet_sim`/`gdbserver_sim` | they open two free localhost ports; a firewall blocking 127.0.0.1 breaks them |

## Limitations / needs you

- **Licence (you):** read the URLs printed by `./segger-box licence`, then run `$BOX_SEGGER/segger-box install --accept-license`. Ozone and SystemView have their own terms (SystemView is free for non-commercial use only).
- **udev rules (sudo, run these yourself).** Without rules only root can open a J-Link. Two equivalent options:

```sh
# a) the rules file shipped by SEGGER inside the pack (after install --accept-license)
sudo cp "$BOX_SEGGER/install/jlink/99-jlink.rules" /etc/udev/rules.d/
# b) or the minimal file written for this ID (vendor 1366, uaccess for the seat user)
sudo cp "$BOX_SEGGER/udev/70-box-segger.rules" /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

  Unplug and re-plug the probe afterwards. Remove with `sudo trash-put /etc/udev/rules.d/70-box-segger.rules`.
- **Hardware:** a J-Link probe is needed for anything beyond `plan`, the simulator and the offline checks. Not verified here: the installed tools, `list` with a probe attached, real flashing (nothing was flashed), RTT/SWO/SystemView on real boards, the J-Link device names of the new board rows, Ozone and the `.JLinkScript` files inside J-Link (they are syntax-checked only).
- **Boards:** ESP32-S3 and the Nano are not supported by J-Link (see the table).
- **Other OSes:** only Linux x86_64 is pinned. For arm64, macOS or Windows add rows to `config/licensed.tsv` with the md5 from the download page; macOS/Windows installers are not tarballs and would need an unpack hook.

## Scripts

Each script has a `[scripts.*]` descriptor in `.box.toml` (`box scripts show 32_12`; `box scripts check 32_12` must stay clean).

| File | Purpose |
|---|---|
| `segger-box` | launcher (POSIX sh): bootstraps the pinned pixi, keeps caches in this folder, then runs `lib/` |
| `lib/boxtool.bash` | shared launcher framework (boxtool 3: bootstrap, pinned downloads, pixi env, every common command); byte-identical copy of `$BOX/00_09_meta/05_policy/templates/tool/lib/boxtool.bash` (edit there, then sync) |
| `lib/segger.bash` | this tool's part: licence gate, fetch/verify/unpack, `plan`, `list`, tool wrappers |
| `lib/cmsim.py` | runs a Cortex-M ELF in unicorn: RTT up/down, ITM ports, DWT cycle counter, GDB server (J-Link `monitor` replies) + RTT telnet port |
| `lib/jlink_check.py`, `lib/jlinkscript_api.h` | offline checks of Commander scripts, `.JLinkScript` files (C syntax with the API declarations) and Ozone `.jdebug` projects |
| `examples/*/example.sh` | the 16 examples |
| `tests/test_smoke.sh`, `tests/test_dry_run.sh`, `tests/test_install_logic.sh` | smoke, dry-run/shellcheck, licence-gate/TOFU logic on fixtures |
| `native/` | written by `./segger-box native`; regenerate, do not edit |

## Links

- SEGGER downloads: <https://www.segger.com/downloads/jlink/>
- Ozone licence: <https://www.segger.com/products/development-tools/ozone-j-link-debugger/#licensing0>
- SystemView licence: <https://www.segger.com/products/development-tools/systemview/license/conditions-activation/>
- History: `NOTES.md`. Report: `$BOX/00_09_meta/02_logs/2026_10_25_embedded_tools2_report.md`.
- Sibling tools: `32_15_flashers` (esptool, avrdude, dfu-util for the unsupported boards), `32_08_probe_tools`.
