# @NAME@

Rust firmware that logs with defmt over SEGGER RTT, from `segger-box new rust_defmt_rtt @NAME@` (32_12_segger).
No HAL (cortex-m-rt, defmt, defmt-rtt, panic-probe), so it runs on any Cortex-M4F board and in cmsim. The Rust
toolchain, the crates and `defmt-print` come from 32_17_embedded_rust (`$BOX_EMBEDDED_RUST`, else the sibling
folder); nothing is installed here.

    segger-box run @NAME@/check.sh    # build (offline), run in cmsim, decode RTT with defmt-print, J-Link commands

defmt sends compact binary frames, not text: J-Link's RTT Viewer shows garbage. Log the raw bytes with
`segger-box rtt-logger ... -RTTChannel 0 rtt.bin` (or read port 19021 of JLinkGDBServer) and decode them
with `defmt-print -e <elf>`. probe-rs (32_17) does both in one step. Not verified with a probe here.
