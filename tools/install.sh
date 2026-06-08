#!/bin/sh
#
# Dotfiles installer for lamboley/dotfiles.
#
# Run via curl:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/lamboley/dotfiles/master/install.sh)"
# Or download then run (recommended for interactive prompts):
#   curl -fsSL https://raw.githubusercontent.com/lamboley/dotfiles/master/install.sh -o install.sh
#   sh install.sh
#
# Targets: Termux (native, bionic) and Ubuntu/glibc (desktop, servers, proot).
#
set -eu

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
DOTFILES="$HOME/.dotfiles"
REPO="https://github.com/lamboley/dotfiles.git"

IS_TERMUX=0
ARCH=""
SUDO=""
INSTALL_NVIM=0
INSTALL_HELIX=0

# ---------------------------------------------------------------------------
# Output helpers (colors only when stdout is a terminal)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  C_RED=$(printf '\033[1;31m'); C_GREEN=$(printf '\033[1;32m')
  C_BLUE=$(printf '\033[1;34m'); C_RESET=$(printf '\033[0m')
else
  C_RED=""; C_GREEN=""; C_BLUE=""; C_RESET=""
fi

info()      { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
success()   { printf '%s==>%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
fmt_error() { printf '%sError:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }

# ---------------------------------------------------------------------------
# Small utilities (inspired by rustup's ensure/need_cmd)
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

has_gui() { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }

# Yes/no prompt that survives `curl | sh` by reading from /dev/tty.
# Non-interactive (no tty): returns "yes" so unattended installs are complete.
# Default answer is yes ([Y/n]).
ask() {
  # Not interactive at all -> accept default (yes)
  if [ ! -t 1 ] || [ ! -e /dev/tty ]; then
    return 0
  fi
  printf '%s [Y/n] ' "$1"
  read -r _ans < /dev/tty || return 0
  case "$_ans" in
    [nN] | [nN][oO]) return 1 ;;
    *) return 0 ;;
  esac
}

# Resolve a repo's latest release tag WITHOUT the GitHub API (no rate limit).
# /releases/latest redirects to /releases/tag/<tag>; read <tag> from the URL.
gh_latest_tag() {
  curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/$1/releases/latest" 2>/dev/null | sed -n 's#.*/tag/##p'
}

# Back up a real file (not a symlink) before we replace it with our symlink.
backup_if_real() {
  if [ -e "$1" ] && [ ! -L "$1" ]; then
    mv "$1" "$1.pre-dotfiles.bak"
    info "Backed up existing $1 to $1.pre-dotfiles.bak"
  fi
}

# ---------------------------------------------------------------------------
# Detection / preflight
# ---------------------------------------------------------------------------
detect_env() {
  [ -n "${TERMUX_VERSION:-}" ] && IS_TERMUX=1

  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64 | aarch64) ;;
    *) fmt_error "Unsupported architecture: $ARCH (expected x86_64 or aarch64)"; exit 1 ;;
  esac

  # sudo only when not already root and not on Termux (no root there)
  if [ "$IS_TERMUX" -eq 1 ] || [ "$(id -u)" -eq 0 ]; then
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
  if [ -d "$DOTFILES" ]; then
    info "Updating dotfiles repo"
    ensure git -C "$DOTFILES" pull --rebase origin master
  else
    info "Cloning dotfiles repo"
    ensure git clone --depth=1 "$REPO" "$DOTFILES"
  fi
}

# ---------------------------------------------------------------------------
# Editor choice
# ---------------------------------------------------------------------------
choose_editors() {
  if ask "Installer Neovim ?"; then INSTALL_NVIM=1; fi
  if ask "Installer Helix ?"; then INSTALL_HELIX=1; fi
}

# ---------------------------------------------------------------------------
# Shared steps (both platforms)
# ---------------------------------------------------------------------------
clone_zsh_plugins() {
  mkdir -p "$HOME/.zsh/plugins"
  [ -d "$HOME/.zsh/plugins/zsh-autosuggestions" ] || \
    ensure git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$HOME/.zsh/plugins/zsh-autosuggestions"
  [ -d "$HOME/.zsh/plugins/zsh-syntax-highlighting" ] || \
    ensure git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$HOME/.zsh/plugins/zsh-syntax-highlighting"
}

deploy_editor_configs() {
  if [ "$INSTALL_NVIM" -eq 1 ]; then
    mkdir -p "$HOME/.config/nvim"
    cp -r "$DOTFILES/nvim/." "$HOME/.config/nvim/"
  fi
  if [ "$INSTALL_HELIX" -eq 1 ]; then
    mkdir -p "$HOME/.config/helix"
    cp -r "$DOTFILES/helix/." "$HOME/.config/helix/"
  fi
}

