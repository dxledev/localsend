#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 6 ]]; then
  printf 'Usage: %s BUNDLE_DIR DESTDIR BINDIR LIBDIR DATADIR DRY_RUN\n' "$0" >&2
  exit 2
fi

bundle_dir=$1
destdir=$2
bindir=$3
libdir=$4
datadir=$5
dry_run=$6

if [[ $dry_run != 0 && $dry_run != 1 ]]; then
  printf 'DRY_RUN must be 0 or 1\n' >&2
  exit 2
fi

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
if [[ $bundle_dir != /* ]]; then
  bundle_dir=$repo_root/$bundle_dir
fi

normalize_absolute_path() {
  local name=$1
  local path=$2
  local allow_empty=$3
  local allow_root=$4
  local segment
  local -a segments

  if [[ -z $path && $allow_empty == 1 ]]; then
    printf -v "$name" '%s' ''
    return
  fi

  if [[ $path != /* || $path == *//* || $path == *[[:cntrl:]]* ]]; then
    printf '%s must be a clean absolute path: %s\n' "$name" "$path" >&2
    exit 2
  fi

  IFS=/ read -r -a segments <<< "$path"
  for segment in "${segments[@]}"; do
    if [[ $segment == . || $segment == .. ]]; then
      printf '%s must not contain . or .. path components: %s\n' "$name" "$path" >&2
      exit 2
    fi
  done

  while [[ $path != / && $path == */ ]]; do
    path=${path%/}
  done

  if [[ $path == / && $allow_root != 1 ]]; then
    printf '%s must not be the filesystem root\n' "$name" >&2
    exit 2
  fi

  printf -v "$name" '%s' "$path"
}

normalize_absolute_path destdir "$destdir" 1 1
normalize_absolute_path bindir "$bindir" 0 0
normalize_absolute_path libdir "$libdir" 0 0
normalize_absolute_path datadir "$datadir" 0 0

bundle_name=localsend
app_binary=localsend_app
desktop_id=org.localsend.localsend_app
icon_source=$repo_root/app/assets/img/logo-256.png

if [[ ! -d $bundle_dir ]]; then
  if [[ $dry_run != 1 ]]; then
    printf 'Flutter bundle not found: %s\n' "$bundle_dir" >&2
    exit 1
  fi
elif [[ ! -f $bundle_dir/$app_binary || ! -x $bundle_dir/$app_binary ]]; then
  printf 'Flutter bundle is missing its executable %s: %s\n' "$app_binary" "$bundle_dir" >&2
  exit 1
fi

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

run() {
  if [[ $dry_run == 1 ]]; then
    printf 'DRY RUN:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

staged() {
  if [[ $destdir == / ]]; then
    printf '%s' "$1"
    return
  fi

  printf '%s%s' "$destdir" "$1"
}

launcher_command=$(printf '%q' "$libdir/$bundle_name/$app_binary")
launcher_target=$(staged "$bindir/$bundle_name")
bundle_target=$(staged "$libdir/$bundle_name")

if [[ $launcher_target == "$bundle_target" ]]; then
  printf 'BINDIR and LIBDIR produce the same install path: %s\n' "$launcher_target" >&2
  exit 2
fi

launcher_content() {
  printf '#!/usr/bin/env bash\nset -euo pipefail\nexec %s "$@"\n' "$launcher_command"
}

if [[ -e $launcher_target || -L $launcher_target ]]; then
  if [[ ! -f $launcher_target || -L $launcher_target ]] || ! cmp -s "$launcher_target" <(launcher_content); then
    printf 'Refusing to overwrite an unmanaged launcher: %s\n' "$launcher_target" >&2
    exit 1
  fi
fi

if [[ $dry_run != 1 && ! -f $icon_source ]]; then
  printf 'Icon asset not found: %s\n' "$icon_source" >&2
  exit 1
fi

run mkdir -p "$(staged "$libdir/$bundle_name")" "$(staged "$bindir")" \
  "$(staged "$datadir/applications")" "$(staged "$datadir/icons/hicolor/256x256/apps")"
run cp -a --remove-destination "$bundle_dir/." "$(staged "$libdir/$bundle_name/")"

if [[ $dry_run == 1 ]]; then
  run install -m 0755 /dev/null "$(staged "$bindir/$bundle_name")"
  run install -m 0644 "$icon_source" "$(staged "$datadir/icons/hicolor/256x256/apps/$desktop_id.png")"
  run install -m 0644 /dev/null "$(staged "$datadir/applications/$desktop_id.desktop")"
  exit 0
fi

launcher_tmp=$(mktemp)
desktop_tmp=$(mktemp)
trap 'rm -f "$launcher_tmp" "$desktop_tmp"' EXIT

launcher_content >"$launcher_tmp"

cat >"$desktop_tmp" <<EOF
[Desktop Entry]
Type=Application
Name=LocalSend
Comment=An open source cross-platform alternative to AirDrop
Exec=$(desktop_exec_arg "$bindir/$bundle_name") %U
TryExec=$bindir/$bundle_name
Icon=$desktop_id
Terminal=false
Categories=Network;FileTransfer;
StartupWMClass=$desktop_id
EOF

run install -D -m 0755 "$launcher_tmp" "$(staged "$bindir/$bundle_name")"
run install -D -m 0644 "$icon_source" "$(staged "$datadir/icons/hicolor/256x256/apps/$desktop_id.png")"
run install -D -m 0644 "$desktop_tmp" "$(staged "$datadir/applications/$desktop_id.desktop")"
