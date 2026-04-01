#!/usr/bin/env bash
set -euo pipefail

if [[ -z "$(git config --global user.email)" ]]; then
  read -rp "Git email: " git_email
  git config --global user.email "$git_email"
fi

if [[ -z "$(git config --global user.name)" ]]; then
  read -rp "Git name: " git_name
  git config --global user.name "$git_name"
fi