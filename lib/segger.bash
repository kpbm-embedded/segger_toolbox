# shellcheck shell=bash disable=SC2015,SC2034  # d_* return 0; TOOL_* are read by boxtool.bash
# segger-box: tool part (hooks for lib/boxtool.bash). SEGGER J-Link Software & Documentation
# Pack (JLinkExe, JLinkGDBServer, RTT Viewer/Logger/Client), Ozone and SystemView.
# LICENCE: these are proprietary. Nothing here downloads them unless the user runs
#   ./segger-box install --accept-license
# which records who accepted what (config/local-licence.txt, gitignored), POSTs the same form
# field SEGGER's download page uses, checks the md5 SEGGER publishes on that page, and pins the
# sha256 on first use (config/pins.local.tsv, gitignored; a later mismatch aborts).
# The licensed table is config/licensed.tsv, NOT config/pins.tsv, so `bootstrap` never fetches it.
# OPEN parts (config/pins.tsv, installed by bootstrap): xPack arm-none-eabi-gcc/gdb and SEGGER's
# BSD-licensed RTT and SystemView target sources from GitHub; lib/cmsim.py (pixi env: unicorn,
# pyelftools) runs firmware without a probe for the examples and templates.
# SAFETY: nothing here flashes, erases, resets or writes a target on its own: `list` is lsusb
# only (J-Link Commander can update probe firmware on connect, so it is never run for listing),
# `plan` prints commands, and the pass-through wrappers run whatever *you* type.
TOOL_TITLE="32_12_segger: SEGGER J-Link $(awk -F'\t' '$1=="jlink"{print $2; exit}' "${BOXT_ROOT:?}/config/licensed.tsv"), Ozone $(awk -F'\t' '$1=="ozone"{print $2; exit}' "$BOXT_ROOT/config/licensed.tsv"), SystemView $(awk -F'\t' '$1=="systemview"{print $2; exit}' "$BOXT_ROOT/config/licensed.tsv") (user-accepted licence)"
TOOL_INSTALL_WHAT="the licensed SEGGER packages (only with --accept-license)"
TOOL_HELP_USE="  install --accept-license [--only jlink,ozone,systemview]
                          YOU accept SEGGER's terms; downloads the pinned Linux x86_64 .tgz
                          (without the flag: prints the licence URLs and exits 2)
  licence                 the licence URLs and what has been accepted on this machine
  list                    read-only: J-Links on USB (lsusb 1366:*)
  boards                  owned boards -> J-Link device name (config/boards.tsv)
  plan <board> [fw.elf|.hex|.bin]   PRINT JLinkExe/JLinkGDBServer commands (runs nothing)
  jlink | gdbserver | rtt | rtt-logger | rtt-client | ozone | systemview [args]
                          the installed SEGGER tools (fail cleanly when not installed)"
hook_help() { # printed after boxtool's help: tool-specific examples and environment
  cat <<EOF

tool examples
  ./$BOXT_NAME licence && ./$BOXT_NAME install --accept-license --only jlink
  ./$BOXT_NAME plan blackpill_f411 build/fw.hex
tool environment (tests use these to run the licensed install on fixtures)
  SEGGER_BOX_LICENSED_TSV, SEGGER_BOX_TOFU_TSV, SEGGER_BOX_LICENCE_RECORD,
  SEGGER_BOX_INSTALL_DIR, SEGGER_BOX_DOWNLOAD_DIR   default: config/licensed.tsv, config/pins.local.tsv,
                          config/local-licence.txt, install/, cache/downloads
EOF
}
# shellcheck source-path=SCRIPTDIR source=boxtool.bash
. "$BOXT_ROOT/lib/boxtool.bash"

LICENSED=${SEGGER_BOX_LICENSED_TSV:-$CONFIG/licensed.tsv}   # tests point this at a fixture table
TOFU=${SEGGER_BOX_TOFU_TSV:-$CONFIG/pins.local.tsv}
LICREC=${SEGGER_BOX_LICENCE_RECORD:-$CONFIG/local-licence.txt}
LINST=${SEGGER_BOX_INSTALL_DIR:-$INST}
LDL=${SEGGER_BOX_DOWNLOAD_DIR:-$DL}
BOARDS="$CONFIG/boards.tsv"

