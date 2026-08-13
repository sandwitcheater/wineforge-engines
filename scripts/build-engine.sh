#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 022

if (( $# != 2 )); then
  printf 'usage: %s VERSION TARGET\n' "$0" >&2
  exit 64
fi

version=$1
target=$2
repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$repo_dir/engines/crossover-$version.json"
work_dir=${WINEFORGE_WORK_DIR:-"$repo_dir/work/$version-$target"}
dist_dir=${WINEFORGE_DIST_DIR:-"$repo_dir/dist"}

case "$target" in
  linux-x86_64) expected_host='x86_64-linux-gnu' ;;
  macos-x86_64) expected_host='x86_64-apple-darwin' ;;
  *) printf 'unsupported target: %s\n' "$target" >&2; exit 64 ;;
esac

[[ -f "$manifest" ]] || { printf 'unsupported version: %s\n' "$version" >&2; exit 64; }

configure_args=(
  --prefix=/
  --enable-win64
  "--host=$expected_host"
)
if [[ "$target" == macos-x86_64 ]]; then
  configure_args+=(--without-alsa --without-cups --without-dbus --without-oss --without-pulse --without-sane --without-wayland --without-x)
fi

if [[ ${DRY_RUN:-0} == 1 ]]; then
  printf 'version=%s\ntarget=%s\nconfigure=' "$version" "$target"
  printf ' %q' "${configure_args[@]}"
  printf '\n'
  exit 0
fi

for command_name in file jq make patch python3 shasum; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$command_name" >&2
    exit 69
  }
done

if [[ -e "$work_dir" ]]; then
  printf 'work directory already exists: %s\n' "$work_dir" >&2
  exit 73
fi
mkdir -p -- "$work_dir" "$dist_dir"
"$repo_dir/scripts/fetch-source.sh" "$version" "$work_dir/source"

source_subdirectory=$(jq -er '.build.source_subdirectory' "$manifest")
source_dir="$work_dir/source/$source_subdirectory"
build_dir="$work_dir/build"
stage_dir="$work_dir/stage"
mkdir -p -- "$build_dir" "$stage_dir"
"$repo_dir/scripts/prepare-source.sh" "$source_dir"

patch_evidence='[]'
while IFS= read -r patch_spec; do
  patch_path=$(jq -er '.path' <<<"$patch_spec")
  expected_patch_sha256=$(jq -er '.sha256' <<<"$patch_spec")
  case "$patch_path" in
    "patches/$version/"*.patch) ;;
    *) printf 'unsafe patch path: %s\n' "$patch_path" >&2; exit 65 ;;
  esac
  patch_file="$repo_dir/$patch_path"
  if [[ ! -f "$patch_file" || -L "$patch_file" ]]; then
    printf 'unsafe or missing patch: %s\n' "$patch_path" >&2
    exit 65
  fi
  actual_patch_sha256=$(shasum -a 256 "$patch_file" | awk '{print $1}')
  if [[ "$actual_patch_sha256" != "$expected_patch_sha256" ]]; then
    printf 'patch digest mismatch for %s\n' "$patch_path" >&2
    exit 65
  fi
  patch --batch --forward --directory="$source_dir" -p1 --input="$patch_file"
  patch_evidence=$(jq -c \
    --arg path "$patch_path" \
    --arg sha256 "$actual_patch_sha256" \
    '. + [{path: $path, sha256: $sha256}]' <<<"$patch_evidence")
done < <(jq -c --arg target "$target" \
  '.build.patches[] | select(.targets | index($target))' "$manifest")

if [[ "$target" == macos-x86_64 ]]; then
  export CC='clang -arch x86_64'
  export CXX='clang++ -arch x86_64'
  if command -v brew >/dev/null 2>&1; then
    brew_prefix=$(brew --prefix)
    export PATH="$(brew --prefix bison)/bin:$PATH"
    export PKG_CONFIG_PATH="$brew_prefix/lib/pkgconfig:$brew_prefix/share/pkgconfig:${PKG_CONFIG_PATH:-}"
    export CPPFLAGS="-I$brew_prefix/include ${CPPFLAGS:-}"
    export LDFLAGS="-L$brew_prefix/lib ${LDFLAGS:-}"
  fi
