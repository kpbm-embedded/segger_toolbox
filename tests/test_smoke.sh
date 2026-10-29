#!/usr/bin/env bash
# Smoke test of segger-box: installed SEGGER binaries are present and their libraries resolve
# (they are never started against a probe: J-Link tools may update probe firmware on connect),
# every template is generated with `new` and built/checked: jlink_script validates, rtt_app compiles,
# and the ten firmware/host templates build and run in cmsim or offline checks (no probe; SKIP before
# bootstrap installed the toolchain and SEGGER's RTT/SystemView sources).
# Usage: tests/test_smoke.sh
# shellcheck disable=SC2015  # ok() always returns 0
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd -P)
Q="$HERE/segger-box"
pass=0; failn=0; skipn=0
ok()   { printf 'ok    %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf 'FAIL  %s\n' "$*"; failn=$((failn+1)); }
skip() { printf 'skip  %s\n' "$*"; skipn=$((skipn+1)); }
tmp=$(mktemp -d)
cleanup() { if command -v trash-put >/dev/null; then trash-put "$tmp"; fi; }   # own temp dir; never rm
trap cleanup EXIT
I="$HERE/install"
for spec in jlink:JLinkExe jlink:JLinkGDBServerCLExe jlink:JLinkRTTViewerExe jlink:JLinkRTTLoggerExe ozone:Ozone systemview:SystemView; do
  pkg=${spec%%:*}; b=${spec#*:}
  if [[ ! -e "$I/$pkg/.boxt-ok" ]]; then skip "$b: $pkg not installed (licensed; ./segger-box install --accept-license)"; continue; fi
  p=$(find "$I/$pkg/" -maxdepth 3 -type f -name "$b" -perm -u+x | head -1)
  if [[ -z "$p" ]]; then bad "$b missing in install/$pkg"; continue; fi
  if missing=$(ldd "$p" 2>/dev/null | grep 'not found'); [[ -z "$missing" ]]; then ok "$b present, libraries resolve"
  else bad "$b: $missing"; fi
done
if "$Q" new jlink_script smoke_js --dir "$tmp" >/dev/null 2>&1 && [[ -f "$tmp/smoke_js/smoke_js.JLinkScript" ]] \
   && tail -1 "$tmp/smoke_js/smoke_js.jlink" | grep -x exit >/dev/null; then ok "template jlink_script"
else bad "template jlink_script"; fi
if "$Q" new rtt_app smoke_rtt --dir "$tmp" >/dev/null 2>&1; then
  out=$("$Q" run bash -c "cd '$tmp/smoke_rtt' && make -s check" 2>&1); rc=$?
  if [[ "$rc" = 0 ]] && grep -q 'compile (syntax)' <<<"$out"; then ok "template rtt_app builds (syntax) against SEGGER's RTT sources"
  elif grep -q 'SKIP: SEGGER RTT sources not found' <<<"$out"; then skip "template rtt_app generated; build needs the RTT sources (./segger-box bootstrap)"
  else bad "template rtt_app: $(tail -3 <<<"$out")"; fi
else bad "template rtt_app not generated"; fi
# open parts (bootstrap): every new template instantiated with `new` and built/checked without a probe
tpl() { # name kind command...  (runs inside the launcher's environment)
  local name=$1 kind=$2; shift 2
  if ! "$Q" new "$kind" "$name" --dir "$tmp" >/dev/null 2>&1; then bad "template $kind: new failed"; return; fi
  if out=$("$Q" run bash -c "cd '$tmp' && $*" 2>&1); then ok "template $kind"
  else bad "template $kind: $(tail -3 <<<"$out")"; fi
}
if [[ -x "$HERE/install/arm-gcc/bin/arm-none-eabi-gcc" ]] && [[ -d "$HERE/install/rtt/RTT" ]]; then
  tpl s_fw rtt_firmware "make -s -C s_fw BOARD=pico_rp2040 all sim | grep -q 's_fw: done'"
  fw="$tmp/s_fw/build/pico_rp2040/s_fw.elf"
  "$Q" run make -s -C "$tmp/s_fw" all >/dev/null 2>&1 || true
  f411="$tmp/s_fw/build/blackpill_f411/s_fw"
  tpl s_con rtt_console "make -s -C s_con sim | grep -q 'bye$'"
  tpl s_swo itm_swo "make -s -C s_swo sim | grep -q 's_swo: done'"
  tpl s_sv systemview_app "make -s -C s_sv check | grep -q '^PASS s_sv'"
  tpl s_mi multi_image "make -s -C s_mi check sim | grep -q 'started by the bootloader'"
  tpl s_gdb gdb_jlink "s_gdb/check.sh '$fw' | grep -q '^PASS s_gdb'"
  tpl s_oz ozone_project "s_oz/check.sh '$f411.elf' | grep -q '^PASS s_oz'"
  tpl s_cli rtt_telnet_client "python3 s_cli/s_cli.py --selftest | grep -q 'selftest: PASS'"
  tpl s_h7 jlink_script_h7 "s_h7/check.sh | grep -q '^PASS s_h7'"
  tpl s_pf production_flash "make -s -C s_pf FW='$f411.bin' SERIALS='7 8' check program SERIAL=8 | grep -q '^+ JLinkExe'"
else
  skip "10 firmware/host templates: toolchain and RTT sources not installed (./segger-box bootstrap)"
fi
echo "smoke: $pass ok, $failn failed, $skipn skipped"
[[ "$failn" -eq 0 ]]
