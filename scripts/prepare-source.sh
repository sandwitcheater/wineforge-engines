#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 022

if (( $# != 1 )); then
  printf 'usage: %s WINE_SOURCE_DIRECTORY\n' "$0" >&2
  exit 64
fi

source_dir=$1
include_dir="$source_dir/include"
header="$include_dir/distversion.h"

if [[ ! -d "$include_dir" || -L "$include_dir" ]]; then
  printf 'unsafe or missing Wine include directory: %s\n' "$include_dir" >&2
  exit 65
fi

# CrossOver source archives omit this generated input from their Wine tree.
# The two messages are the only definitions consumed by winedbg/resource.h.
if [[ ! -e "$header" && ! -L "$header" ]]; then
  temporary=$(mktemp "$include_dir/.distversion.h.XXXXXX")
  cleanup() { rm -f -- "$temporary"; }
  trap cleanup EXIT HUP INT TERM
  cat > "$temporary" <<'HEADER'
#ifndef __WINEFORGE_DISTVERSION_H
#define __WINEFORGE_DISTVERSION_H
#define WINDEBUG_WHAT_HAPPENED_MESSAGE \
    "A problem in the program or an unimplemented Wine feature caused this application to stop."
#define WINDEBUG_USER_SUGGESTION_MESSAGE \
    "Save the details, then report the issue to the application vendor or the Wine project."
#endif
HEADER
  chmod 0644 "$temporary"
  mv -f -- "$temporary" "$header"
  trap - EXIT HUP INT TERM
elif [[ -L "$header" || ! -f "$header" ]]; then
  printf 'unsafe Wine distversion header: %s\n' "$header" >&2
  exit 65
fi

for required_macro in \
  WINDEBUG_WHAT_HAPPENED_MESSAGE \
  WINDEBUG_USER_SUGGESTION_MESSAGE
do
  if ! grep -q "^#define $required_macro" "$header"; then
    printf 'Wine distversion header lacks %s\n' "$required_macro" >&2
    exit 65
  fi
done
