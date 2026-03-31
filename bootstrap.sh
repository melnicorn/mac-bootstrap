#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="${HOME}/Library/Logs"
LOG_FILE="${LOG_DIR}/mac-bootstrap.$(date +"%Y%m%d-%H%M%S").log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
info() { printf "• %s\n" "$*"; }
warn() { printf "\033[33m! %s\033[0m\n" "$*"; }
die()  { printf "\033[31m✖ %s\033[0m\n" "$*"; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }

confirm() {
  local prompt="${1:-Are you sure?}"
  read -r -p "$prompt [y/N]: " ans
  [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
}

DRY_RUN=false
HOSTNAME_ARG=""
RUN_ALL=false
REQUESTED_STEPS=()
ALL_STEPS=(hostname rosetta xcode homebrew brew git repos zsh gcloud antigravity mysql)

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf "[dry-run] %q" "$1"
    shift
    for arg in "$@"; do printf " %q" "$arg"; done
    printf "\n"
    return 0
  fi
  "$@"
}

run_sudo() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf "[dry-run] sudo"
    for arg in "$@"; do printf " %q" "$arg"; done
    printf "\n"
    return 0
  fi
  sudo "$@"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --hostname)
        HOSTNAME_ARG="${2:-}"
        shift 2
        ;;
      --step)
        [[ -n "${2:-}" ]] || die "--step requires an argument"
        REQUESTED_STEPS+=("$2")
        shift 2
        ;;
      --all)
        RUN_ALL=true
        shift
        ;;
      --list)
        info "Available steps: ${ALL_STEPS[*]}"
        exit 0
        ;;
      -h|--help)
        cat <<EOF
Usage: ./bootstrap.sh [OPTIONS]

Options:
  --all               Run all bootstrap steps
  --step NAME         Run a specific step (can be used multiple times)
  --list              List all available steps
  --dry-run           Show what would be done without making changes
  --hostname NAME     Set the machine hostname
  -h, --help          Show this help message

Steps:
  ${ALL_STEPS[*]}

Example:
  ./bootstrap.sh --step homebrew --step git
  ./bootstrap.sh --all --hostname my-mac
EOF
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        die "Unknown option: $1"
        ;;
      *)
        # positional hostname for backward compatibility
        HOSTNAME_ARG="$1"
        shift
        ;;
    esac
  done
}

should_run() {
  local step="$1"
  if [[ "$RUN_ALL" == "true" ]]; then
    return 0
  fi
  for s in "${REQUESTED_STEPS[@]}"; do
    if [[ "$s" == "$step" ]]; then
      return 0
    fi
  done
  return 1
}

set_hostname() {
  bold "Hostname"
  local current
  current="$(scutil --get ComputerName 2>/dev/null || true)"
  info "Current ComputerName: ${current:-<unset>}"

  local new_name="${1:-}"
  if [[ -z "$new_name" ]]; then
    read -r -p "Enter new hostname (ComputerName) (leave blank to skip): " new_name
  fi

  if [[ -z "$new_name" ]]; then
    warn "Skipping hostname."
    return 0
  fi

  info "Setting hostname to: $new_name"
  run_sudo scutil --set ComputerName "$new_name"
  run_sudo scutil --set HostName "$new_name"
  run_sudo scutil --set LocalHostName "$new_name"
  run_sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$new_name"

  # Best-effort cache flush so services pick it up sooner
  run_sudo dscacheutil -flushcache || true
  run_sudo killall -HUP mDNSResponder || true

  info "Hostname set."
}

install_rosetta() {
  bold "Rosetta 2"
  if [[ "$(uname -m)" != "arm64" ]]; then
    info "Not on Apple Silicon. Skipping Rosetta installation."
    return 0
  fi

  if /usr/bin/pgrep oahd >/dev/null 2>&1; then
    info "Rosetta is already running/installed."
    return 0
  fi

  # More robust check: check for a known rosetta file or use pkgutil?
  # The pgrep check is good for running, but maybe not if it's installed but not running?
  # Apple recommends checking for the service or just running the installer safely.
  # softwareupdate --install-rosetta will return success if already installed?
  # Actually, /usr/bin/pgrep oahd might not verify installation if not active.
  # A common check is:
  if [[ -f "/Library/Apple/System/Library/LaunchDaemons/com.apple.oahd.plist" ]]; then
      info "Rosetta appears to be installed."
      return 0
  fi

  info "Installing Rosetta 2..."
  if [[ "$DRY_RUN" == "true" ]]; then
    run_sudo softwareupdate --install-rosetta --agree-to-license
    return 0
  fi

  run_sudo softwareupdate --install-rosetta --agree-to-license
  info "Rosetta 2 installed."
}

