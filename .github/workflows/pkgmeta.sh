#!/bin/bash

set -euo pipefail

# Usage: pkgmeta.sh [gen|check]

case "$1" in
  gen)
    output_file="metadata"
    > "$output_file"
    for dir in */; do
      pkg="${dir%/}"
      combined_hashes=""
      while IFS= read -r -d '' file; do
        hash=$(sha256sum "$file" | awk '{print $1}')
        combined_hashes+="$hash"
      done < <(find "$dir" -type f -print0 | sort -z)
      sum=$(printf "%s" "$combined_hashes" | sha256sum | awk '{print $1}')
      echo "$pkg - $sum" >> "$output_file"
    done
    ;;

  check)
    if [[ ! -f metadata || ! -f build-metadata ]]; then
      echo "metadata or build-metadata file not found."
      exit 1
    fi

    diff <(sort metadata) <(sort build-metadata) | grep '^[<>]' | awk '{print $2}' | sort -u || true
    ;;

  *)
    echo "Usage: $0 [gen|check]"
    exit 1
    ;;
esac
