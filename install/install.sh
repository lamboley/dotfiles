#!/bin/bash
#
# Dotfiles installer for lamboley/dotfiles.
#
# Run via curl:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/lamboley/dotfiles/master/install/install.sh)"
# Or download then run (recommended for interactive prompts):
#   curl -fsSL https://raw.githubusercontent.com/lamboley/dotfiles/master/install/install.sh -o install.sh
#   bash install.sh
#
# Usage: install.sh [ubuntu|termux|rhel] [-y]  (see --help)
#
set -euo pipefail

# ==========================================================
# Globals
# ==========================================================
DOTFILES="$HOME/.dotfiles"
REPO="https://github.com/lamboley/dotfiles.git"

IS_TERMUX=0
IS_RHEL=0
ARCH=""
ARCH_ARM64=""    # x86_64 -> x86_64 ; aarch64 -> arm64   (sshm)
ARCH_AARCH64=""  # x86_64 -> x86_64 ; aarch64 -> aarch64 (zellij, helix)
ARCH_GO=""       # x86_64 -> amd64  ; aarch64 -> arm64   (Go toolchain)
SUDO=""
TARGET=""        # forced branch: ubuntu | termux | rhel (empty = auto-detect)
ASSUME_YES=0     # -y / --yes: skip all prompts (install everything)
SUDO_REVOKE=0    # revoke the sudo timestamp at exit if we activated it
FAILED_STEPS=()  # optional steps that failed (reported at the end)
TMP_FILES=()     # mktemp files to remove on exit (Ctrl-C safe)

# Clean up any leftover temp files on exit, even if the script dies mid-way.
cleanup() {
  rm -rf /tmp/helix-extract /tmp/shellcheck-extract /tmp/FiraCode.zip \
    "${TMP_FILES[@]}" 2>/dev/null || true
  # Drop the sudo timestamp if this run is what activated it (brew-style).
  if [[ "${SUDO_REVOKE}" -eq 1 ]]; then
    sudo -k 2>/dev/null || true
  fi
}
trap cleanup EXIT

# ==========================================================
# Logging in the Kubernetes hack/lib/logging.sh format (no colors):
#   +++ [MMDD HH:MM:SS] status line
#       indented continuation (4 spaces, no prefix)
#   !!! [MMDD HH:MM:SS] error line (stderr)
# ==========================================================
ts() { date +"[%m%d %H:%M:%S]"; }

info()      { printf '+++ %s %s\n' "$(ts)" "$*"; }
# Continuation line under the current step (plain indentation, k8s-style).
detail()    { printf '    %s\n' "$*"; }
fmt_error() { printf '!!! %s %s\n' "$(ts)" "$*" >&2; }

# ==========================================================
# Small utilities
# ==========================================================
check_cmd() { command -v "$1" >/dev/null 2>&1; }

need_cmd() {
  if ! check_cmd "$1"; then
    fmt_error "required command not found: $1"
    exit 1
  fi
}

# Run a command that must succeed, or abort with a clear message.
ensure() {
  if ! "$@"; then
    fmt_error "command failed: $*"
    exit 1
  fi
}

# Run an OPTIONAL step: if it fails, record it and keep going instead of
# aborting. A summary of failures is printed at the end. Use this for
# individual tools where one failure shouldn't sink the whole install.
# $1 = human label ; $2... = command
attempt() {
  local label="$1"; shift
  if ! "$@"; then
    fmt_error "step failed: $label (continuing)"
    FAILED_STEPS+=("$label")
  fi
  return 0
}

# Retry a command with exponential backoff (Homebrew-style).
# $1 = max attempts ; $2... = command
retry() {
  local n="$1" pause=2
  shift
  while true; do
    "$@" && return 0
    n=$((n - 1))
    [[ "$n" -le 0 ]] && return 1
    detail "Retrying in ${pause}s: $*"
    sleep "$pause"
    pause=$((pause * 2))
  done
}

