#!/usr/bin/env bash
set -euo pipefail

IMAGE_PATH="$HOME/Development/.disk-images/Repos.sparsebundle"
MOUNTPOINT="$HOME/Development/Repos"

mkdir -p "$HOME/Development/.disk-images"
mkdir -p "$MOUNTPOINT"

if mount | grep -q "on ${MOUNTPOINT//\//\\/} "; then
  exit 0
fi

if [[ -d "$IMAGE_PATH" ]]; then
  /usr/bin/hdiutil attach -nobrowse -mountpoint "$MOUNTPOINT" "$IMAGE_PATH" >/dev/null
fi