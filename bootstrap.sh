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

# Ordered list of all available steps
ALL_STEPS=(
  hostname
  rosetta
  xcode
  homebrew
  brew-bundle
  git
  repos-volume
  zsh
  gcloud
  antigravity
  mysql
)

# Steps selected via --only (empty = run all)
SELECTED_STEPS=()

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

list_steps() {
  bold "Available steps:"
  for s in "${ALL_STEPS[@]}"; do
    printf "  %s\n" "$s"
  done
}

step_enabled() {
  local step="$1"
  # If no --only was given, every step is enabled
  if [[ ${#SELECTED_STEPS[@]} -eq 0 ]]; then
    return 0
  fi
  for s in "${SELECTED_STEPS[@]}"; do
    [[ "$s" == "$step" ]] && return 0
  done
  return 1
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
      --only)
        [[ -z "${2:-}" ]] && die "--only requires a comma-separated list of steps"
        IFS=',' read -ra SELECTED_STEPS <<< "$2"
        # Validate every requested step
        for sel in "${SELECTED_STEPS[@]}"; do
          local found=false
          for valid in "${ALL_STEPS[@]}"; do
            [[ "$sel" == "$valid" ]] && found=true && break
          done
          [[ "$found" == "true" ]] || die "Unknown step: $sel (run with --list to see available steps)"
        done
        shift 2
        ;;
      --list)
        list_steps
        exit 0
        ;;
      -h|--help)
        cat <<EOF
Usage: ./bootstrap.sh [OPTIONS] [HOSTNAME]

Options:
  --dry-run              Print commands instead of executing them
  --hostname NAME        Set the machine hostname
  --only step1,step2,..  Run only the specified steps (comma-separated)
  --list                 List available step names and exit
  -h, --help             Show this help and exit

Available steps:
  $(printf '%s, ' "${ALL_STEPS[@]}" | sed 's/, $//')

Examples:
  ./bootstrap.sh                          # run everything
  ./bootstrap.sh --only zsh               # run only the zsh step
  ./bootstrap.sh --only git,zsh,gcloud    # run several steps
  ./bootstrap.sh --dry-run --only homebrew # dry-run a single step
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
  if [[ ${#SELECTED_STEPS[@]} -gt 0 ]]; then
    info "Running steps: ${SELECTED_STEPS[*]}"
  fi

  if [[ "$DRY_RUN" == "false" ]]; then
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
  else
    warn "Dry-run: skipping sudo keep-alive."
  fi

  step_enabled hostname      && set_hostname "$HOSTNAME_ARG"
  step_enabled rosetta       && install_rosetta
  step_enabled xcode         && install_xcode_clt
  step_enabled homebrew      && install_homebrew

  if step_enabled brew-bundle; then
    # If dry-run and brew isn't installed, bundle won't run. That's expected.
    if command -v brew >/dev/null 2>&1; then
      brew_bundle
    else
      warn "brew not on PATH yet (likely dry-run). Skipping brew bundle."
    fi
  fi

  step_enabled git           && setup_git
  step_enabled repos-volume  && setup_repos_volume
  step_enabled zsh           && setup_zsh
  step_enabled gcloud        && setup_gcloud
  step_enabled antigravity   && install_antigravity
  step_enabled mysql         && setup_mysql

  bold "Done"
  info "Recommended: quit/reopen terminal (or log out/in) to ensure shell + PATH changes apply."
}

main "$@"