# Print a summary of optional steps that failed, if any.
report_failures() {
  if [[ "${#FAILED_STEPS[@]}" -gt 0 ]]; then
    fmt_error "Some optional steps failed: ${FAILED_STEPS[*]}"
    detail "The rest of the setup completed. You can re-run the script to retry."
  fi
}

has_gui() { [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; }

# Yes/no prompt that survives `curl | bash` by reading from /dev/tty.
# Non-interactive (no tty) or -y flag: returns "yes" so unattended
# installs are complete.
ask() {
  [[ "$ASSUME_YES" -eq 1 ]] && return 0
  [[ ! -t 1 || ! -e /dev/tty ]] && return 0
  local ans
  printf '+++ %s %s [Y/n] ' "$(ts)" "$1"
  read -r ans < /dev/tty || return 0
  [[ "$ans" =~ ^[Nn] ]] && return 1
  return 0
}

# True if at least one of the given commands is missing.
any_missing() {
  local c
  for c in "$@"; do check_cmd "$c" || return 0; done
  return 1
}

# One "brick" = a tool and its config, handled together:
#   - tool already present  -> (re)deploy its config, no question asked
#   - tool absent           -> ask; on yes, install then deploy its config
#   - user declines         -> skip both (config still syncs if the
#     primary tool exists)
# $1 = command to check ; $2 = prompt ; $3 = deploy function ("-" for none)
# $4... = install command
brick() {
  local cmd="$1" prompt="$2" deploy_fn="$3"; shift 3
  if ! check_cmd "$cmd"; then
    ask "$prompt" || return 0
    attempt "$cmd" "$@"
  fi
  if check_cmd "$cmd" && [[ "$deploy_fn" != "-" ]]; then
    "$deploy_fn"
  fi
  return 0
}

# Resolve a repo's latest release tag WITHOUT the GitHub API (no rate limit).
gh_latest_tag() {
  curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/$1/releases/latest" 2>/dev/null | sed -n 's#.*/tag/##p'
}

# Back up a real file (not a symlink) before replacing it with our symlink.
backup_if_real() {
  if [[ -e "$1" && ! -L "$1" ]]; then
    mv "$1" "$1.pre-dotfiles.bak"
    detail "Backed up existing $1 to $1.pre-dotfiles.bak"
  fi
}

# Best-effort SHA256 verification of a downloaded file.
#   $1 = file ; $2 = checksum URL ; $3 = asset filename (to match in lists)
# A mismatch is fatal (return 1). A missing/unreachable checksum file is
# reported but not fatal — not every project publishes one.
verify_sha256() {
  local file="$1" sum_url="$2" fname="$3" expected actual
  check_cmd sha256sum || { detail "sha256sum not found; skipping verification"; return 0; }
  # Accept both formats: a bare hash, or a "hash  filename" checksum list.
  expected="$(curl -fsSL "$sum_url" 2>/dev/null \
    | awk -v f="$fname" 'NF==1 {print $1; exit} index($0, f) {print $1; exit}')"
  if [[ ! "$expected" =~ ^[0-9a-f]{64}$ ]]; then
    detail "No usable checksum at $sum_url (skipping verification)"
    return 0
  fi
  actual="$(sha256sum "$file" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    fmt_error "SHA256 mismatch for $fname"
    detail "expected: $expected"
    detail "actual:   $actual"
    return 1
  fi
  detail "SHA256 verified: $fname"
  return 0
}

# ==========================================================
# GitHub binary installer with a pluggable extraction step.
#   $1 = download URL
#   $2 = name of a function handling extraction; it receives the downloaded
#        file path as $1 and is responsible for installing the binary.
#   $3 = optional checksum URL (verified best-effort, see verify_sha256)
# The helper owns the common parts (download + verify + cleanup); the
# callback owns the layout differences (single binary vs runtime dir, etc.).
# ==========================================================
fetch_and_install() {
  local url="$1" extract_fn="$2" sum_url="${3:-}"
  local tmp; tmp="$(mktemp)"
  TMP_FILES+=("$tmp")
  if ! curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o "$tmp" "$url"; then
    rm -f "$tmp"; return 1
  fi
  if [[ -n "$sum_url" ]]; then
    verify_sha256 "$tmp" "$sum_url" "$(basename "$url")" || { rm -f "$tmp"; return 1; }
  fi
  "$extract_fn" "$tmp" || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"
}

# Extraction callbacks ------------------------------------------------------
# All tools are installed user-local in ~/.local/bin (must be in PATH).
# Simple case: a .tar.gz containing a single binary.
# Uses $EXTRACT_BIN (set by caller) as the binary name inside the tarball.
# Callbacks return non-zero on failure so attempt() can record it.
extract_single_bin() {
  mkdir -p "$HOME/.local/bin"
  tar -C "$HOME/.local/bin" -xzf "$1" "$EXTRACT_BIN"
}

extract_shellcheck() {
  local dir="/tmp/shellcheck-extract"
  rm -rf "$dir"; mkdir -p "$dir"
  tar -C "$dir" -xJf "$1" || return 1
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$dir/shellcheck-${SHELLCHECK_TAG}/shellcheck" \
    "$HOME/.local/bin/shellcheck" || return 1
  rm -rf "$dir"
}

extract_helix() {
  # helix ships hx + a runtime dir that must live where hx looks for it.
  local dir="/tmp/helix-extract"
  rm -rf "$dir"; mkdir -p "$dir"
  tar -C "$dir" -xJf "$1" || return 1
  local hxdir="$dir/helix-${HELIX_TAG}-${ARCH_AARCH64}-linux"
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$hxdir/hx" "$HOME/.local/bin/hx" || return 1
  mkdir -p "$HOME/.config/helix"
  rm -rf "$HOME/.config/helix/runtime"
  cp -r "$hxdir/runtime" "$HOME/.config/helix/runtime"
  rm -rf "$dir"
}

# ==========================================================
# Detection / preflight
# ==========================================================
detect_env() {
  [[ -n "${TERMUX_VERSION:-}" ]] && IS_TERMUX=1
  command -v dnf >/dev/null 2>&1 && IS_RHEL=1

  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  ARCH_ARM64="x86_64"; ARCH_AARCH64="x86_64"; ARCH_GO="amd64" ;;
    aarch64) ARCH_ARM64="arm64";  ARCH_AARCH64="aarch64"; ARCH_GO="arm64" ;;
    *) fmt_error "Unsupported architecture: $ARCH (expected x86_64 or aarch64)"; exit 1 ;;
  esac

  if [[ "$IS_TERMUX" -eq 1 || "$(id -u)" -eq 0 ]]; then
    SUDO=""
  else
    need_cmd sudo
    SUDO="sudo"
    # Remember whether sudo was already active before we run anything.
    sudo -n -v 2>/dev/null || SUDO_REVOKE=1
  fi
}

