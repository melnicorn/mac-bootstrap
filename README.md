# mac-bootstrap

Opinionated, idempotent bootstrap for a fresh macOS development machine.
Run the whole thing or cherry-pick individual steps — every step is safe to re-run.

---

## Quick Start

```bash
git clone https://github.com/melnicorn/mac-bootstrap.git
cd mac-bootstrap
chmod +x bootstrap.sh scripts/*.sh
./bootstrap.sh
```

> [!NOTE]
> The script requires **macOS** and will prompt for `sudo` once (kept alive automatically).
> A timestamped log is written to `~/Library/Logs/mac-bootstrap.*.log`.

---

## CLI Options

```
Usage: ./bootstrap.sh [OPTIONS] [HOSTNAME]

Options:
  --dry-run              Print commands instead of executing them
  --hostname NAME        Set the machine hostname
  --only step1,step2,..  Run only the specified steps (comma-separated)
  --list                 List available step names and exit
  -h, --help             Show this help and exit
```

### Examples

```bash
./bootstrap.sh                            # run everything
./bootstrap.sh --only zsh                 # single step
./bootstrap.sh --only git,zsh,gcloud      # several steps
./bootstrap.sh --dry-run --only homebrew  # preview without side-effects
./bootstrap.sh --hostname skywalker       # set hostname inline
```

---

## Bootstrap Steps

All steps run in the order shown below. Use `--only` to select a subset.

| Step | What it does |
|---|---|
| **hostname** | Set `ComputerName`, `HostName`, `LocalHostName`, and NetBIOS name via `scutil` / `defaults`. Prompts interactively if `--hostname` is omitted. |
| **rosetta** | Install Rosetta 2 on Apple Silicon Macs (skipped on Intel). |
| **xcode** | Install Xcode Command Line Tools (triggers the Apple installer UI if missing). |
| **homebrew** | Install [Homebrew](https://brew.sh) non-interactively, then add it to `PATH`. |
| **brew-bundle** | Run `brew bundle` against the included [`Brewfile`](Brewfile) (see [Packages](#packages-brewfile) below). |
| **git** | Set global `user.name` and `user.email` via [`scripts/setup-git.sh`](scripts/setup-git.sh). |
| **repos-volume** | Create a **case-sensitive APFS sparsebundle** at `~/Development/.disk-images/Repos.sparsebundle`, mounted at `~/Development/Repos`. Installs a launchd agent to auto-mount on login (see [Repos Volume](#repos-volume-1) below). |
| **zsh** | Symlink the modular zsh config into `~/.zsh/` and point `~/.zshrc` at the loader (see [Zsh Configuration](#zsh-configuration) below). |
| **gcloud** | Run interactive `gcloud init` (opens a browser for OAuth). |
| **antigravity** | Open the [Antigravity](https://antigravity.google/download) download page for manual install. |
| **mysql** | Start the MySQL service via `brew services` and remind you about `mysql_secure_installation`. |

---

## Packages (Brewfile)

| Category | Package | Type |
|---|---|---|
| Terminal | [iTerm2](https://iterm2.com) | cask |
| Essentials | `git`, `jq`, `ripgrep`, `fd`, `fzf` | brew |
| Python | [uv](https://github.com/astral-sh/uv) | brew |
| Node | [Volta](https://volta.sh) | brew |
| JRE | [Eclipse Temurin](https://adoptium.net) | cask |
| Cloud | [Google Cloud CLI](https://cloud.google.com/sdk) | cask |
| Data Stores | `mysql` | brew |

---

## Zsh Configuration

The zsh setup uses a **numbered-fragment** pattern. The main loader (`zsh/zshrc`, symlinked to `~/.zshrc`) sources every `zshrc_*` file in `~/.zsh/` in lexicographic order:

| Fragment | Purpose |
|---|---|
| `zshrc_00_env` | Reserved for environment variables (currently empty). |
| `zshrc_10_hostname` | Keeps `$HOST` / `$HOSTNAME` in sync with System Settings changes via a `precmd` hook — no shell restart needed. |
| `zshrc_20_gcloud` | Adds Google Cloud SDK component binaries to `$PATH`. |
| `zshrc_30_path` | Sets `$VOLTA_HOME` and adds Volta's `bin/` to `$PATH`. |
| `zshrc_40_alias` | Shell aliases (see [Aliases](#aliases) below). |
| `zshrc_50_ghutils` | Git/GitHub helper functions (see [Git Utilities](#git-utilities) below). |

The loader also sources `~/.zshrc_local` if it exists, which is **not** tracked in git — use it for per-machine overrides.

### Aliases

| Alias | Expands to |
|---|---|
| `cls` | `clear && printf "\e[3J"` — clears terminal **and** scrollback. |
| `p` | `pnpm` |
| `nvm` | Prints a reminder to use Volta instead. |

### Git Utilities

| Command | Description |
|---|---|
| `merge-main` | Switches to `main`, pulls, switches back, and merges `main` into the current branch. |
| `git-clean-local` | Checks out `main`, deletes all other local branches (safe `-d`), and pulls. |
| `gopen` | Opens the current repo's GitHub page in the browser (supports SSH and HTTPS remotes). |
| `gact` | Same as `gopen` but opens the **Actions** tab (`/actions`). |
| `create-branch <name>` | Creates a new local branch, pushes it to `origin`, and sets upstream tracking. |

---

## Repos Volume

Some tools (e.g., Git on Linux-origin projects) need a **case-sensitive** filesystem. The `repos-volume` step:

1. Creates a case-sensitive APFS sparsebundle at `~/Development/.disk-images/Repos.sparsebundle` (default max size **50 GB**, override with `REPOS_VOLUME_MAX_SIZE` env var).
2. Mounts it at `~/Development/Repos`.
3. Installs a **launchd agent** (`com.melnicorn.mount-repos`) that re-mounts the volume on login and every 60 seconds if it's not already mounted.

---

## Project Structure

```
mac-bootstrap/
├── bootstrap.sh                  # Main entry point
├── Brewfile                      # Homebrew packages
├── scripts/
│   ├── setup-git.sh              # Global git config
│   ├── setup-repos-volume.sh     # Create & mount case-sensitive volume
│   ├── mount-repos-volume.sh     # Lightweight mount helper (used by launchd)
│   ├── setup-zsh.sh              # Symlink zsh fragments
│   ├── setup-gcloud.sh           # Interactive gcloud init
│   ├── install-antigravity.sh    # Opens download page
│   └── setup-mysql.sh            # Start MySQL via Homebrew services
├── zsh/
│   ├── zshrc                     # Main loader (→ ~/.zshrc)
│   ├── zshrc_00_env              # Environment variables
│   ├── zshrc_10_hostname         # Hostname sync hook
│   ├── zshrc_20_gcloud           # gcloud PATH
│   ├── zshrc_30_path             # Volta PATH
│   ├── zshrc_40_alias            # Shell aliases
│   └── zshrc_50_ghutils          # Git/GitHub helpers
└── launchd/
    └── com.melnicorn.mount-repos.plist  # Auto-mount agent template
```

---

## Customisation

- **Add packages** — edit [`Brewfile`](Brewfile) and re-run `./bootstrap.sh --only brew-bundle`.
- **Add shell config** — create a new `zsh/zshrc_NN_name` file; it will be sourced automatically.
- **Machine-local overrides** — put them in `~/.zshrc_local` (git-ignored).
- **Skip steps** — use `--only` to run exactly the steps you need.

## License

MIT