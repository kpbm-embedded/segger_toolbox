#!/usr/bin/env bash
# The licensed-install logic WITHOUT SEGGER's binaries: licence gate refusal, dry-run install,
# fixture tarball over file:// (md5 check, TOFU sha256 record + recheck + mismatch abort, HTML
# instead of archive, unpack flattening), plan output. All state goes to a temp dir through the
# SEGGER_BOX_* test hooks; the real config/ and install/ are not touched.
# Usage: tests/test_install_logic.sh
# shellcheck disable=SC2015  # ok() always returns 0
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd -P)
L="$HERE/segger-box"
pass=0; failn=0
ok()  { printf 'ok    %s\n' "$*"; pass=$((pass+1)); }
bad() { printf 'FAIL  %s\n' "$*"; failn=$((failn+1)); }
tmp=$(mktemp -d)
cleanup() { if command -v trash-put >/dev/null; then trash-put "$tmp"; fi; }   # own temp dir; never rm
trap cleanup EXIT

# 1) licence gate: install without the flag refuses (exit 2) and prints the licence URLs; nothing downloaded
out=$("$L" install 2>&1); rc=$?
if [[ "$rc" = 2 ]] && grep -q 'https://www.segger.com/downloads/jlink/' <<<"$out" && grep -q 'refused: SEGGER licence not accepted' <<<"$out" \
   && grep -q 'systemview/license/conditions-activation' <<<"$out"; then ok "licence gate refuses without --accept-license (exit 2, URLs printed)"
else bad "licence gate (rc=$rc)"; fi
out=$("$L" install --only jlink 2>&1); rc=$?
[[ "$rc" = 2 ]] && ok "gate also refuses with --only but no flag" || bad "gate with --only (rc=$rc)"

# 2) dry-run of the real install: the POST form field, md5, the three pinned URLs; no file written
before=$(find "$HERE/cache" "$HERE/install" "$HERE/config" -type f 2>/dev/null | sort | md5sum)
out=$("$L" --dry-run install --accept-license 2>&1); rc=$?
after=$(find "$HERE/cache" "$HERE/install" "$HERE/config" -type f 2>/dev/null | sort | md5sum)
if [[ "$rc" = 0 ]] && grep -q -- '--data accept_license_agreement=accepted https://www.segger.com/downloads/jlink/JLink_Linux_V988_x86_64.tgz' <<<"$out" \
   && grep -q 'Ozone_Linux_V350b_x86_64.tgz' <<<"$out" && grep -q 'SystemView_Linux_V410b_x86_64.tgz' <<<"$out" \
   && grep -q 'md5 8752fae1ab5c0254c73380035b16f53e' <<<"$out" && [[ "$before" = "$after" ]]; then ok "dry-run install: POST form, md5 pins, 3 URLs, nothing written"
else bad "dry-run install (rc=$rc)"; tail -5 <<<"$out"; fi

# 3) fixture tarball: a fake J-Link pack with a single top folder
mkdir -p "$tmp/src/JLink_Linux_V000_x86_64/Samples/RTT" "$tmp/state"
printf '#!/bin/sh\necho "SEGGER J-Link Commander V0.00 (fixture)"\n' >"$tmp/src/JLink_Linux_V000_x86_64/JLinkExe"
chmod +x "$tmp/src/JLink_Linux_V000_x86_64/JLinkExe"
cp "$HERE/udev/70-box-segger.rules" "$tmp/src/JLink_Linux_V000_x86_64/99-jlink.rules"
tar -czf "$tmp/JLink_Linux_V000_x86_64.tgz" -C "$tmp/src" JLink_Linux_V000_x86_64
md5=$(md5sum "$tmp/JLink_Linux_V000_x86_64.tgz" | cut -d' ' -f1)
sha=$(sha256sum "$tmp/JLink_Linux_V000_x86_64.tgz" | cut -d' ' -f1)
printf 'jlink\tV0.00\tlinux-x64\t%s\tfile://%s\thttps://www.segger.com/downloads/jlink/\tfixture\n' "$md5" "$tmp/JLink_Linux_V000_x86_64.tgz" >"$tmp/licensed.tsv"
export SEGGER_BOX_LICENSED_TSV="$tmp/licensed.tsv" SEGGER_BOX_TOFU_TSV="$tmp/state/pins.local.tsv" \
       SEGGER_BOX_LICENCE_RECORD="$tmp/state/local-licence.txt" SEGGER_BOX_INSTALL_DIR="$tmp/install" SEGGER_BOX_DOWNLOAD_DIR="$tmp/dl"
