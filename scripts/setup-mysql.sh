#!/usr/bin/env bash
set -euo pipefail

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
info() { printf "• %s\n" "$*"; }
warn() { printf "\033[33m! %s\033[0m\n" "$*"; }

bold "MySQL Setup"

if ! command -v mysql >/dev/null 2>&1; then
    warn "MySQL is not installed. Run 'brew bundle' first."
    exit 0
fi

info "MySQL version: $(mysql --version)"

# Check if service is running
if brew services list --json | grep -q '"name":"mysql","status":"started"'; then
  info "MySQL service is already running."
else
  info "Starting MySQL service..."
  brew services start mysql
  info "MySQL service started."
fi

info "Note: You may want to run 'mysql_secure_installation' manually if this is a fresh install."
