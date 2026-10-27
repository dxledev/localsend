#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [--dry-run]\n' "${0##*/}"
  printf 'Prepare the Rustup toolchain pinned by RUST_TOOLCHAIN_FILE for a local Linux build.\n'
}

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
rustup_bin_dir=${RUSTUP_BIN_DIR:-$repo_root/.fvm/tools}
rustup_home=${RUSTUP_HOME:-$repo_root/.fvm/tools/rustup-home}
toolchain_file=${RUST_TOOLCHAIN_FILE:-$repo_root/packages/localsend_isolates/rust-toolchain.toml}
rustup_path=$rustup_bin_dir/rustup
dry_run=${DRY_RUN:-0}

case ${1:-} in
  '') ;;
  --dry-run) dry_run=1 ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

if [[ $dry_run != 0 && $dry_run != 1 ]]; then
  printf 'DRY_RUN must be 0 or 1\n' >&2
  exit 2
fi

validate_absolute_path() {
  local name=$1
  local value=$2

  if [[ $value != /* || $value == *[[:cntrl:]]* ]]; then
    printf '%s must be an absolute path: %s\n' "$name" "$value" >&2
    exit 2
  fi
}

validate_absolute_path RUSTUP_BIN_DIR "$rustup_bin_dir"
validate_absolute_path RUSTUP_HOME "$rustup_home"
validate_absolute_path RUST_TOOLCHAIN_FILE "$toolchain_file"

if [[ ! -f $toolchain_file ]]; then
  printf 'Rust toolchain file not found: %s\n' "$toolchain_file" >&2
  exit 1
fi

toolchain=''
while IFS= read -r line || [[ -n $line ]]; do
  if [[ $line =~ ^[[:space:]]*channel[[:space:]]*=[[:space:]]*\"([^\"]+)\"[[:space:]]*$ ]]; then
    if [[ -n $toolchain ]]; then
      printf 'Multiple channel entries found in %s\n' "$toolchain_file" >&2
      exit 1
    fi
    toolchain=${BASH_REMATCH[1]}
  fi
done <"$toolchain_file"

if [[ ! $toolchain =~ ^(stable|beta|nightly|[0-9]+\.[0-9]+(\.[0-9]+)?)(-[[:alnum:].]+)?$ ]]; then
  printf 'Could not read a supported Rust toolchain channel from %s\n' "$toolchain_file" >&2
  exit 1
fi

find_rustup() {
  local candidate

  if [[ -n ${HOME:-} && -e $HOME/.cargo/bin/rustup ]]; then
    candidate=$HOME/.cargo/bin/rustup
  elif [[ -e $rustup_path ]]; then
    candidate=$rustup_path
  else
    candidate=$(command -v rustup || true)
  fi

  if [[ -n $candidate ]]; then
    if [[ ! -x $candidate ]]; then
      printf 'Rustup is not executable: %s\n' "$candidate" >&2
      exit 1
    fi
    printf '%s\n' "$candidate"
  fi
}

rustup_command=$(find_rustup)

if [[ $(uname -s) != Linux ]]; then
  printf 'Local Rustup setup supports Linux only\n' >&2
  exit 1
fi

case $(uname -m) in
  x86_64) rustup_host=x86_64-unknown-linux-gnu ;;
  aarch64) rustup_host=aarch64-unknown-linux-gnu ;;
  *)
    printf 'Unsupported Linux architecture for local Rustup setup: %s\n' "$(uname -m)" >&2
    exit 1
    ;;
esac

download_dir=''
publish_tmp=''

cleanup() {
  if [[ -n $download_dir ]]; then
    rm -rf -- "$download_dir"
  fi
  if [[ -n $publish_tmp ]]; then
    rm -f -- "$publish_tmp"
  fi
}
trap cleanup EXIT

download_rustup() {
  local url checksum_url binary_tmp checksum_tmp expected_checksum checksum_name

  url=https://static.rust-lang.org/rustup/dist/$rustup_host/rustup-init
  checksum_url=$url.sha256

  if [[ $dry_run == 1 ]]; then
    printf 'DRY RUN: download %s and %s\n' "$url" "$checksum_url"
    printf 'DRY RUN: verify SHA-256, then atomically publish %s\n' "$rustup_path"
    rustup_command=$rustup_path
    return
  fi

  for command_name in curl sha256sum mktemp install mv; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      printf 'Required command not found: %s\n' "$command_name" >&2
      exit 1
    fi
  done

  download_dir=$(mktemp -d "${TMPDIR:-/tmp}/localsend-rustup.XXXXXX")
  binary_tmp=$download_dir/rustup-init
  checksum_tmp=$download_dir/rustup-init.sha256

  curl --proto '=https' --tlsv1.2 -fsSL -o "$binary_tmp" "$url"
  curl --proto '=https' --tlsv1.2 -fsSL -o "$checksum_tmp" "$checksum_url"

  checksum_name=''
  expected_checksum=''
  if ! IFS=' ' read -r expected_checksum checksum_name <"$checksum_tmp"; then
    printf 'Could not read Rustup SHA-256 file: %s\n' "$checksum_url" >&2
    exit 1
  fi
  checksum_name=${checksum_name#\*}
  checksum_name=${checksum_name#./}
  if [[ ! $expected_checksum =~ ^[[:xdigit:]]{64}$ || ( -n $checksum_name && $checksum_name != rustup-init ) ]]; then
    printf 'Unexpected Rustup SHA-256 file format: %s\n' "$checksum_url" >&2
    exit 1
  fi

  if ! printf '%s  %s\n' "$expected_checksum" "$binary_tmp" | sha256sum --check --status -; then
    printf 'SHA-256 verification failed for %s\n' "$url" >&2
    exit 1
  fi

  mkdir -p -- "$rustup_bin_dir"
  publish_tmp=$(mktemp "$rustup_bin_dir/.rustup.XXXXXX")
  install -m 0755 -- "$binary_tmp" "$publish_tmp"
  mv -f -- "$publish_tmp" "$rustup_path"
  publish_tmp=''
  rustup_command=$rustup_path
}

if [[ -z $rustup_command ]]; then
  download_rustup
fi

if [[ $dry_run == 1 ]]; then
  if [[ -z $rustup_command ]]; then
    rustup_command=$rustup_path
  fi
  printf 'DRY RUN: RUSTUP_HOME=%s %s set auto-self-update disable\n' "$rustup_home" "$rustup_command"
  printf 'DRY RUN: RUSTUP_HOME=%s %s toolchain install %s --profile minimal --no-self-update\n' \
    "$rustup_home" "$rustup_command" "$toolchain"
  exit 0
fi

(cd / && RUSTUP_HOME="$rustup_home" "$rustup_command" set auto-self-update disable)

installed=0
toolchain_list=$(cd / && RUSTUP_HOME="$rustup_home" "$rustup_command" toolchain list)
while IFS= read -r line; do
  installed_name=${line%% *}
  if [[ $installed_name == "$toolchain" || $installed_name == "$toolchain-"* ]]; then
    installed=1
    break
  fi
done <<<"$toolchain_list"

if [[ $installed == 1 ]]; then
  printf 'Rust toolchain %s is already installed in %s\n' "$toolchain" "$rustup_home"
else
  (cd / && RUSTUP_HOME="$rustup_home" "$rustup_command" toolchain install "$toolchain" --profile minimal --no-self-update)
fi
