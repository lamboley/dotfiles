#!/usr/bin/env bash
#
# Dotfiles installer for lamboley/dotfiles.
#
# Run via curl:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/lamboley/dotfiles/master/tools/install.sh)"
# Or download then run (recommended for interactive prompts):
#   curl -fsSL https://raw.githubusercontent.com/lamboley/dotfiles/master/tools/install.sh -o install.sh
#   bash install.sh
#
# Targets: Termux (native, bionic) and Ubuntu/glibc (desktop, servers, proot).
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
DOTFILES="$HOME/.dotfiles"
REPO="https://github.com/lamboley/dotfiles.git"

IS_TERMUX=0
ARCH=""
ARCH_ARM64=""    # x86_64 -> x86_64 ; aarch64 -> arm64   (neovim, lazygit, sshm)
ARCH_AARCH64=""  # x86_64 -> x86_64 ; aarch64 -> aarch64 (zellij, helix)
SUDO=""
INSTALL_NVIM=0
INSTALL_HELIX=0
FAILED_STEPS=()  # optional steps that failed (reported at the end)

# Clean up any leftover temp files on exit, even if the script dies mid-way.
cleanup() {
  rm -rf /tmp/helix-extract /tmp/FiraCode.zip 2>/dev/null || true
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Output helpers (colors only when stdout is a terminal)
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RED=$'\033[1;31m'; C_GREEN=$'\033[1;32m'
  C_BLUE=$'\033[1;34m'; C_RESET=$'\033[0m'
else
  C_RED=""; C_GREEN=""; C_BLUE=""; C_RESET=""
fi

info()      { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
success()   { printf '%s==>%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
fmt_error() { printf '%sError:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }

# ---------------------------------------------------------------------------
# Small utilities
# ---------------------------------------------------------------------------
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

# Print a summary of optional steps that failed, if any.
report_failures() {
  if [[ "${#FAILED_STEPS[@]}" -gt 0 ]]; then
    fmt_error "Some optional steps failed: ${FAILED_STEPS[*]}"
    info "The rest of the setup completed. You can re-run the script to retry."
  fi
}

has_gui() { [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; }

# Yes/no prompt that survives `curl | bash` by reading from /dev/tty.
# Non-interactive (no tty): returns "yes" so unattended installs are complete.
ask() {
  [[ ! -t 1 || ! -e /dev/tty ]] && return 0
  local ans
  printf '%s [Y/n] ' "$1"
  read -r ans < /dev/tty || return 0
  [[ "$ans" =~ ^[Nn] ]] && return 1
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
    info "Backed up existing $1 to $1.pre-dotfiles.bak"
  fi
}

# ---------------------------------------------------------------------------
# GitHub binary installer with a pluggable extraction step.
#   $1 = download URL
#   $2 = name of a function handling extraction; it receives the downloaded
#        file path as $1 and is responsible for installing the binary.
# The helper owns the common parts (download + cleanup); the callback owns
# the layout differences (/usr/local/bin vs /opt, runtime dir, etc.).
# ---------------------------------------------------------------------------
fetch_and_install() {
  local url="$1" extract_fn="$2"
  local tmp; tmp="$(mktemp)"
  if ! curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o "$tmp" "$url"; then
    rm -f "$tmp"; return 1
  fi
  "$extract_fn" "$tmp" || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"
}

# Extraction callbacks ------------------------------------------------------
# Simple case: a .tar.gz containing a single binary -> /usr/local/bin.
# Uses $EXTRACT_BIN (set by caller) as the binary name inside the tarball.
# Callbacks return non-zero on failure so attempt() can record it.
extract_single_bin() {
  $SUDO tar -C /usr/local/bin -xzf "$1" "$EXTRACT_BIN"
}

extract_neovim() {
  # nvim ships a whole tree; install under /opt and symlink the binary.
  $SUDO rm -rf "/opt/nvim-linux-${ARCH_ARM64}"
  $SUDO tar -C /opt -xzf "$1" || return 1
  $SUDO ln -sf "/opt/nvim-linux-${ARCH_ARM64}/bin/nvim" /usr/local/bin/nvim
}

extract_helix() {
  # helix ships hx + a runtime dir that must live where hx looks for it.
  local dir="/tmp/helix-extract"
  rm -rf "$dir"; mkdir -p "$dir"
  tar -C "$dir" -xJf "$1" || return 1
  local hxdir="$dir/helix-${HELIX_TAG}-${ARCH_AARCH64}-linux"
  $SUDO install -m 755 "$hxdir/hx" /usr/local/bin/hx || return 1
  mkdir -p "$HOME/.config/helix"
  rm -rf "$HOME/.config/helix/runtime"
  cp -r "$hxdir/runtime" "$HOME/.config/helix/runtime"
  rm -rf "$dir"
}

# ---------------------------------------------------------------------------
# Detection / preflight
# ---------------------------------------------------------------------------
detect_env() {
  [[ -n "${TERMUX_VERSION:-}" ]] && IS_TERMUX=1

  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  ARCH_ARM64="x86_64"; ARCH_AARCH64="x86_64" ;;
    aarch64) ARCH_ARM64="arm64";  ARCH_AARCH64="aarch64" ;;
    *) fmt_error "Unsupported architecture: $ARCH (expected x86_64 or aarch64)"; exit 1 ;;
  esac

  if [[ "$IS_TERMUX" -eq 1 || "$(id -u)" -eq 0 ]]; then
    SUDO=""
  else
    need_cmd sudo
    SUDO="sudo"
  fi
}

preflight() {
  need_cmd curl
  need_cmd git
  need_cmd uname
  need_cmd sed
}

# ---------------------------------------------------------------------------
# Repo
# ---------------------------------------------------------------------------
clone_or_update_repo() {
  if [[ -d "$DOTFILES" ]]; then
    info "Updating dotfiles repo"
    ensure git -C "$DOTFILES" pull --rebase origin master
  else
    info "Cloning dotfiles repo"
    ensure git clone --depth=1 "$REPO" "$DOTFILES"
  fi
}

choose_editors() {
  if ask "Installer Neovim ?"; then INSTALL_NVIM=1; fi
  if ask "Installer Helix ?"; then INSTALL_HELIX=1; fi
}

# ---------------------------------------------------------------------------
# Shared steps
# ---------------------------------------------------------------------------
clone_zsh_plugins() {
  mkdir -p "$HOME/.zsh/plugins"
  local p
  for p in zsh-autosuggestions zsh-syntax-highlighting; do
    [[ -d "$HOME/.zsh/plugins/$p" ]] || \
      ensure git clone --depth=1 "https://github.com/zsh-users/$p" "$HOME/.zsh/plugins/$p"
  done
}

deploy_editor_configs() {
  if [[ "$INSTALL_NVIM" -eq 1 ]]; then
    mkdir -p "$HOME/.config/nvim"
    cp -r "$DOTFILES/nvim/." "$HOME/.config/nvim/"
  fi
  if [[ "$INSTALL_HELIX" -eq 1 ]]; then
    mkdir -p "$HOME/.config/helix"
    cp -r "$DOTFILES/helix/." "$HOME/.config/helix/"
  fi
}

deploy_common_symlinks() {
  backup_if_real "$HOME/.zshrc"
  ln -sf "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
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
      info "Could not change shell automatically; run 'chsh -s zsh' manually."
  fi
}

# Language servers for Helix (Go + Bash). Only runs if Helix was installed.
# $1 = package manager for nodejs ("pkg" or "apt-get").
install_helix_lsp() {
  [[ "$INSTALL_HELIX" -eq 1 ]] || return 0
  info "Installing Helix language servers"

  if check_cmd go && ! check_cmd gopls; then
    go install golang.org/x/tools/gopls@latest \
      || fmt_error "Failed to install gopls (continuing)"
  fi

  if ! check_cmd bash-language-server; then
    if check_cmd npm; then
      ensure npm install -g bash-language-server
    elif ask "bash-language-server nécessite Node.js. L'installer ?"; then
      case "$1" in
        pkg)     ensure pkg install -y nodejs ;;
        apt-get) ensure $SUDO apt-get install -y nodejs npm ;;
      esac
      ensure npm install -g bash-language-server
    else
      info "Skipping bash-language-server (Node.js declined)."
    fi
  fi
}

# ---------------------------------------------------------------------------
# TERMUX branch
# ---------------------------------------------------------------------------
install_termux() {
  info "Termux detected — installing via pkg"
  ensure pkg update -y
  ensure pkg upgrade -y
  ensure pkg install -y \
    git zsh zellij lazygit starship \
    fzf ripgrep fd eza openssh curl unzip golang

  if [[ "$INSTALL_NVIM" -eq 1 ]]; then ensure pkg install -y neovim; fi
  if [[ "$INSTALL_HELIX" -eq 1 ]]; then ensure pkg install -y helix; fi

  clone_zsh_plugins

  if ! check_cmd sshm; then
    attempt "sshm" go install github.com/Gu1llaum-3/sshm@latest
  fi

  # Nerd Font: on Termux the font is an APP setting (~/.termux/font.ttf)
  if [[ ! -f "$HOME/.termux/font.ttf" ]]; then
    mkdir -p "$HOME/.termux"
    attempt "Nerd Font" curl -fL --retry 3 --retry-all-errors -o "$HOME/.termux/font.ttf" \
      "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FiraCode/Regular/FiraCodeNerdFont-Regular.ttf"
    if [[ -f "$HOME/.termux/font.ttf" ]] && check_cmd termux-reload-settings; then
      termux-reload-settings
    fi
  fi

  deploy_editor_configs
  deploy_common_symlinks
  setup_ssh
  set_default_shell
  install_helix_lsp pkg
  report_failures

  success "Termux setup complete. Restart Termux to land in zsh."
}

# ---------------------------------------------------------------------------
# UBUNTU / glibc branch
# ---------------------------------------------------------------------------
install_apt_packages() {
  info "Installing apt packages"
  ensure $SUDO apt-get update -y
  $SUDO apt-get upgrade -y && $SUDO apt-get autoremove -y
  ensure $SUDO apt-get install -y \
    curl git zsh unzip ripgrep fd-find fzf eza keychain
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
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

install_neovim_glibc() {
  [[ "$INSTALL_NVIM" -eq 1 ]] || return 0
  local tag; tag="$(gh_latest_tag neovim/neovim)"
  [[ -n "$tag" ]] || { fmt_error "Failed to resolve neovim version"; return 1; }
  fetch_and_install \
    "https://github.com/neovim/neovim/releases/download/${tag}/nvim-linux-${ARCH_ARM64}.tar.gz" \
    extract_neovim
}

install_helix_glibc() {
  [[ "$INSTALL_HELIX" -eq 1 ]] || return 0
  check_cmd hx && return 0
  HELIX_TAG="$(gh_latest_tag helix-editor/helix)"
  [[ -n "$HELIX_TAG" ]] || { fmt_error "Failed to resolve helix version"; return 1; }
  fetch_and_install \
    "https://github.com/helix-editor/helix/releases/download/${HELIX_TAG}/helix-${HELIX_TAG}-${ARCH_AARCH64}-linux.tar.xz" \
    extract_helix
}

install_lazygit_glibc() {
  check_cmd lazygit && return 0
  local tag ver; tag="$(gh_latest_tag jesseduffield/lazygit)"; ver="${tag#v}"
  [[ -n "$ver" ]] || { fmt_error "Failed to resolve lazygit version"; return 1; }
  EXTRACT_BIN=lazygit fetch_and_install \
    "https://github.com/jesseduffield/lazygit/releases/download/${tag}/lazygit_${ver}_linux_${ARCH_ARM64}.tar.gz" \
    extract_single_bin
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
  EXTRACT_BIN=sshm fetch_and_install \
    "https://github.com/Gu1llaum-3/sshm/releases/download/${tag}/sshm_Linux_${ARCH_ARM64}.tar.gz" \
    extract_single_bin
}

install_starship_glibc() {
  check_cmd starship && return 0
  curl -fsSL https://starship.rs/install.sh | $SUDO sh -s -- --yes
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
  info "Ubuntu/glibc target"
  install_apt_packages                          # critical: must succeed
  attempt "Nerd Font"  install_nerd_font_gui
  attempt "neovim"     install_neovim_glibc
  attempt "helix"      install_helix_glibc
  attempt "lazygit"    install_lazygit_glibc
  attempt "zellij"     install_zellij_glibc
  attempt "sshm"       install_sshm_glibc
  attempt "alacritty"  install_alacritty_gui
  attempt "starship"   install_starship_glibc
  clone_zsh_plugins
  deploy_editor_configs
  deploy_common_symlinks
  deploy_alacritty_config
  setup_ssh
  set_default_shell
  install_helix_lsp apt-get
  report_failures
  success "Ubuntu setup complete."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  detect_env
  preflight
  clone_or_update_repo
  choose_editors

  if [[ "$IS_TERMUX" -eq 1 ]]; then
    install_termux
  else
    install_ubuntu
  fi
}

main "$@"