deploy_common_symlinks() {
  backup_if_real "$HOME/.zshrc"
  ln -s -f "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"

  mkdir -p "$HOME/.config/zellij"
  ln -s -f "$DOTFILES/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
}

setup_ssh() {
  mkdir -p "$HOME/.ssh/cm" "$HOME/.ssh/config.d"
  chmod 700 "$HOME/.ssh" "$HOME/.ssh/cm" "$HOME/.ssh/config.d"
  chmod 600 "$DOTFILES/ssh/config" "$DOTFILES/ssh/hardening.conf"
  ln -s -f "$DOTFILES/ssh/hardening.conf" "$HOME/.ssh/hardening.conf"

  # Seed an example host only if config.d is empty
  if [ -z "$(ls -A "$HOME/.ssh/config.d" 2>/dev/null)" ]; then
    cp "$DOTFILES/ssh/config.d/00-example.conf" "$HOME/.ssh/config.d/00-example.conf"
  fi
  chmod 600 "$HOME"/.ssh/config.d/*.conf 2>/dev/null || true

  # Entry config: back up a foreign config, then symlink ours
  backup_if_real "$HOME/.ssh/config"
  ln -s -f "$DOTFILES/ssh/config" "$HOME/.ssh/config"

  # Tighten permissions on existing private keys
  find "$HOME/.ssh" -maxdepth 1 -type f -name 'id_*' ! -name '*.pub' \
    -exec chmod 600 {} \; 2>/dev/null || true
}

set_default_shell() {
  if [ "$(basename "${SHELL:-}")" != "zsh" ] && check_cmd zsh; then
    chsh -s "$(command -v zsh)" || \
      info "Could not change shell automatically; run 'chsh -s zsh' manually."
  fi
}

# Language servers for Helix (Go + Bash). Only runs if Helix was installed.
# gopls comes from Go (already present). bash-language-server needs npm/Node,
# so we ask before pulling in that dependency.
# $1 is the package manager command to install nodejs ("pkg" or "apt-get").
install_helix_lsp() {
  [ "$INSTALL_HELIX" -eq 1 ] || return 0
  info "Installing Helix language servers"

  # Go LSP — uses the Go toolchain we already installed.
  if check_cmd go && ! check_cmd gopls; then
    go install golang.org/x/tools/gopls@latest \
      || fmt_error "Failed to install gopls (continuing)"
  fi

  # Bash LSP — needs npm. Ask before installing Node, it's a heavy dependency.
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

  if [ "$INSTALL_NVIM" -eq 1 ]; then ensure pkg install -y neovim; fi
  if [ "$INSTALL_HELIX" -eq 1 ]; then ensure pkg install -y helix; fi

  clone_zsh_plugins

  # sshm: not packaged, build from source (pure Go)
  if ! check_cmd sshm; then
    go install github.com/Gu1llaum-3/sshm@latest \
      || fmt_error "Failed to build sshm (continuing without it)"
  fi

  # Nerd Font: on Termux the font is an APP setting (~/.termux/font.ttf)
  if [ ! -f "$HOME/.termux/font.ttf" ]; then
    mkdir -p "$HOME/.termux"
    if curl -fL --retry 3 --retry-all-errors -o "$HOME/.termux/font.ttf" \
      "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FiraCode/Regular/FiraCodeNerdFont-Regular.ttf"; then
      check_cmd termux-reload-settings && termux-reload-settings
    else
      fmt_error "Failed to install Termux Nerd Font (icons may be missing)"
    fi
  fi

  deploy_editor_configs
  deploy_common_symlinks
  setup_ssh
  set_default_shell
  install_helix_lsp pkg

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

  # Ubuntu names the binary fdfind
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
}

install_nerd_font_gui() {
  if has_gui && [ ! -f "$HOME/.local/share/fonts/FiraCodeNerdFont-Regular.ttf" ]; then
    mkdir -p "$HOME/.local/share/fonts"
    curl -fsSL -o /tmp/FiraCode.zip \
      https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
    unzip -o /tmp/FiraCode.zip -d "$HOME/.local/share/fonts"
    rm -f /tmp/FiraCode.zip
    fc-cache -f
  fi
}

install_neovim_glibc() {
  [ "$INSTALL_NVIM" -eq 1 ] || return 0
  case "$ARCH" in
    x86_64)  _na="x86_64" ;;
    aarch64) _na="arm64" ;;
  esac
  _tag=$(gh_latest_tag neovim/neovim)
  [ -n "$_tag" ] || { fmt_error "Failed to resolve neovim version"; exit 1; }
  ensure curl -fL --retry 3 --retry-delay 2 --retry-all-errors -O \
    "https://github.com/neovim/neovim/releases/download/${_tag}/nvim-linux-${_na}.tar.gz"
  $SUDO rm -rf "/opt/nvim-linux-${_na}"
  ensure $SUDO tar -C /opt -xzf "nvim-linux-${_na}.tar.gz"
  rm -f "nvim-linux-${_na}.tar.gz"
  $SUDO ln -sf "/opt/nvim-linux-${_na}/bin/nvim" /usr/local/bin/nvim
}

install_helix_glibc() {
  [ "$INSTALL_HELIX" -eq 1 ] || return 0
  check_cmd hx && return 0
  case "$ARCH" in
    x86_64)  _ha="x86_64" ;;
    aarch64) _ha="aarch64" ;;
  esac
  _tag=$(gh_latest_tag helix-editor/helix)
  [ -n "$_tag" ] || { fmt_error "Failed to resolve helix version"; exit 1; }
  ensure curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o /tmp/helix.tar.xz \
    "https://github.com/helix-editor/helix/releases/download/${_tag}/helix-${_tag}-${_ha}-linux.tar.xz"
  rm -rf /tmp/helix-extract && mkdir -p /tmp/helix-extract
  ensure tar -C /tmp/helix-extract -xJf /tmp/helix.tar.xz
  _hxdir="/tmp/helix-extract/helix-${_tag}-${_ha}-linux"
  ensure $SUDO install -m 755 "$_hxdir/hx" /usr/local/bin/hx
  # Helix needs its runtime dir (themes, grammars) where hx looks for it
  mkdir -p "$HOME/.config/helix"
  rm -rf "$HOME/.config/helix/runtime"
  cp -r "$_hxdir/runtime" "$HOME/.config/helix/runtime"
  rm -rf /tmp/helix.tar.xz /tmp/helix-extract
}

install_lazygit_glibc() {
  check_cmd lazygit && return 0
  case "$ARCH" in
    x86_64)  _la="x86_64" ;;
    aarch64) _la="arm64" ;;
  esac
  _tag=$(gh_latest_tag jesseduffield/lazygit)
  _ver=${_tag#v}
  [ -n "$_ver" ] || { fmt_error "Failed to resolve lazygit version"; exit 1; }
  ensure curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o /tmp/lazygit.tar.gz \
    "https://github.com/jesseduffield/lazygit/releases/download/${_tag}/lazygit_${_ver}_linux_${_la}.tar.gz"
  ensure $SUDO tar -C /usr/local/bin -xzf /tmp/lazygit.tar.gz lazygit
  rm -f /tmp/lazygit.tar.gz
}

install_zellij_glibc() {
  check_cmd zellij && return 0
  case "$ARCH" in
    x86_64)  _za="x86_64" ;;
    aarch64) _za="aarch64" ;;
  esac
  ensure curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o /tmp/zellij.tar.gz \
    "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${_za}-unknown-linux-musl.tar.gz"
  ensure $SUDO tar -C /usr/local/bin -xzf /tmp/zellij.tar.gz zellij
  rm -f /tmp/zellij.tar.gz
}

install_sshm_glibc() {
  check_cmd sshm && return 0
  case "$ARCH" in
    x86_64)  _sa="x86_64" ;;
    aarch64) _sa="arm64" ;;
  esac
  _tag=$(gh_latest_tag Gu1llaum-3/sshm)
  [ -n "$_tag" ] || { fmt_error "Failed to resolve sshm version"; exit 1; }
  ensure curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o /tmp/sshm.tar.gz \
    "https://github.com/Gu1llaum-3/sshm/releases/download/${_tag}/sshm_Linux_${_sa}.tar.gz"
  ensure $SUDO tar -C /usr/local/bin -xzf /tmp/sshm.tar.gz sshm
  rm -f /tmp/sshm.tar.gz
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
    ln -s -f "$DOTFILES/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
  fi
}

install_ubuntu() {
  info "Ubuntu/glibc target"
  install_apt_packages
  install_nerd_font_gui
  install_neovim_glibc
  install_helix_glibc
  install_lazygit_glibc
  install_zellij_glibc
  install_sshm_glibc
  install_alacritty_gui
  install_starship_glibc
  clone_zsh_plugins
  deploy_editor_configs
  deploy_common_symlinks
  deploy_alacritty_config
  setup_ssh
  set_default_shell
  install_helix_lsp apt-get
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

  if [ "$IS_TERMUX" -eq 1 ]; then
    install_termux
  else
    install_ubuntu
  fi
}

main "$@"
