#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 077

if (( $# != 2 )); then
  printf 'usage: %s ENGINE_ROOT WINE_RELATIVE_PATH\n' "$0" >&2
  exit 64
fi

engine_root=$1
wine_relative=$2
wine="$engine_root/$wine_relative"
[[ -x "$wine" ]] || { printf 'Wine executable is not executable: %s\n' "$wine" >&2; exit 66; }
wineserver="$engine_root/bin/wineserver"
[[ -x "$wineserver" ]] || { printf 'wineserver is not executable: %s\n' "$wineserver" >&2; exit 66; }

prefix=$(mktemp -d "${TMPDIR:-/tmp}/wineforge-engine-smoke.XXXXXX")
cleanup() {
  WINEPREFIX="$prefix" "$wineserver" -k >/dev/null 2>&1 || true
  rm -rf -- "$prefix"
}
trap cleanup EXIT HUP INT TERM

output=$(WINEPREFIX="$prefix" WINEDEBUG=-all ROSETTA_ADVERTISE_AVX=1 "$wine" cmd /c ver 2>&1) || {
  printf '%s\n' "$output" >&2
  printf 'fresh-prefix engine acceptance failed\n' >&2
  exit 70
}
printf '%s\n' "$output" | grep -Eq 'Microsoft Windows [0-9]+' || {
  printf '%s\n' "$output" >&2
  printf 'fresh-prefix engine acceptance returned no Windows version\n' >&2
  exit 70
}
printf 'fresh-prefix engine acceptance passed: %s\n' "$(printf '%s\n' "$output" | grep -E 'Microsoft Windows [0-9]+' | tail -1)"
