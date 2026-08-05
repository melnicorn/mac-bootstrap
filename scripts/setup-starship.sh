#!/usr/bin/env bash
set -euo pipefail

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
info() { printf "• %s\n" "$*"; }
warn() { printf "\033[33m! %s\033[0m\n" "$*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

STARSHIP_SRC="$REPO_ROOT/starship/starship.toml"
STARSHIP_DST="$HOME/.config/starship.toml"

# PostScript name of the font shipped by the font-meslo-lg-nerd-font cask
FONT_POSTSCRIPT="MesloLGSNerdFontMono-Regular"
FONT_SIZE=13
ITERM_PROFILE_NAME="Bootstrap"
ITERM_PROFILE_GUID="8B1FE1B4-3C6A-4E7B-9E0E-5C2A7D4F1A90"
ITERM_DYNAMIC_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"

bold "Starship Setup"

if ! command -v starship >/dev/null 2>&1; then
  warn "starship is not installed. Run './bootstrap.sh --only brew-bundle' first."
  exit 0
fi

info "starship version: $(starship --version | head -n 1)"

# --- Config ------------------------------------------------------------------

mkdir -p "$(dirname "$STARSHIP_DST")"

if [[ -e "$STARSHIP_DST" && ! -L "$STARSHIP_DST" ]]; then
  backup="$STARSHIP_DST.backup.$(date +%Y%m%d-%H%M%S)"
  info "Backing up existing starship.toml → $backup"
  mv "$STARSHIP_DST" "$backup"
fi

ln -sf "$STARSHIP_SRC" "$STARSHIP_DST"
info "Linked $STARSHIP_DST → $STARSHIP_SRC"

# --- Font --------------------------------------------------------------------

font_installed() {
  local dir
  for dir in "$HOME/Library/Fonts" "/Library/Fonts"; do
    [[ -e "$dir/${FONT_POSTSCRIPT}.ttf" ]] && return 0
  done
  return 1
}

if font_installed; then
  info "MesloLGS Nerd Font Mono is installed."
else
  warn "MesloLGS Nerd Font Mono not found."
  warn "Install it with: brew install --cask font-meslo-lg-nerd-font"
fi

# --- iTerm2 profile ----------------------------------------------------------

if [[ -d "/Applications/iTerm.app" ]]; then
  mkdir -p "$ITERM_DYNAMIC_DIR"
  cat > "$ITERM_DYNAMIC_DIR/bootstrap.json" <<EOF
{
  "Profiles": [
    {
      "Name": "$ITERM_PROFILE_NAME",
      "Guid": "$ITERM_PROFILE_GUID",
      "Normal Font": "$FONT_POSTSCRIPT $FONT_SIZE",
      "Non Ascii Font": "$FONT_POSTSCRIPT $FONT_SIZE",
      "Use Non-ASCII Font": true,
      "Ambiguous Double Width": false,
      "Unlimited Scrollback": true,
      "Horizontal Spacing": 1,
      "Vertical Spacing": 1
    }
  ]
}
EOF
  info "Installed iTerm2 dynamic profile '$ITERM_PROFILE_NAME' (MesloLGS Nerd Font Mono)."

  current_default="$(defaults read com.googlecode.iterm2 "Default Bookmark Guid" 2>/dev/null || echo "")"
  if [[ "$current_default" != "$ITERM_PROFILE_GUID" ]]; then
    info "To make it the default: iTerm2 → Settings → Profiles → '$ITERM_PROFILE_NAME' → Other Actions → Set as Default."
    info "Or, with iTerm2 closed:"
    info "  defaults write com.googlecode.iterm2 \"Default Bookmark Guid\" -string \"$ITERM_PROFILE_GUID\""
  else
    info "'$ITERM_PROFILE_NAME' is already the default iTerm2 profile."
  fi
else
  info "iTerm2 not installed — set your terminal font to 'MesloLGS Nerd Font Mono' manually."
fi

info "Starship is wired into zsh via ~/.zsh/zshrc_60_starship. Open a new shell to see it."
