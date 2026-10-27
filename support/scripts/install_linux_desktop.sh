#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  printf 'Usage: %s BINDIR DESTDIR DESKTOPDIR DRY_RUN\n' "$0" >&2
  exit 2
fi

bindir=$1
destdir=$2
desktopdir=$3
dry_run=$4

if [[ $dry_run != 0 && $dry_run != 1 ]]; then
  printf 'DRY_RUN must be 0 or 1\n' >&2
  exit 2
fi

normalize_absolute_path() {
  local name=$1
  local value=$2
  local allow_empty=$3
  local segment
  local -a segments

  if [[ -z $value && $allow_empty == 1 ]]; then
    printf -v "$name" '%s' ''
    return
  fi
  if [[ $value != /* || $value == *//* || $value == *[[:cntrl:]]* ]]; then
    printf '%s must be a clean absolute path: %s\n' "$name" "$value" >&2
    exit 2
  fi

  IFS=/ read -r -a segments <<< "$value"
  for segment in "${segments[@]}"; do
    if [[ $segment == . || $segment == .. ]]; then
      printf '%s must not contain . or .. path components: %s\n' "$name" "$value" >&2
      exit 2
    fi
  done

  while [[ $value != / && $value == */ ]]; do
    value=${value%/}
  done
  printf -v "$name" '%s' "$value"
}

normalize_absolute_path bindir "$bindir" 0
normalize_absolute_path destdir "$destdir" 1
normalize_absolute_path desktopdir "$desktopdir" 0

desktop_id=org.localsend.localsend_app
desktop_exec_arg() {
  local value=$1
  local escaped=''
  local character
  local index

  for ((index = 0; index < ${#value}; index++)); do
    character=${value:index:1}
    case $character in
      \\) escaped+='\\' ;;
      '"'|'$'|$'\x60') escaped+="\\$character" ;;
      '%') escaped+='%%' ;;
      *) escaped+=$character ;;
    esac
  done

  printf '"%s"' "$escaped"
}

desktop_target=$desktopdir/$desktop_id.desktop
if [[ $destdir == / ]]; then
  staged_target=$desktop_target
elif [[ -z $destdir ]]; then
  staged_target=$desktop_target
else
  staged_target=$destdir$desktop_target
fi

if ! command -v desktop-file-validate >/dev/null 2>&1; then
  printf 'desktop-file-validate is required to install the desktop entry\n' >&2
  exit 1
fi

desktop_tmp=$(mktemp --suffix=.desktop)
trap 'rm -f "$desktop_tmp"' EXIT

cat >"$desktop_tmp" <<EOF
[Desktop Entry]
Type=Application
Name=LocalSend
Comment=An open source cross-platform alternative to AirDrop
Exec=$(desktop_exec_arg "$bindir/localsend") %U
TryExec=$bindir/localsend
Icon=$desktop_id
Terminal=false
Categories=Network;FileTransfer;
StartupWMClass=$desktop_id
EOF

desktop-file-validate "$desktop_tmp"

if [[ $dry_run == 1 ]]; then
  printf 'DRY RUN: install -D -m 0644 %q %q\n' "$desktop_tmp" "$staged_target"
else
  install -D -m 0644 "$desktop_tmp" "$staged_target"
fi
