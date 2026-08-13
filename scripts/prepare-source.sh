#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 022

if (( $# != 1 )); then
  printf 'usage: %s WINE_SOURCE_DIRECTORY\n' "$0" >&2
  exit 64
fi

source_dir=$1
source_parent=${source_dir%/*}
header="$source_parent/distversion.h"

if [[ ! -d "$source_dir" || -L "$source_dir" ]]; then
  printf 'unsafe or missing Wine source directory: %s\n' "$source_dir" >&2
  exit 65
fi
if [[ ! -d "$source_parent" || -L "$source_parent" ]]; then
  printf 'unsafe Wine source parent directory: %s\n' "$source_parent" >&2
  exit 65
fi

# CrossOver's winedbg Makefile searches the parent of the Wine source tree for
# this generated input. The source archives omit it; only two values are used.
if [[ ! -e "$header" && ! -L "$header" ]]; then
  temporary=$(mktemp "$source_parent/.distversion.h.XXXXXX")
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
