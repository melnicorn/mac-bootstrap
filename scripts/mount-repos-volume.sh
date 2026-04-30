#!/usr/bin/env bash
set -euo pipefail

IMAGE_PATH="$HOME/.disk-images/Development.sparsebundle"
MOUNTPOINT="$HOME/Development"

mkdir -p "$HOME/.disk-images"
mkdir -p "$MOUNTPOINT"

if mount | grep -q "on ${MOUNTPOINT//\//\\/} "; then
  exit 0
fi

if [[ -d "$IMAGE_PATH" ]]; then
  /usr/bin/hdiutil attach -nobrowse -mountpoint "$MOUNTPOINT" "$IMAGE_PATH" >/dev/null
fi