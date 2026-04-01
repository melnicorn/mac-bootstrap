#!/usr/bin/env bash
set -euo pipefail

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
info() { printf "• %s\n" "$*"; }
warn() { printf "\033[33m! %s\033[0m\n" "$*"; }

bold "OpenCode Setup"

if ! command -v opencode >/dev/null 2>&1; then
    warn "OpenCode is not installed. Run 'brew bundle' first."
    exit 0
fi

info "OpenCode version: $(opencode --version 2>/dev/null || echo "installed")"

info "Next steps:"
info "1. Run 'opencode /connect' to link your AI provider."
info "2. Run 'opencode' in your project directory to get started."
