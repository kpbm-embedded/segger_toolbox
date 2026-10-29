#!/usr/bin/env bash
# @NAME@: offline check of the Ozone project (no probe, Ozone not started): copies FW.elf to build/@NAME@.elf
# (where File.Open looks), checks actions/hooks/syntax with lib/jlink_check.py and that the ELF is a
# Cortex-M image with its vector table at the start of flash. Usage: ./check.sh fw.elf
set -euo pipefail
fw=${1:?usage: ./check.sh firmware.elf}
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$here/build"
cp "$fw" "$here/build/@NAME@.elf"
python3 "${SEGGER_BOX_ROOT:?run inside segger-box shell}/lib/jlink_check.py" ozone "$here/@NAME@.jdebug"
arm-none-eabi-readelf -h "$here/build/@NAME@.elf" | grep -q 'Machine: *ARM'
arm-none-eabi-readelf -S "$here/build/@NAME@.elf" | grep -Eq '\.isr_vector +PROGBITS +08000000'
echo "PASS @NAME@ (Ozone project checked offline against build/@NAME@.elf)"
