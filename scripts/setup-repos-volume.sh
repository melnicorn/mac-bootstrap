#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IMAGE_DIR="$HOME/Development/.disk-images"
IMAGE_PATH="$IMAGE_DIR/Repos.sparsebundle"
MOUNTPOINT="$HOME/Development/Repos"
VOLUME_NAME="Repos"
MAX_SIZE="${REPOS_VOLUME_MAX_SIZE:-50g}" # change by env var if desired

mkdir -p "$IMAGE_DIR"
mkdir -p "$MOUNTPOINT"

echo "Repos volume:"
echo "  Image: $IMAGE_PATH"
echo "  Mount: $MOUNTPOINT"
echo "  Max:   $MAX_SIZE"

# Create sparsebundle if missing
if [[ ! -d "$IMAGE_PATH" ]]; then
  echo "Creating case-sensitive APFS sparsebundle..."
  hdiutil create \
    -size "$MAX_SIZE" \
    -type SPARSEBUNDLE \
    -fs "Case-sensitive APFS" \
    -volname "$VOLUME_NAME" \
    "$IMAGE_PATH"
else
  echo "Sparsebundle exists."
fi

# Mount if not already mounted
if mount | grep -q "on ${MOUNTPOINT//\//\\/} "; then
  echo "Already mounted."
else
  echo "Mounting..."
  hdiutil attach -nobrowse -mountpoint "$MOUNTPOINT" "$IMAGE_PATH" >/dev/null
fi

# Install mount helper script (symlinked for consistency)
chmod +x "$REPO_ROOT/scripts/mount-repos-volume.sh"

# Install LaunchAgent
PLIST_SRC="$REPO_ROOT/launchd/com.melnicorn.mount-repos.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.melnicorn.mount-repos.plist"

mkdir -p "$HOME/Library/LaunchAgents"

# Escape REPO_ROOT for use in a sed replacement safely
REPO_ESCAPED="$(printf '%s' "$REPO_ROOT" | sed -e 's/[\\/&]/\\&/g')"
export REPO_ROOT="$REPO_ROOT"

sed "s|__REPO_ROOT__|$REPO_ROOT|g" "$PLIST_SRC" > "$PLIST_DST"

echo "Loading LaunchAgent..."
launchctl unload "$PLIST_DST" >/dev/null 2>&1 || true
launchctl load "$PLIST_DST"

echo "Repos volume setup complete."