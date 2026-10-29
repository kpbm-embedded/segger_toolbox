#!/usr/bin/env bash
# Every segger-box command in --dry-run mode (no downloads, launches or probe access), the
# licensed-install logic on fixtures (tests/test_install_logic.sh), plus shellcheck of every script.
# Usage: tests/test_dry_run.sh
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd -P)
Q="$HERE/segger-box"
pass=0; failn=0
check() { # name expected-regex cmd...
  local name=$1 re=$2; shift 2
  local out rc
  out=$(timeout 300 "$@" 2>&1); rc=$?
  if [[ "$rc" -eq 0 ]] && grep -qE -- "$re" <<<"$out"; then
    printf 'ok    %s\n' "$name"; pass=$((pass+1))
  else
    printf 'FAIL  %s (rc=%s)\n%s\n' "$name" "$rc" "$(tail -5 <<<"$out" | sed 's/^/      /')"; failn=$((failn+1))
  fi
}
check help        'usage: \./segger-box'                   "$Q" help
check where       '^root '                                 "$Q" where
check bootstrap   'bootstrap|pixi'                         bash -c "'$Q' --dry-run bootstrap; echo pixi"
check install-gate 'refused: SEGGER licence not accepted'  bash -c "'$Q' install 2>&1; true"
check install     'accept_license_agreement=accepted .*JLink_Linux_V988' "$Q" --dry-run install --accept-license
check install-only 'Ozone_Linux_V350b'                      "$Q" --dry-run install --accept-license --only ozone
check licence     'segger.com/downloads/jlink/'            "$Q" licence
check update      'pinned vs newest'                       "$Q" --dry-run update
check clean       'nothing to clean|dry run: re-run with --yes' "$Q" clean
check clean-all   'nothing to clean|dry run: re-run with --yes' "$Q" clean --all
check status      'jlink +V9\.88'                          "$Q" status
check doctor      'doctor: [0-9]+ ok'                      bash -c "'$Q' doctor || true"
check shell       '\+ true'                                "$Q" --dry-run shell -- true
check run         '\+ echo hi'                             "$Q" --dry-run run echo hi
check test        'test_smoke\.sh'                         "$Q" --dry-run test
check new         '\+ copy .*templates/rtt_app'            "$Q" --dry-run new rtt_app demo --dir /nonexistent
check new-fw      '\+ copy .*templates/rtt_firmware'   "$Q" --dry-run new rtt_firmware demo --dir /nonexistent
check ex-list     'plan_boards .*J-Link'                   "$Q" examples list
check ex-run      'example\.sh run'                        "$Q" --dry-run examples run plan_boards
check ex-build    'example\.sh build'                      "$Q" --dry-run examples build
check ex-test     'example\.sh test'                       "$Q" --dry-run examples test
check native      'JLinkExe @jlink'                        "$Q" --dry-run native
check relocate    'pixi env already matches|re-creating'   "$Q" --dry-run relocate
check pack        '\+ tar .*-cf .*segger-box_'             "$Q" --dry-run pack
check list        '\+ lsusb'                               "$Q" --dry-run list
check boards      'STM32F411CE'                            "$Q" boards
check plan        'PRINTED ONLY'                           "$Q" plan blackpill_f411 fw.hex
check jlink       '\+ JLinkExe -?'                         "$Q" --dry-run jlink -?
check gdbserver   '\+ JLinkGDBServerCLExe'                 "$Q" --dry-run gdbserver -device STM32F411CE
check rtt         '\+ JLinkRTTViewerExe'                   "$Q" --dry-run rtt
check rtt-logger  '\+ JLinkRTTLoggerExe'                   "$Q" --dry-run rtt-logger
check rtt-client  '\+ JLinkRTTClientExe'                   "$Q" --dry-run rtt-client
check ozone       '\+ Ozone'                               "$Q" --dry-run ozone
check systemview  '\+ SystemView'                          "$Q" --dry-run systemview
check install-logic 'install-logic: [0-9]+ ok, 0 failed'   bash "$HERE/tests/test_install_logic.sh"
if command -v shellcheck >/dev/null; then
  mapfile -t files < <(cd "$HERE" && { echo segger-box; ls lib/*.bash tests/*.sh examples/*/example.sh templates/*/*.sh; })
  if out=$(cd "$HERE" && shellcheck -x "${files[@]}" 2>&1); then printf 'ok    shellcheck (%s files)\n' "${#files[@]}"; pass=$((pass+1))
  else printf 'FAIL  shellcheck\n%s\n' "$(head -30 <<<"$out")"; failn=$((failn+1)); fi
else printf 'skip  shellcheck (not installed)\n'; fi
echo "dry-run: $pass ok, $failn failed"
[[ "$failn" -eq 0 ]]
