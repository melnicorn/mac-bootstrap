#!/usr/bin/env bash
set -euo pipefail

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
info() { printf "• %s\n" "$*"; }
warn() { printf "\033[33m! %s\033[0m\n" "$*"; }

confirm() {
  local prompt="${1:-Are you sure?}"
  read -r -p "$prompt [y/N]: " ans

  # lowercase using posix-safe tr (works even on macOS Bash 3.2)
  local lower_ans
  lower_ans="$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')"

  if [[ "$lower_ans" == "y" || "$lower_ans" == "yes" ]]; then
    return 0
  fi

  return 1
}

bold "Google Cloud CLI (gcloud)"

if ! command -v gcloud >/dev/null 2>&1; then
  warn "gcloud not found on PATH yet. It may require a new shell session."
  warn "Try: exec zsh (or reopen terminal) after bootstrap completes."
  exit 0
fi

info "gcloud version: $(gcloud version 2>/dev/null | head -n 1 || true)"

if confirm "Run 'gcloud init' now (interactive, opens browser)?"; then
  # The 'gcloud init' command initializes authentication and configuration
  # interactive setup. See official docs: https://cloud.google.com/sdk/docs/initializing  [oai_citation:1‡Google Cloud Documentation](https://docs.cloud.google.com/sdk/docs/initializing?utm_source=chatgpt.com)
  gcloud init
else
  info "Skipping 'gcloud init'. You can run it anytime: gcloud init"
fi