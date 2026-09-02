#!/usr/bin/env bash
# Strips one or more build directories down to only what's needed to keep as an artifact/cache:
#   - the "bin" folder and shared objects in "lib"
#
# Usage:
#   ./clean_build_dir.sh <build_directory> [<build_directory> ...]

set -euo pipefail


if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <build_directory> [<build_directory> ...]" >&2
  exit 1
fi

for dir in "$@"; do
  # Sanity check to make sure this is actually (probably) a PICLas build directory
  if [ ! -d "$dir/bin" ]; then
    echo "\"$dir\" has no \"bin\" folder, refusing to strip it."
    continue
  fi

  echo "Stripping build dir \"$dir\""
  for entry in "$dir"/*; do
    name="$(basename "$entry")"

      # Keep bin and shared objects in lib
    case "$name" in
      bin)
        ;;
      lib)
        rm -f $entry/lib*.a
        ;;
      *)
        rm -rf -- "$entry"
        ;;
    esac
  done
done