#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
failures=0

for command_name in bash jq; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'missing required command: %s\n' "$command_name" >&2
    exit 1
  fi
done

while IFS= read -r script; do
  bash -n "$script"
done < <(find "$repo_dir/scripts" -type f -name '*.sh' -print | LC_ALL=C sort)

preparation_test=$(mktemp -d "${TMPDIR:-/tmp}/wineforge-prepare-test.XXXXXX")
cleanup() { rm -rf -- "$preparation_test"; }
trap cleanup EXIT HUP INT TERM
mkdir -- "$preparation_test/wine"
"$repo_dir/scripts/prepare-source.sh" "$preparation_test/wine"
"$repo_dir/scripts/prepare-source.sh" "$preparation_test/wine"
if ! grep -q '^#define WINDEBUG_WHAT_HAPPENED_MESSAGE' \
  "$preparation_test/distversion.h" || \
  ! grep -q '^#define WINDEBUG_USER_SUGGESTION_MESSAGE' \
  "$preparation_test/distversion.h"; then
  printf 'source preparation did not create the required definitions\n' >&2
  failures=$((failures + 1))
fi

for manifest in "$repo_dir"/engines/crossover-*.json; do
  if ! jq -e '
    .schema_version == 1 and
    (.id | test("^[a-z0-9][a-z0-9.-]+$")) and
    (.source.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and
    (.source.url | test("^https://media\\.codeweavers\\.com/")) and
    (.source.sha256 | test("^[a-f0-9]{64}$")) and
    (.source.source_date_epoch | type == "number") and
    (.build.source_subdirectory == "sources/wine") and
    (.build.targets == ["linux-x86_64", "macos-x86_64"]) and
    (.redistribution.status as $status |
      (["review_required", "approved", "prohibited"] | index($status)) != null)
  ' "$manifest" >/dev/null; then
    printf 'invalid manifest: %s\n' "$manifest" >&2
    failures=$((failures + 1))
  fi
done

if rg -n -i '(private application|customer name|personal path)' "$repo_dir" \
  --glob '!scripts/validate.sh' >/dev/null; then
  printf 'repository-neutrality placeholder found in tracked content\n' >&2
  failures=$((failures + 1))
fi

if (( failures != 0 )); then
  exit 1
fi

printf 'manifests and shell syntax are valid\n'