preflight() {
  need_cmd curl
  need_cmd git
  need_cmd uname
  need_cmd sed
}

# ==========================================================
# Repo
# ==========================================================
clone_or_update_repo() {
  if [[ -d "$DOTFILES" ]]; then
    if ! git -C "$DOTFILES" diff --quiet || ! git -C "$DOTFILES" diff --cached --quiet; then
      fmt_error "Uncommitted changes in $DOTFILES."
      detail "Commit or stash them, then re-run the script."
      exit 1
    fi
    info "Updating dotfiles repo"
    ensure retry 5 git -C "$DOTFILES" pull --rebase origin master
  else
    info "Cloning dotfiles repo"
    ensure retry 5 git clone --depth=1 "$REPO" "$DOTFILES"
  fi
}

# ==========================================================
# Shared steps
# ==========================================================
clone_zsh_plugins() {
  mkdir -p "$HOME/.zsh/plugins"
  local p
  for p in zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
    [[ -d "$HOME/.zsh/plugins/$p" ]] || \
      ensure retry 3 git clone --depth=1 "https://github.com/zsh-users/$p" "$HOME/.zsh/plugins/$p"
  done
}

# Symlink each file/dir from the repo's helix/ folder into ~/.config/helix/.
# The directory itself stays real so the helix runtime/ (installed by
# extract_helix or pkg) can live alongside without polluting the repo.
# -n: replace an existing symlink-to-dir instead of descending into it.
deploy_editor_configs() {
  mkdir -p "$HOME/.config/helix"
  local f
  for f in "$DOTFILES"/helix/*; do
    ln -sfn "$f" "$HOME/.config/helix/$(basename "$f")"
  done
}

# zsh config: plugins, .zshrc symlink, default shell.
deploy_zsh_config() {
  clone_zsh_plugins
  backup_if_real "$HOME/.zshrc"
  ln -sf "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
  set_default_shell
}

# Helix "config" includes its language servers (gopls if Go is present;
# bash-ls keeps its internal Node.js prompt since that is a heavy extra).
deploy_helix_termux() {
  deploy_editor_configs
  install_helix_lsp pkg
}

deploy_helix_ubuntu() {
  deploy_editor_configs
  install_helix_lsp apt-get
}

deploy_zellij_config() {
  mkdir -p "$HOME/.config/zellij"
  ln -sf "$DOTFILES/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
}

setup_ssh() {
  mkdir -p "$HOME/.ssh/cm" "$HOME/.ssh/config.d"
  chmod 700 "$HOME/.ssh" "$HOME/.ssh/cm" "$HOME/.ssh/config.d"
  chmod 600 "$DOTFILES/ssh/config" "$DOTFILES/ssh/hardening.conf"
  ln -sf "$DOTFILES/ssh/hardening.conf" "$HOME/.ssh/hardening.conf"

  if [[ -z "$(ls -A "$HOME/.ssh/config.d" 2>/dev/null)" ]]; then
    cp "$DOTFILES/ssh/config.d/00-example.conf" "$HOME/.ssh/config.d/00-example.conf"
  fi
  chmod 600 "$HOME"/.ssh/config.d/*.conf 2>/dev/null || true

  backup_if_real "$HOME/.ssh/config"
  ln -sf "$DOTFILES/ssh/config" "$HOME/.ssh/config"

  find "$HOME/.ssh" -maxdepth 1 -type f -name 'id_*' ! -name '*.pub' \
    -exec chmod 600 {} \; 2>/dev/null || true
}

set_default_shell() {
  if [[ "$(basename "${SHELL:-}")" != "zsh" ]] && check_cmd zsh; then
    chsh -s "$(command -v zsh)" || \
      detail "Could not change shell automatically; run 'chsh -s zsh' manually."
  fi
}

# Language servers for Helix (Go + Bash).
# $1 = package manager for nodejs ("pkg" or "apt-get").
install_helix_lsp() {
  if check_cmd gopls && check_cmd bash-language-server; then
    return 0
  fi
  info "Installing Helix language servers"

  if check_cmd go && ! check_cmd gopls; then
    go install golang.org/x/tools/gopls@latest \
      || fmt_error "Failed to install gopls (continuing)"
  fi

  if ! check_cmd bash-language-server; then
    if check_cmd npm; then
      ensure npm install -g bash-language-server
    elif ask "bash-language-server requires Node.js. Install it?"; then
      case "$1" in
        pkg)     ensure pkg install -y nodejs ;;
        apt-get) ensure $SUDO apt-get install -y nodejs npm ;;
      esac
      ensure npm install -g bash-language-server
    else
      detail "Skipping bash-language-server (Node.js declined)."
    fi
  fi
}

# ==========================================================
# TERMUX branch
# ==========================================================
install_termux() {
  # Refresh package lists only; upgrading the system is update-packages()'s
  # job (zsh function), not the installer's.
  ensure pkg update -y

  # Script prerequisites — installed without asking.
  ensure pkg install -y git curl unzip openssh

  # Bricks: tool + its config, installed and deployed immediately.
  # The zsh group checks every member, not just zsh itself.
  if any_missing zsh fzf eza zoxide; then
    if ask "Install zsh and its tools (fzf, eza, zoxide)?"; then
      attempt "zsh + tools" pkg install -y zsh fzf eza zoxide
    fi
  fi
  check_cmd zsh && deploy_zsh_config
  brick zellij "Install zellij?" deploy_zellij_config pkg install -y zellij
  brick starship "Install starship?" - pkg install -y starship
  brick go "Install golang?" - pkg install -y golang
  brick hx "Install helix?" deploy_helix_termux pkg install -y helix
  if check_cmd go; then
    brick sshm "Install sshm?" - go install github.com/Gu1llaum-3/sshm@latest
    brick golangci-lint "Install golangci-lint?" - install_golangci
  fi
  brick shellcheck "Install shellcheck?" - pkg install -y shellcheck
  brick pre-commit "Install pre-commit (via uv)?" - install_precommit pkg

  # Persistent ssh-agent via termux-services (pairs with AddKeysToAgent).
  if ! check_cmd sv-enable && ask "Enable a persistent ssh-agent (termux-services)?"; then
    attempt "termux-services" pkg install -y termux-services
    if check_cmd sv-enable; then
      sv-enable ssh-agent 2>/dev/null \
        || detail "Restart Termux, then run: sv-enable ssh-agent"
    fi
  fi

  # Nerd Font: on Termux the font is an APP setting (~/.termux/font.ttf)
  if [[ ! -f "$HOME/.termux/font.ttf" ]] && ask "Install the Nerd Font?"; then
    mkdir -p "$HOME/.termux"
    attempt "Nerd Font" curl -fL --retry 3 --retry-all-errors -o "$HOME/.termux/font.ttf" \
      "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FiraCode/Regular/FiraCodeNerdFont-Regular.ttf"
    if [[ -f "$HOME/.termux/font.ttf" ]] && check_cmd termux-reload-settings; then
      termux-reload-settings
    fi
  fi

  # ssh is a prerequisite, so its hardened client config deploys
  # automatically (brick rule: tool present -> config deployed).
  setup_ssh

  report_failures
}

# ==========================================================
# UBUNTU / glibc branch
# ==========================================================
install_apt_packages() {
  # Refresh package lists only; upgrading the system is update-packages()'s
  # job (zsh function), not the installer's.
  ensure $SUDO apt-get update -y

  # Script prerequisites — installed without asking.
  ensure $SUDO apt-get install -y curl git unzip
}

install_nerd_font_gui() {
  if has_gui && [[ ! -f "$HOME/.local/share/fonts/FiraCodeNerdFont-Regular.ttf" ]]; then
    mkdir -p "$HOME/.local/share/fonts"
    curl -fsSL -o /tmp/FiraCode.zip \
      https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
    unzip -o /tmp/FiraCode.zip -d "$HOME/.local/share/fonts"
    rm -f /tmp/FiraCode.zip
    fc-cache -f
  fi
}

install_helix_glibc() {
  check_cmd hx && return 0
  HELIX_TAG="$(gh_latest_tag helix-editor/helix)"
  [[ -n "$HELIX_TAG" ]] || { fmt_error "Failed to resolve helix version"; return 1; }
  fetch_and_install \
    "https://github.com/helix-editor/helix/releases/download/${HELIX_TAG}/helix-${HELIX_TAG}-${ARCH_AARCH64}-linux.tar.xz" \
    extract_helix
}

install_zellij_glibc() {
  check_cmd zellij && return 0
  EXTRACT_BIN=zellij fetch_and_install \
    "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${ARCH_AARCH64}-unknown-linux-musl.tar.gz" \
    extract_single_bin
}

install_sshm_glibc() {
  check_cmd sshm && return 0
  local tag; tag="$(gh_latest_tag Gu1llaum-3/sshm)"
  [[ -n "$tag" ]] || { fmt_error "Failed to resolve sshm version"; return 1; }
  local url="https://github.com/Gu1llaum-3/sshm/releases/download/${tag}/sshm_Linux_${ARCH_ARM64}.tar.gz"
  EXTRACT_BIN=sshm fetch_and_install "$url" extract_single_bin \
    "https://github.com/Gu1llaum-3/sshm/releases/download/${tag}/checksums.txt"
}

# Go toolchain, user-local: ~/.local/go (add ~/.local/go/bin to PATH).
install_go_glibc() {
  check_cmd go && return 0
  local ver
  ver="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)"
  [[ -n "$ver" ]] || { fmt_error "Failed to resolve Go version"; return 1; }
  local file="${ver}.linux-${ARCH_GO}.tar.gz"
  local tmp; tmp="$(mktemp)"
  TMP_FILES+=("$tmp")
  if ! curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o "$tmp" \
    "https://go.dev/dl/${file}"; then
    rm -f "$tmp"; return 1
  fi
  verify_sha256 "$tmp" "https://dl.google.com/go/${file}.sha256" "$file" \
    || { rm -f "$tmp"; return 1; }
  rm -rf "$HOME/.local/go"
  mkdir -p "$HOME/.local"
  tar -C "$HOME/.local" -xzf "$tmp" || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"
}

# uv: Python package/tool manager (Astral). Not a user-facing brick: it is
# the install vehicle for pre-commit (and any future Python CLI tool).
# UV_NO_MODIFY_PATH: never let the installer edit rc files — .zshrc is a
# symlink into the dotfiles repo and already exports ~/.local/bin.
install_uv_glibc() {
  check_cmd uv && return 0
  curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
}

# pre-commit, installed through uv. uv (and python on Termux) is brought
# in automatically as a dependency step.
# $1 = "pkg" (Termux) or "glibc" (Ubuntu)
install_precommit() {
  check_cmd pre-commit && return 0
  if ! check_cmd uv; then
    case "$1" in
      pkg)   pkg install -y uv python || return 1 ;;
      glibc) install_uv_glibc || return 1 ;;
    esac
  fi
  uv tool install pre-commit
}

# ShellCheck linter: static release binary -> ~/.local/bin (asset names
# use the raw uname -m arch, so $ARCH is used directly).
install_shellcheck_glibc() {
  check_cmd shellcheck && return 0
  local tag; tag="$(gh_latest_tag koalaman/shellcheck)"
  [[ -n "$tag" ]] || { fmt_error "Failed to resolve shellcheck version"; return 1; }
  SHELLCHECK_TAG="$tag" fetch_and_install \
    "https://github.com/koalaman/shellcheck/releases/download/${tag}/shellcheck-${tag}.linux.${ARCH}.tar.xz" \
    extract_shellcheck
}

# golangci-lint: official installer, user-local. The project advises its
# install script over `go install` (version/reproducibility issues).
install_golangci() {
  check_cmd golangci-lint && return 0
  curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh \
    | sh -s -- -b "$HOME/.local/bin"
}

install_starship_glibc() {
  check_cmd starship && return 0
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://starship.rs/install.sh | \
    sh -s -- --yes --bin-dir "$HOME/.local/bin"
}

install_alacritty_gui() {
  if has_gui && ! check_cmd alacritty; then
    $SUDO apt-get install -y software-properties-common
    $SUDO add-apt-repository -y ppa:aslatter/ppa
    $SUDO apt-get update -qq && $SUDO apt-get install -y alacritty
  fi
}

deploy_alacritty_config() {
  if has_gui; then
    mkdir -p "$HOME/.config/alacritty"
    ln -sf "$DOTFILES/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
  fi
}

install_ubuntu() {
  # Tools are installed user-local; make sure the directory exists.
  mkdir -p "$HOME/.local/bin"

  install_apt_packages

  # Bricks: tool + its config, installed and deployed immediately.
  # The zsh group checks every member, not just zsh itself.
  # $SUDO is intentionally unquoted: it disappears when empty.
  if any_missing zsh fzf eza zoxide keychain; then
    if ask "Install zsh and its tools (fzf, eza, zoxide, keychain)?"; then
      attempt "zsh + tools" $SUDO apt-get install -y zsh fzf eza zoxide keychain
    fi
  fi
  check_cmd zsh && deploy_zsh_config
  brick go "Install golang (~/.local/go)?" - install_go_glibc
  brick hx "Install helix?" deploy_helix_ubuntu install_helix_glibc
  brick zellij "Install zellij?" deploy_zellij_config install_zellij_glibc
  brick sshm "Install sshm?" - install_sshm_glibc
  brick starship "Install starship?" - install_starship_glibc
  brick pre-commit "Install pre-commit (via uv)?" - install_precommit glibc
  brick shellcheck "Install shellcheck?" - install_shellcheck_glibc
  if check_cmd go; then
    brick golangci-lint "Install golangci-lint?" - install_golangci
  fi
  if has_gui; then
    brick alacritty "Install alacritty?" deploy_alacritty_config install_alacritty_gui
    if ask "Install the Nerd Font?"; then
      attempt "Nerd Font" install_nerd_font_gui
    fi
  fi

  # ssh is a prerequisite, so its hardened client config deploys
  # automatically (brick rule: tool present -> config deployed).
  setup_ssh

  report_failures
}

# ==========================================================
# ROCKY / RHEL-family branch (SSH bastion: hardening only)
# No zsh, no tools — this host is only a ProxyJump relay.
# Deploys ssh/sshd_hardening.conf into /etc/ssh/sshd_config.d/
# with a lockout guard and config validation before restart.
# ==========================================================
bootstrap_rhel() {
  check_cmd git || ensure $SUDO dnf -y install git
}

install_rhel_bastion() {
  if ! ask "Apply sshd hardening (keys only, no root)?"; then
    detail "sshd hardening skipped."
    report_failures
    return 0
  fi

  # Lockout guard: never disable password auth without a working key.
  if [[ ! -s "$HOME/.ssh/authorized_keys" ]]; then
    fmt_error "No ~/.ssh/authorized_keys found."
    fmt_error "Add your public key first or you will lock yourself out."
    exit 1
  fi

  # Copy (not symlink): /etc must not depend on a file in \$HOME.
  ensure $SUDO install -m 600 -o root -g root \
    "$DOTFILES/ssh/sshd_hardening.conf" \
    /etc/ssh/sshd_config.d/00-hardening.conf

  # Validate before restarting; roll back if the config is broken.
  if $SUDO sshd -t; then
    ensure $SUDO systemctl restart sshd
    info "sshd hardened. Test a NEW connection before closing this one."
  else
    $SUDO rm -f /etc/ssh/sshd_config.d/00-hardening.conf
    fmt_error "sshd config validation failed — hardening removed, sshd untouched."
    exit 1
  fi

  report_failures
}

# ==========================================================
# Main
# ==========================================================
usage() {
  cat <<'EOF'
Usage: install.sh [target] [-y]

  target     force the install branch instead of auto-detecting:
               ubuntu   apt-based desktop/server setup
               termux   Termux/Android setup
               rhel     Rocky/RHEL bastion (sshd hardening)
  -y, --yes  answer yes to every prompt (unattended install)
EOF
}

main() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -y|--yes)          ASSUME_YES=1 ;;
      ubuntu|termux|rhel) TARGET="$arg" ;;
      -h|--help)         usage; exit 0 ;;
      *) fmt_error "unknown option: $arg"; usage; exit 1 ;;
    esac
  done

  detect_env

  # Make user-local install locations visible to this script run itself:
  # without this, gopls installation cannot find the Go toolchain that
  # install_go_glibc just placed in ~/.local/go.
  export PATH="$HOME/.local/bin:$HOME/.local/go/bin:$HOME/go/bin:$PATH"

  # Forced target overrides detection (proot, containers, testing...).
  case "$TARGET" in
    termux) IS_TERMUX=1; IS_RHEL=0 ;;
    rhel)   IS_TERMUX=0; IS_RHEL=1 ;;
    ubuntu) IS_TERMUX=0; IS_RHEL=0 ;;
  esac
  [[ -n "$TARGET" ]] && detail "Forced target: $TARGET"

  [[ "$IS_RHEL" -eq 1 ]] && bootstrap_rhel
  preflight
  clone_or_update_repo

  if [[ "$IS_TERMUX" -eq 1 ]]; then
    install_termux
  elif [[ "$IS_RHEL" -eq 1 ]]; then
    install_rhel_bastion
  else
    install_ubuntu
  fi
}

main "$@"
