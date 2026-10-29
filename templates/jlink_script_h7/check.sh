#!/usr/bin/env bash
# @NAME@: offline checks (no probe): the JLinkScript compiles as C against lib/jlinkscript_api.h and uses only
# J-Link hooks; the Commander script uses known commands, ends with exit and loads inside the H743 flash (2 MB).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
chk="python3 ${SEGGER_BOX_ROOT:?run inside segger-box shell}/lib/jlink_check.py"
$chk jlinkscript "$here/@NAME@.JLinkScript"
$chk commander "$here/@NAME@.jlink" --flash 0x08000000:0x200000
grep -q '_DBGMCU_CR   = 0x5C001004' "$here/@NAME@.JLinkScript"
echo "PASS @NAME@ (checked offline; J-Link runs the script only with a probe)"