# ---------- licensed table ----------
# columns: name version platform md5 url licence-urls(space separated) title
lic_rows() { [[ -r "$LICENSED" ]] && awk -F'\t' '!/^[[:space:]]*#/ && NF>=6' "$LICENSED"; true; }
lic_names() { lic_rows | awk -F'\t' -v p="$PLATFORM" '$3==p {print $1}' | awk '!s[$0]++'; }
lic_get() { lic_rows | awk -F'\t' -v n="$1" -v p="$PLATFORM" -v f="$2" '$1==n && $3==p {print $f; exit}'; }
lic_file() { local u; u=$(lic_get "$1" 5); printf '%s/%s' "$LDL" "$(basename "${u%%\?*}")"; }
lic_dir() { printf '%s/%s-%s' "$LINST" "$1" "$(lic_get "$1" 2)"; }
lic_installed() { [[ -e "$(lic_dir "$1")/.boxt-ok" ]]; }
md5_of() { if have md5sum; then md5sum "$1" | cut -d' ' -f1; else md5 -q "$1"; fi; }

# TOFU table: name version file sha256 date
tofu_get() { [[ -r "$TOFU" ]] && awk -F'\t' -v n="$1" -v v="$2" '$1==n && $2==v {print $4; exit}' "$TOFU"; true; }
tofu_check() { # name version file -> 0 ok (recorded or matching), 1 mismatch
  local n=$1 v=$2 f=$3 want have_s
  have_s=$(sha_of sha256 "$f")
  want=$(tofu_get "$n" "$v")
  if [[ -z "$want" ]]; then
    mkdir -p "$(dirname "$TOFU")"
    [[ -e "$TOFU" ]] || printf '# name\tversion\tfile\tsha256\tdate  (trust on first use, written by segger-box install; gitignored)\n' >"$TOFU"
    printf '%s\t%s\t%s\t%s\t%s\n' "$n" "$v" "$(basename "$f")" "$have_s" "$(date -Iseconds)" >>"$TOFU"
    info "$n $v: sha256 $have_s recorded (TOFU, $(basename "$TOFU"))"
    return 0
  fi
  if [[ "$want" = "$have_s" ]]; then info "$n $v: sha256 matches the pin from first use"; return 0; fi
  warn "$n $v: sha256 $have_s differs from the first-use pin $want"
  return 1
}

licence_urls() { lic_rows | awk -F'\t' -v p="$PLATFORM" '$3==p {n=split($6,a," "); for(i=1;i<=n;i++) print $1": "a[i]}' | awk '!s[$0]++'; }

print_licences() {
  cat <<EOF
SEGGER software is proprietary. Read and accept the terms yourself before installing:
$(licence_urls | sed 's/^/  /')
  (each package also ships its own licence file; J-Link: JLink/Doc/ and license.txt)
Then run:  ./$NAME install --accept-license        (records your acceptance in config/local-licence.txt)
EOF
}

record_acceptance() { # names...
  [[ "$DRY" = 1 ]] && { printf '+ record acceptance -> %s\n' "$LICREC"; return 0; }
  mkdir -p "$(dirname "$LICREC")"
  {
    printf '# %s licence acceptance (gitignored; written by ./%s install --accept-license)\n' "${LICREC##*/}" "$NAME"
    printf 'accepted_by=%s@%s\naccepted_at=%s\n' "${USER:-$(id -un)}" "$(hostname 2>/dev/null || echo host)" "$(date -Iseconds)"
    local n
    for n in "$@"; do printf 'package=%s %s %s\n' "$n" "$(lic_get "$n" 2)" "$(lic_get "$n" 6)"; done
    printf '\n'
  } >>"$LICREC"
}