fi

(
  cd "$build_dir"
  "$source_dir/configure" "${configure_args[@]}"
  make -j "${WINEFORGE_JOBS:-2}" install DESTDIR="$stage_dir"
)

wine_binary=$(find "$stage_dir" -type f \( -name wine -o -name wine64 \) -perm -111 -print | LC_ALL=C sort | head -1)
[[ -n "$wine_binary" ]] || { printf 'installed Wine executable not found\n' >&2; exit 70; }
binary_description=$(file "$wine_binary")
case "$target:$binary_description" in
  linux-x86_64:*ELF*x86-64*|macos-x86_64:*Mach-O*64-bit*x86_64*) ;;
  *) printf 'unexpected runtime architecture: %s\n' "$binary_description" >&2; exit 70 ;;
esac

mkdir -p -- "$stage_dir/share/wineforge/licenses"
find "$source_dir" -maxdepth 2 -type f \
  \( -iname 'copying*' -o -iname 'license*' -o -iname 'authors*' \) \
  -exec cp -p {} "$stage_dir/share/wineforge/licenses/" \;

source_sha256=$(jq -er '.source.sha256' "$manifest")
source_date_epoch=$(jq -er '.source.source_date_epoch' "$manifest")
compiler_command=${CC:-cc}
compiler_command=${compiler_command%% *}
jq -n \
  --arg version "$version" \
  --arg target "$target" \
  --arg source_sha256 "$source_sha256" \
  --arg source_url "$(jq -er '.source.url' "$manifest")" \
  --arg runner_image "${ImageOS:-unknown}-${ImageVersion:-unknown}" \
  --arg binary_description "$binary_description" \
  --arg configure "$(printf '%q ' "${configure_args[@]}")" \
  --argjson patches "$patch_evidence" \
  --arg cc "$($compiler_command --version 2>/dev/null | head -1 || true)" \
  --arg make "$(make --version | head -1)" \
  '{schema_version: 1, version: $version, target: $target,
    source: {url: $source_url, sha256: $source_sha256},
    builder: {runner_image: $runner_image, compiler: $cc, make: $make},
    configure: $configure, source_patches: $patches,
    executable: $binary_description}' \
  > "$stage_dir/share/wineforge/build-info.json"

artifact="$dist_dir/wineforge-engine-$version-$target.tar.gz"
python3 "$repo_dir/scripts/package.py" "$stage_dir" "$artifact" --mtime "$source_date_epoch"
artifact_name=$(basename "$artifact")
artifact_sha256=$(shasum -a 256 "$artifact" | awk '{print $1}')
wine_relative=${wine_binary#"$stage_dir"/}
case "$target" in
  linux-x86_64)
    runtime_platform='linux-x86-64'
    translation='native'
    ;;
  macos-x86_64)
    runtime_platform='macos-x86-64'
    translation='rosetta2'
    ;;
esac
jq -n \
  --arg id "crossover-$version-$target" \
  --arg platform "$runtime_platform" \
  --arg translation "$translation" \
  --arg sha256 "$artifact_sha256" \
  --arg wine_binary "$wine_relative" \
  '{schema_version: 1, id: $id, platform: $platform,
    host_architecture: "x86_64", translation: $translation,
    artifact: {source: {kind: "user-supplied"}, sha256: $sha256},
    wine_binary: $wine_binary,
    environment: {WINEESYNC: "1", WINEMSYNC: "1"},
    license: {
      name: "CrossOver component licences",
      url: "https://www.codeweavers.com/crossover/source",
      acceptance_required: false
    }}' > "$dist_dir/$artifact_name.runtime.json"
(
  cd "$dist_dir"
  printf '%s  %s\n' "$artifact_sha256" "$artifact_name" > "$artifact_name.sha256"
)
printf 'created %s\n' "$artifact"
