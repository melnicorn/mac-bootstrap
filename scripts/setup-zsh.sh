#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSH_SRC="$REPO_ROOT/zsh"
ZSH_DST="$HOME/.zsh"
ZSHRC="$HOME/.zshrc"

echo "Setting up zsh config..."

# Ensure zsh is default shell
if [[ "$SHELL" != *"/zsh" ]]; then
  echo "Setting zsh as default shell..."
  chsh -s /bin/zsh
fi

mkdir -p "$ZSH_DST"

# Symlink fragments into ~/.zsh
for file in "$ZSH_SRC"/zshrc_*; do
  name="$(basename "$file")"
  ln -sf "$file" "$ZSH_DST/$name"
done

# Backup existing ~/.zshrc if it's a real file
if [[ -e "$ZSHRC" && ! -L "$ZSHRC" ]]; then
  backup="$ZSHRC.backup.$(date +%Y%m%d-%H%M%S)"
  echo "Backing up existing .zshrc → $backup"
  mv "$ZSHRC" "$backup"
elif [[ ! -e "$ZSHRC" ]]; then
  echo "Creating new .zshrc link..."
fi

# Symlink canonical loader to ~/.zshrc
ln -sf "$ZSH_SRC/zshrc" "$ZSHRC"

echo "zsh setup complete."