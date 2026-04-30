#!/usr/bin/env bash
set -euo pipefail

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1"; exit 1; }; }

need_cmd uv

PYTHON_VERSION="3.13"

if uv python list --only-installed 2>/dev/null | grep -q "cpython-${PYTHON_VERSION}"; then
  echo "• Python ${PYTHON_VERSION} already installed via uv."
else
  echo "• Installing Python ${PYTHON_VERSION} via uv..."
  uv python install "$PYTHON_VERSION"
fi
