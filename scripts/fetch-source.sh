#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 022

if (( $# != 2 )); then
  printf 'usage: %s VERSION DESTINATION\n' "$0" >&2
  exit 64
fi

version=$1
destination=$2
repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$repo_dir/engines/crossover-$version.json"

if [[ ! -f "$manifest" ]]; then
  printf 'unsupported version: %s\n' "$version" >&2
  exit 64
fi

for command_name in curl jq shasum tar; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$command_name" >&2
    exit 69
  }
done

url=$(jq -er '.source.url' "$manifest")
expected_sha256=$(jq -er '.source.sha256' "$manifest")
archive=$(mktemp "${TMPDIR:-/tmp}/wineforge-source.XXXXXX")
cleanup() { rm -f -- "$archive"; }
trap cleanup EXIT HUP INT TERM

curl --fail --location --proto '=https' --tlsv1.2 \
  --retry 3 --retry-all-errors --output "$archive" "$url"
actual_sha256=$(shasum -a 256 "$archive" | awk '{print $1}')
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
  printf 'source digest mismatch: expected %s, got %s\n' \
    "$expected_sha256" "$actual_sha256" >&2
  exit 65
fi

while IFS= read -r member; do
  case "$member" in
    /*|../*|*/../*|*/..)
      printf 'unsafe archive path: %s\n' "$member" >&2
      exit 65
      ;;
  esac
done < <(tar -tzf "$archive")

if [[ -e "$destination" ]]; then
  printf 'destination already exists: %s\n' "$destination" >&2
  exit 73
fi
mkdir -p -- "$destination"
tar -xzf "$archive" -C "$destination" --no-same-owner
printf '%s\n' "$actual_sha256" > "$destination/SOURCE.sha256"