fetch_licensed() { # name -> file in cache/downloads (md5 from SEGGER's page + TOFU sha256)
  local n=$1 url md5w f data=()
  url=$(lic_get "$n" 5); md5w=$(lic_get "$n" 4); f=$(lic_file "$n")
  [[ -n "$url" ]] || die "no licensed entry for '$n' on $PLATFORM"
  case "$url" in http://*|https://*) data=(--data 'accept_license_agreement=accepted&submit=Download+software') ;; esac
  if [[ -f "$f" ]] && [[ "$(md5_of "$f")" = "$md5w" ]]; then
    tofu_check "$n" "$(lic_get "$n" 2)" "$f" || die "$n: cached $f does not match the first-use sha256; inspect it, then move it to the Trash"
    return 0
  fi
  info "download $n $(lic_get "$n" 2): $url"
  if [[ "$DRY" = 1 ]]; then printf '+ curl -fL --data accept_license_agreement=accepted %s -> %s (md5 %s, sha256 TOFU)\n' "$url" "$f" "$md5w"; return 0; fi
  mkdir -p "$LDL"; cachedir_tag "$(dirname "$LDL")"
  curl -fL -sS --retry 3 --connect-timeout 30 --max-time "$NET_TIMEOUT" "${data[@]+"${data[@]}"}" -o "$f.part" "$url" || die "download failed: $url"
  if [[ "$(head -c 15 "$f.part" | tr -d '\r\n ' | tr '[:upper:]' '[:lower:]')" = '<!doctypehtml>' ]] || head -c 200 "$f.part" | grep -i '<html' >/dev/null; then
    die "$n: got an HTML page instead of the archive (licence form changed?); kept $f.part"
  fi
  local m; m=$(md5_of "$f.part")
  [[ "$m" = "$md5w" ]] || die "$n: md5 $m != $md5w published by SEGGER; kept $f.part for inspection"
  tofu_check "$n" "$(lic_get "$n" 2)" "$f.part" || die "$n: sha256 mismatch against the first-use pin; kept $f.part (abort)"
  mv "$f.part" "$f"
}

unpack_licensed() { # name -> install/<name>-<ver>/ (single top folder flattened) + install/<name> link
  local n=$1 dir tmp top
  dir=$(lic_dir "$n")
  [[ -e "$dir/.boxt-ok" ]] && return 0
  info "install $n -> $dir"
  if [[ "$DRY" = 1 ]]; then printf '+ unpack %s -> %s\n' "$(lic_file "$n")" "$dir"; return 0; fi
  mkdir -p "$LINST"
  [[ -e "$dir" ]] && trash_paths "incomplete install of $n" "$dir"
  tmp="$LINST/.tmp-$n"
  [[ -e "$tmp" ]] && trash_paths "stale unpack dir" "$tmp"
  unpack "$(lic_file "$n")" tar "$tmp"
  if [[ "$(find "$tmp" -mindepth 1 -maxdepth 1 | wc -l)" = 1 ]] && top=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d) && [[ -n "$top" ]]; then
    mv "$top" "$dir"; rmdir "$tmp"
  else mv "$tmp" "$dir"; fi
  printf 'name=%s\nversion=%s\nurl=%s\nmd5=%s\nsha256=%s\ndate=%s\n' "$n" "$(lic_get "$n" 2)" "$(lic_get "$n" 5)" \
    "$(lic_get "$n" 4)" "$(tofu_get "$n" "$(lic_get "$n" 2)")" "$(date -Iseconds)" >"$dir/.boxt-ok"
  ln -sfn "$(basename "$dir")" "$LINST/$n"
}