install_xcode_clt() {
  bold "Xcode Command Line Tools"
  if xcode-select -p >/dev/null 2>&1; then
    info "Xcode CLT already installed: $(xcode-select -p)"
    return 0
  fi

  warn "Xcode CLT not found. Triggering Apple installer UI..."
  run xcode-select --install || true

  if [[ "$DRY_RUN" == "true" ]]; then
    warn "Dry-run: not waiting for Xcode CLT install."
    return 0
  fi

  info "Waiting for Xcode CLT to finish installing..."
  until xcode-select -p >/dev/null 2>&1; do
    sleep 10
  done
  info "Xcode CLT installed: $(xcode-select -p)"
}

install_homebrew() {
  bold "Homebrew"
  if command -v brew >/dev/null 2>&1; then
    info "Homebrew already installed: $(brew --version | head -n 1)"
    return 0
  fi

  info "Installing Homebrew..."
  if [[ "$DRY_RUN" == "true" ]]; then
    run /bin/bash -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    return 0
  fi

  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  need_cmd brew
  info "Homebrew installed: $(brew --version | head -n 1)"
}

brew_bundle() {
  bold "Brew bundle"
  need_cmd brew

  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local brewfile="$repo_root/Brewfile"
  [[ -f "$brewfile" ]] || die "Missing Brewfile at $brewfile"

  run brew update
  run brew bundle --file="$brewfile"
  info "Brew bundle complete."
}

setup_git() {
  bold "Git configuration"
  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  run bash "$repo_root/scripts/setup-git.sh"
}

setup_repos_volume() {
  bold "Case-sensitive Repos volume"
  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  run bash "$repo_root/scripts/setup-repos-volume.sh"
}

setup_zsh() {
  bold "Zsh configuration"
  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  run bash "$repo_root/scripts/setup-zsh.sh"
}

setup_gcloud() {
  bold "gcloud"
  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ "$DRY_RUN" == "true" ]]; then
    run bash "$repo_root/scripts/setup-gcloud.sh"
    return 0
  fi
  bash "$repo_root/scripts/setup-gcloud.sh"
}

install_antigravity() {
  bold "Antigravity"
  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  run bash "$repo_root/scripts/install-antigravity.sh"
}

setup_mysql() {
  bold "MySQL"
  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  run bash "$repo_root/scripts/setup-mysql.sh"
}

main() {
  parse_args "$@"
  is_macos || die "This bootstrap is for macOS only."

  bold "mac-bootstrap starting"
  info "Log file: $LOG_FILE"
  info "Dry-run: $DRY_RUN"

  if [[ "$RUN_ALL" == "false" && ${#REQUESTED_STEPS[@]} -eq 0 ]]; then
    die "No steps specified. Use --step NAME or --all. Use --list to see steps."
  fi

  if [[ "$DRY_RUN" == "false" ]]; then
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
  else
    warn "Dry-run: skipping sudo keep-alive."
  fi

  if should_run "hostname"; then
    set_hostname "$HOSTNAME_ARG"
  fi

  if should_run "rosetta"; then
    install_rosetta
  fi

  if should_run "xcode" || should_run "xcode_clt"; then
    install_xcode_clt
  fi

  if should_run "homebrew"; then
    install_homebrew
  fi

  # If dry-run and brew isn't installed, bundle won't run. That's expected.
  if should_run "brew" || should_run "brew_bundle"; then
    if command -v brew >/dev/null 2>&1; then
      brew_bundle
    else
      warn "brew not on PATH yet (likely dry-run). Skipping brew bundle."
    fi
  fi

  if should_run "git"; then
    setup_git
  fi

  if should_run "repos" || should_run "repos_volume"; then
    setup_repos_volume
  fi

  if should_run "zsh"; then
    setup_zsh
  fi

  if should_run "gcloud"; then
    setup_gcloud
  fi

  if should_run "antigravity"; then
    install_antigravity
  fi

  if should_run "mysql"; then
    setup_mysql
  fi

  bold "Done"
  info "Recommended: quit/reopen terminal (or log out/in) to ensure shell + PATH changes apply."
}

main "$@"