out=$("$L" install --accept-license 2>&1); rc=$?
if [[ "$rc" = 0 ]] && grep -q "$sha" "$tmp/state/pins.local.tsv" 2>/dev/null; then ok "first install records the TOFU sha256"
else bad "first install (rc=$rc)"; tail -5 <<<"$out"; fi
if [[ -x "$tmp/install/jlink-V0.00/JLinkExe" ]] && [[ -L "$tmp/install/jlink" ]] && grep -q "sha256=$sha" "$tmp/install/jlink-V0.00/.boxt-ok"; then
  ok "unpack: single top folder flattened to install/jlink-V0.00 + install/jlink link + .boxt-ok"
else bad "unpack layout"; find "$tmp/install" -maxdepth 2 | head; fi
grep -q '^accepted_by=' "$tmp/state/local-licence.txt" && grep -q '^package=jlink V0.00' "$tmp/state/local-licence.txt" \
  && ok "acceptance recorded (who/when/package)" || bad "acceptance record"
v=$("$L" jlink 2>&1); grep -q 'fixture' <<<"$v" && ok "jlink wrapper runs the installed JLinkExe" || bad "jlink wrapper: $v"

# 4) second install: cached archive re-verified against the TOFU pin
out=$("$L" install --accept-license 2>&1); rc=$?
[[ "$rc" = 0 ]] && grep -q 'matches the pin from first use' <<<"$out" && ok "reinstall: cached archive matches the TOFU pin" || { bad "reinstall (rc=$rc)"; tail -3 <<<"$out"; }

# 5) TOFU mismatch aborts (pin edited to another value)
sed -i "s/$sha/$(printf '0%.0s' {1..64})/" "$tmp/state/pins.local.tsv"
out=$("$L" install --accept-license 2>&1); rc=$?
[[ "$rc" != 0 ]] && grep -q 'differs from the first-use pin' <<<"$out" && ok "TOFU mismatch aborts (rc=$rc)" || bad "TOFU mismatch not detected (rc=$rc)"

# 6) md5 mismatch (a different archive at the URL) aborts and keeps .part
printf 'jlink\tV0.01\tlinux-x64\t%s\tfile://%s\thttps://www.segger.com/downloads/jlink/\tfixture\n' "00000000000000000000000000000000" "$tmp/JLink_Linux_V000_x86_64.tgz" >"$tmp/licensed.tsv"
mv "$tmp/dl/JLink_Linux_V000_x86_64.tgz" "$tmp/dl/old.tgz"
out=$("$L" install --accept-license 2>&1); rc=$?
[[ "$rc" != 0 ]] && grep -q 'md5 .* published by SEGGER' <<<"$out" && [[ -e "$tmp/dl/JLink_Linux_V000_x86_64.tgz.part" ]] && ok "md5 mismatch aborts, .part kept" || bad "md5 mismatch (rc=$rc)"

# 7) HTML page instead of the archive (licence form not accepted) aborts
printf '<!DOCTYPE html><html><body>Terms of Use</body></html>\n' >"$tmp/page.tgz"
printf 'jlink\tV0.02\tlinux-x64\t%s\tfile://%s\thttps://www.segger.com/downloads/jlink/\tfixture\n' "$(md5sum "$tmp/page.tgz" | cut -d' ' -f1)" "$tmp/page.tgz" >"$tmp/licensed.tsv"
out=$("$L" install --accept-license 2>&1); rc=$?
[[ "$rc" != 0 ]] && grep -q 'HTML page instead of the archive' <<<"$out" && ok "HTML instead of archive aborts" || bad "HTML detection (rc=$rc)"
unset SEGGER_BOX_LICENSED_TSV SEGGER_BOX_TOFU_TSV SEGGER_BOX_LICENCE_RECORD SEGGER_BOX_INSTALL_DIR SEGGER_BOX_DOWNLOAD_DIR

# 8) not installed: wrappers fail cleanly; plan output
if [[ ! -d "$HERE/install/jlink/" ]]; then
  out=$("$L" jlink 2>&1); rc=$?
  [[ "$rc" != 0 ]] && grep -q 'not installed' <<<"$out" && ok "jlink fails cleanly when not installed" || bad "jlink not-installed message (rc=$rc)"
  out=$("$L" ozone 2>&1); rc=$?
  [[ "$rc" != 0 ]] && grep -q 'Ozone not installed' <<<"$out" && ok "ozone fails cleanly when not installed" || bad "ozone not-installed (rc=$rc)"
fi
out=$("$L" plan pico_rp2040 fw.elf 2>&1)
grep -q -- '-device RP2040_M0_0 -if SWD' <<<"$out" && grep -q 'loadfile fw.elf' <<<"$out" && ok "plan pico_rp2040" || bad "plan pico"
out=$("$L" plan esp32s3_devkitc 2>&1)
grep -q 'NOT SUPPORTED by J-Link' <<<"$out" && ok "plan esp32s3: not supported" || bad "plan esp32s3"
echo "install-logic: $pass ok, $failn failed"
[[ "$failn" -eq 0 ]]