# install --accept-license [--only a,b] [--no-demos]: replaces boxtool's install (which knows no licence flag)
tool_install() {
  local accept=0 only="" n names=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --accept-license|--accept-licence) accept=1 ;;
      --only) only=${2:?--only needs names}; shift ;;
      --no-demos|--with-demos|--all) ;;
      *) usage_error "install: unknown option $1" ;;
    esac; shift
  done
  if [[ "$accept" != 1 ]]; then
    print_licences >&2
    usage_error "refused: SEGGER licence not accepted (add --accept-license after reading the terms)"
  fi
  for n in $(lic_names); do
    if [[ -n "$only" ]] && ! grep -qw -- "$n" <<<"${only//,/ }"; then continue; fi
    names+=("$n")
  done
  [[ ${#names[@]} -gt 0 ]] || die "nothing to install for $PLATFORM (SEGGER Linux x86_64 tgz only are pinned; see README 'Other OSes')"
  cmd_bootstrap
  record_acceptance "${names[@]}"
  cachedir_tag "$LINST"
  for n in "${names[@]}"; do fetch_licensed "$n"; unpack_licensed "$n"; done
  [[ "$DRY" = 1 ]] || { [[ "$LINST" = "$INST" ]] && cmd_native; info "install done: ./$NAME doctor; udev rules: README 'udev' (sudo, you run it)"; }
}

hook_update_check() { # SEGGER's GitHub repos (RTT, SystemView) have tags, no releases; licensed pins are bumped by hand
  local repo pinned latest
  while read -r repo pinned; do
    if [[ "$DRY" = 1 ]]; then printf '+ curl https://api.github.com/repos/%s/tags\n' "$repo"; continue; fi
    local auth=(); [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
    latest=$(curl -fsS --connect-timeout 20 --max-time 60 "${auth[@]+"${auth[@]}"}" "https://api.github.com/repos/$repo/tags?per_page=1" 2>/dev/null \
      | sed -n 's/^ *"name": *"\([^"]*\)".*/\1/p' | head -1) || true
    printf '  %-14s pinned %-16s latest %-16s %s (tags)\n' "${repo#*/}" "$pinned" "${latest:-? (offline or API rate limit)}" "$repo"
  done <<EOF2
SEGGERMicro/RTT $(pin_get rtt 2)
SEGGERMicro/SystemView $(pin_get systemview-src 2)
EOF2
  echo "  licensed packages: compare config/licensed.tsv with https://www.segger.com/downloads/jlink/ (no API)"
}

tool_cmd_licence() {
  print_licences
  if [[ -r "$LICREC" ]]; then echo "accepted on this machine ($LICREC):"; grep -E '^(accepted_|package=)' "$LICREC" | sed 's/^/  /'
  else echo "not accepted on this machine yet"; fi
}
tool_cmd_license() { tool_cmd_licence "$@"; }

# ---------- installed tools ----------
seg_bin() { # name binary -> path or empty
  local d="$LINST/$1" b
  [[ -d "$d/" ]] || return 0
  for b in "$d/$2" "$d/bin/$2"; do [[ -x "$b" ]] && { printf '%s' "$b"; return 0; }; done
  b=$(find "$d/" -maxdepth 3 -type f -name "$2" -perm -u+x 2>/dev/null | head -1); printf '%s' "$b"
}
need_bin() { # pkg binary -> path or die
  local p; p=$(seg_bin "$1" "$2")
  [[ -n "$p" ]] || die "$2 not installed ($1 is licensed: read './$NAME licence', then ./$NAME install --accept-license --only $1)"
  printf '%s' "$p"
}

sibling_id() { # ENV_VAR FOLDER MARKER -> another tool ID: the variable's folder (or one above it) holding MARKER,
  # else ../FOLDER next to this ID, else nothing (same lookup as 32_30_robot_framework)
  local d=${!1:-} i
  for i in 1 2 3; do
    [[ -n "$d" ]] && [[ -e "$d/$3" ]] && { (cd -P "$d" && pwd -P); return 0; }
    d=${d%/*}
  done
  if [[ -e "$ROOT/../$2/$3" ]]; then (cd -P "$ROOT/../$2" && pwd -P); fi
  return 0
}

hook_env() {
  local d
  for d in "$LINST/jlink" "$LINST/ozone" "$LINST/systemview"; do [[ -d "$d/" ]] && PATH="$d:$PATH"; done
  # open parts from config/pins.tsv (bootstrap): pinned arm-none-eabi-gcc/gdb, SEGGER's RTT and SystemView sources
  [[ -d "$INST/arm-gcc/bin" ]] && PATH="$INST/arm-gcc/bin:$PATH"
  export PATH SEGGER_BOX_ROOT="$ROOT" SEGGER_BOX_BOARDS="$BOARDS" SEGGER_JLINK_DIR="$LINST/jlink"
  export SEGGER_RTT_DIR="$INST/rtt" SEGGER_SYSVIEW_DIR="$INST/systemview-src"
  # other tool IDs, reached (never copied): Rust (32_17), Zig (32_24), AtomVM (32_29); empty when missing
  SEGGER_RUST_ID=$(sibling_id BOX_EMBEDDED_RUST 32_17_embedded_rust rust-box)
  SEGGER_ZIG_ID=$(sibling_id BOX_MICROZIG 32_24_microzig microzig-box)
  SEGGER_ATOMVM_ID=$(sibling_id BOX_ATOMVM 32_29_atomvm atomvm-box)
  export SEGGER_RUST_ID SEGGER_ZIG_ID SEGGER_ATOMVM_ID
  # Qt GUIs (RTT Viewer, Ozone, SystemView) and J-Link's own settings stay in the ID
  export XDG_CONFIG_HOME="$ROOT/cache/xdg-config" XDG_DATA_HOME="$ROOT/cache/xdg-data" XDG_CACHE_HOME="$ROOT/cache/xdg-cache"
  mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" 2>/dev/null || true
}
hook_bootstrap() { cachedir_tag "$ROOT/cache"; }

hook_status() {
  local n
  for n in $(lic_names); do
    printf '  %-22s %-12s %-9s %s\n' "$n" "$(lic_get "$n" 2)" licensed "$(lic_installed "$n" && echo "installed $(human_size "$(lic_dir "$n")")" || echo 'not installed (needs --accept-license)')"
  done
  printf '  %-22s %s\n' licence "$([[ -r "$LICREC" ]] && echo "accepted ($(grep -c '^accepted_at' "$LICREC")x)" || echo 'not accepted')"
  printf '  %-22s %s boards in config/boards.tsv\n' boards "$(board_rows | wc -l)"
}

hook_doctor() {
  local n p
  # open parts (bootstrap, listed above by boxtool): toolchain on PATH and the host helpers in the pixi env
  if have arm-none-eabi-gcc && have arm-none-eabi-gdb; then d_ok "arm-none-eabi-gcc $(arm-none-eabi-gcc -dumpversion) + gdb on PATH (pinned)"
  else d_fail "arm-none-eabi-gcc/gdb not on PATH (./$NAME bootstrap)"; fi
  if python3 -c 'import unicorn, elftools' 2>/dev/null; then d_ok "cmsim helpers: unicorn $(python3 -c 'import unicorn; print(unicorn.__version__)'), pyelftools (pixi env)"
  else d_fail "unicorn/pyelftools missing in the pixi env (./$NAME bootstrap)"; fi
  local v id f x
  for v in "Rust:BOX_EMBEDDED_RUST:32_17_embedded_rust:rust-box" "Zig:BOX_MICROZIG:32_24_microzig:microzig-box" "AtomVM:BOX_ATOMVM:32_29_atomvm:atomvm-box"; do
    IFS=: read -r n p f x <<<"$v"
    id=$(sibling_id "$p" "$f" "$x")
    [[ -n "$id" ]] && d_ok "$n examples: ${id##*/} found" || d_warn "$n examples skip (exit 3): $f not found, set $p"
  done
  [[ -r "$LICENSED" ]] && d_ok "licensed table: $(lic_names | wc -l) packages for $PLATFORM" || d_fail "config/licensed.tsv missing"
  for n in $(lic_names); do
    if lic_installed "$n"; then d_ok "$n $(lic_get "$n" 2) installed (user-accepted licence)"
    else d_warn "$n $(lic_get "$n" 2) not installed: licensed, needs './$NAME install --accept-license' by you"; fi
  done
  if lic_installed jlink; then
    p=$(seg_bin jlink JLinkExe); [[ -n "$p" ]] && d_ok "JLinkExe present" || d_fail "JLinkExe missing in install/jlink"
    p=$(seg_bin jlink JLinkGDBServerCLExe); [[ -n "$p" ]] && d_ok "JLinkGDBServerCLExe present" || d_fail "JLinkGDBServerCLExe missing"
    p=$(seg_bin jlink JLinkRTTViewerExe); [[ -n "$p" ]] && d_ok "RTT Viewer present (ships in the J-Link pack)" || d_warn "JLinkRTTViewerExe missing"
  fi
  if [[ -e /etc/udev/rules.d/99-jlink.rules ]] || [[ -e /usr/lib/udev/rules.d/99-jlink.rules ]] || [[ -e /etc/udev/rules.d/70-box-segger.rules ]]; then
    d_ok "J-Link udev rules present"
  else d_warn "J-Link udev rules not installed: probes need root (README 'udev', sudo, you run it)"; fi
  have lsusb && d_ok "lsusb available (list)" || d_warn "lsusb missing: list cannot enumerate"
  [[ -r "$BOARDS" ]] && d_ok "boards table: $(board_rows | wc -l) boards" || d_fail "config/boards.tsv missing"
  [[ -r "$ROOT/udev/70-box-segger.rules" ]] && d_ok "udev/70-box-segger.rules shipped" || d_fail "udev/70-box-segger.rules missing"
}

hook_native_bins() {
  echo "JLinkExe @jlink"
  echo "JLinkGDBServer @gdbserver"
  echo "JLinkRTTViewer @rtt"
  echo "JLinkRTTLogger @rtt-logger"
  echo "JLinkRTTClient @rtt-client"
  echo "ozone @ozone"
  echo "systemview @systemview"
}

exec_tool() { # pkg binary args...
  local pkg=$1 b=$2; shift 2
  activate
  if [[ "$DRY" = 1 ]]; then printf '+ %s %s\n' "$b" "$*"; return 0; fi
  local p; p=$(need_bin "$pkg" "$b")
  exec "$p" "$@"
}
tool_cmd_jlink() { exec_tool jlink JLinkExe "$@"; }
tool_cmd_gdbserver() { exec_tool jlink JLinkGDBServerCLExe "$@"; }
tool_cmd_rtt() { exec_tool jlink JLinkRTTViewerExe "$@"; }
tool_cmd_rtt-logger() { exec_tool jlink JLinkRTTLoggerExe "$@"; }
tool_cmd_rtt-client() { exec_tool jlink JLinkRTTClientExe "$@"; }
tool_cmd_ozone() { exec_tool ozone Ozone "$@"; }
tool_cmd_systemview() { exec_tool systemview SystemView "$@"; }

# ---------- list (read-only) ----------
tool_cmd_list() {
  if [[ "$DRY" = 1 ]]; then echo "+ lsusb (filter 1366:*)"; return 0; fi
  have lsusb || die "lsusb not found (usbutils)"
  echo "== J-Link / J-Trace probes on USB (vendor 1366, read-only lsusb)"
  lsusb | grep -i ' 1366:' || echo "(none)"
  echo "# J-Link Commander is not run for listing: it may update the probe firmware on connect."
}

# ---------- boards / plan (prints only) ----------
board_rows() { [[ -r "$BOARDS" ]] && awk -F'\t' '!/^#/ && $1!="board" && NF>=5' "$BOARDS"; true; }
board_get() { board_rows | awk -F'\t' -v b="$1" '$1==b'; }
tool_cmd_boards() {
  { printf 'board\tchip\tjlink-device\tinterface\tflash-base\n'; board_rows | cut -f1-5; } | column -t -s "$(printf '\t')"
}

tool_cmd_plan() {
  local b=${1:-} fw=${2:-fw.elf}
  [[ -n "$b" ]] || usage_error "usage: ./$NAME plan <board|all> [firmware.elf|.hex|.bin] (boards: ./$NAME boards)"
  if [[ "$b" = all ]]; then
    local x; for x in $(board_rows | cut -f1); do tool_cmd_plan "$x" "$fw"; echo; done; return 0
  fi
  local row; row=$(board_get "$b")
  [[ -n "$row" ]] || usage_error "unknown board '$b' (./$NAME boards)"
  local chip dev ifc base notes ext speed
  chip=$(cut -f2 <<<"$row"); dev=$(cut -f3 <<<"$row"); ifc=$(cut -f4 <<<"$row"); base=$(cut -f5 <<<"$row"); notes=$(cut -f6 <<<"$row")
  speed=$(cut -f7 <<<"$row"); [[ -n "$speed" ]] || speed=4000
  ext=${fw##*.}
  echo "# J-Link plan for $b ($chip): PRINTED ONLY, nothing was run."
  echo "# notes: ${notes:--}"
  if [[ "$dev" = - ]]; then
    echo "# NOT SUPPORTED by J-Link: $notes"
    return 0
  fi
  local load="loadfile $fw"
  [[ "$ext" = bin ]] && load="loadbin $fw $base
verifybin $fw $base"
  cat <<EOF
# 1) flash (J-Link Commander script; writes the target when YOU run it)
cat > flash_$b.jlink <<'JL'
r
h
$load
r
g
exit
JL
./$NAME jlink -device $dev -if $ifc -speed $speed -autoconnect 1 -NoGui 1 -ExitOnError 1 -CommanderScript flash_$b.jlink
# 2) GDB server (debug with arm-none-eabi-gdb / lldb: target remote :2331)
./$NAME gdbserver -device $dev -if $ifc -speed $speed -port 2331 -swoport 2332 -telnetport 2333 -nogui -singlerun
# 3) RTT (target firmware linked with SEGGER_RTT, see templates/rtt_app)
./$NAME rtt-logger -Device $dev -If $ifc -Speed $speed -RTTChannel 0 rtt_$b.log
./$NAME rtt                                   # RTT Viewer GUI (connect: $dev, $ifc, $speed kHz)
# 4) Ozone / SystemView (GUIs)
./$NAME ozone                                  # new project: device $dev, $ifc, file $fw
./$NAME systemview                             # Target -> Start Recording: device $dev, $ifc
EOF
  return 0
}

boxt_main_segger() {
  case "${1:-help}" in
    install) shift; tool_install "$@" ;;
    *) boxt_main "$@" ;;
  esac
}
boxt_main_segger "$@"
