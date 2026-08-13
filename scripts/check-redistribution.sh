#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if (( $# != 1 )); then
  printf 'usage: %s VERSION\n' "$0" >&2
  exit 64
fi

repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$repo_dir/engines/crossover-$1.json"
status=$(jq -er '.redistribution.status' "$manifest")
if [[ "$status" != approved ]]; then
  printf 'release refused: redistribution status is %s\n' "$status" >&2
  exit 77
fi
