#!/bin/sh
#
# This script should be run via curl:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/lamboley/dotfiles/master/install.sh)"
# or via wget:
#   sh -c "$(wget -qO- https://raw.githubusercontent.com/lamboley/dotfiles/master/install.sh)"
# or via fetch:
#   sh -c "$(fetch -o - https://raw.githubusercontent.com/lamboley/dotfiles/master/install.sh)"
#
set -e

DOTFILES="$HOME/.dotfiles"
REPO="https://github.com/lamboley/dotfiles.git"

fmt_error() {
  printf '\033[1;31mError: %s\033[0m\n' "$*" >&2
}

has_gui() {
  [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]
}

# Detect CPU architecture once; map per-project below since naming conventions differ.
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64 | aarch64) ;;
  *) fmt_error "Unsupported architecture: $ARCH (expected x86_64 or aarch64)"; exit 1 ;;
esac

# Privilege escalation: use sudo only when not already root.
# In proot/containers we're already root and sudo can't elevate (no_new_privs).
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  if ! command -v sudo >/dev/null 2>&1; then
    fmt_error "sudo is required to run this script as a non-root user"
    exit 1
  fi
  SUDO="sudo"
fi

# Get the repo
if [ -d "$DOTFILES" ]; then
  git -C "$DOTFILES" pull --rebase origin master
else
  git clone --depth=1 "$REPO" "$DOTFILES" || { fmt_error "Failed to clone dotfiles"; exit 1; }
fi

# Update and install packages
$SUDO apt-get update -y && $SUDO apt-get upgrade -y && $SUDO apt-get autoremove -y
$SUDO apt-get install -y curl git zsh unzip ripgrep fd-find fzf eza keychain

# Symlink fdfind to fd (Ubuntu names it fdfind)
mkdir -p "$HOME/.local/bin"
ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"

# Install FiraCode Nerd Font (GUI only)
if has_gui && [ ! -f "$HOME/.local/share/fonts/FiraCodeNerdFont-Regular.ttf" ]; then
  mkdir -p "$HOME/.local/share/fonts"
  curl -fsSL -o /tmp/FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
  unzip -o /tmp/FiraCode.zip -d "$HOME/.local/share/fonts"
  rm -f /tmp/FiraCode.zip
  fc-cache -f
fi

# Resolve a repo's latest release tag WITHOUT the GitHub API (no rate limit).
# /releases/latest redirects to /releases/tag/<tag>; we read <tag> from the
# effective URL. Echoes the tag (e.g. v0.62.2) or empty string on failure.
gh_latest_tag() {
  curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/$1/releases/latest" 2>/dev/null | sed -n 's#.*/tag/##p'
}

# Install Neovim (asset: nvim-linux-{x86_64,arm64}.tar.gz)
case "$ARCH" in
  x86_64)  NVIM_ARCH="x86_64" ;;
  aarch64) NVIM_ARCH="arm64" ;;
esac
NVIM_TAG=$(gh_latest_tag neovim/neovim)
[ -n "$NVIM_TAG" ] || { fmt_error "Failed to resolve neovim version"; exit 1; }
curl -fL --retry 3 --retry-delay 2 --retry-all-errors -O \
  "https://github.com/neovim/neovim/releases/download/${NVIM_TAG}/nvim-linux-${NVIM_ARCH}.tar.gz" \
  || { fmt_error "Failed to download neovim"; exit 1; }
$SUDO rm -rf "/opt/nvim-linux-${NVIM_ARCH}"
$SUDO tar -C /opt -xzf "nvim-linux-${NVIM_ARCH}.tar.gz" && rm -f "nvim-linux-${NVIM_ARCH}.tar.gz"
$SUDO ln -sf "/opt/nvim-linux-${NVIM_ARCH}/bin/nvim" /usr/local/bin/nvim

# Install lazygit (asset: lazygit_{version}_linux_{x86_64,arm64}.tar.gz)
if ! command -v lazygit >/dev/null 2>&1; then
  case "$ARCH" in
    x86_64)  LG_ARCH="x86_64" ;;
    aarch64) LG_ARCH="arm64" ;;
  esac
  LG_TAG=$(gh_latest_tag jesseduffield/lazygit)
  LG_VER=${LG_TAG#v}
  [ -n "$LG_VER" ] || { fmt_error "Failed to resolve lazygit version"; exit 1; }
  curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o /tmp/lazygit.tar.gz \
    "https://github.com/jesseduffield/lazygit/releases/download/${LG_TAG}/lazygit_${LG_VER}_linux_${LG_ARCH}.tar.gz" \
    || { fmt_error "Failed to download lazygit"; exit 1; }
  $SUDO tar -C /usr/local/bin -xzf /tmp/lazygit.tar.gz lazygit
  rm -f /tmp/lazygit.tar.gz
fi

# Install zellij (asset: zellij-{x86_64,aarch64}-unknown-linux-musl.tar.gz)
if ! command -v zellij >/dev/null 2>&1; then
  case "$ARCH" in
    x86_64)  ZJ_ARCH="x86_64" ;;
    aarch64) ZJ_ARCH="aarch64" ;;
  esac
  # No version in the asset name, so latest/download resolves directly.
  curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o /tmp/zellij.tar.gz \
    "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${ZJ_ARCH}-unknown-linux-musl.tar.gz" \
    || { fmt_error "Failed to download zellij"; exit 1; }
  $SUDO tar -C /usr/local/bin -xzf /tmp/zellij.tar.gz zellij
  rm -f /tmp/zellij.tar.gz
fi

# Install sshm (asset: sshm_Linux_{x86_64,arm64}.tar.gz; binary inside is "sshm")
if ! command -v sshm >/dev/null 2>&1; then
  case "$ARCH" in
    x86_64)  SSHM_ARCH="x86_64" ;;
    aarch64) SSHM_ARCH="arm64" ;;
  esac
  SSHM_TAG=$(gh_latest_tag Gu1llaum-3/sshm)
  [ -n "$SSHM_TAG" ] || { fmt_error "Failed to resolve sshm version"; exit 1; }
  curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o /tmp/sshm.tar.gz \
    "https://github.com/Gu1llaum-3/sshm/releases/download/${SSHM_TAG}/sshm_Linux_${SSHM_ARCH}.tar.gz" \
    || { fmt_error "Failed to download sshm"; exit 1; }
  $SUDO tar -C /usr/local/bin -xzf /tmp/sshm.tar.gz sshm
  rm -f /tmp/sshm.tar.gz
fi

# Install Alacritty (GUI only)
if has_gui && ! command -v alacritty >/dev/null 2>&1; then
  $SUDO apt-get install -y software-properties-common
  $SUDO add-apt-repository -y ppa:aslatter/ppa
  $SUDO apt-get update -qq && $SUDO apt-get install -y alacritty
fi

# Install Oh My Zsh framework
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] || \
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || \
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# Configure Neovim
if [ ! -d "$HOME/.config/nvim" ]; then
  git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"
fi
cp -r "$DOTFILES/nvim/." "$HOME/.config/nvim/"

# Symlinks
ln -s -f "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"

mkdir -p "$HOME/.config/zellij"
ln -s -f "$DOTFILES/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"

if has_gui; then
  mkdir -p "$HOME/.config/alacritty"
  ln -s -f "$DOTFILES/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
fi

# SSH — hardened client config via native Include, with strict permissions (CIS)
mkdir -p "$HOME/.ssh/cm" "$HOME/.ssh/config.d"
chmod 700 "$HOME/.ssh" "$HOME/.ssh/cm" "$HOME/.ssh/config.d"
chmod 600 "$DOTFILES/ssh/config" "$DOTFILES/ssh/hardening.conf"
ln -s -f "$DOTFILES/ssh/hardening.conf" "$HOME/.ssh/hardening.conf"

# Hosts stay out of the repo; seed an example if config.d is empty
if [ -z "$(ls -A "$HOME/.ssh/config.d" 2>/dev/null)" ]; then
  cp "$DOTFILES/ssh/config.d/00-example.conf" "$HOME/.ssh/config.d/00-example.conf"
fi
chmod 600 "$HOME"/.ssh/config.d/*.conf 2>/dev/null || true

# Entry config (Include directives): back up a foreign config, then symlink
if [ -e "$HOME/.ssh/config" ] && [ ! -L "$HOME/.ssh/config" ]; then
  cp "$HOME/.ssh/config" "$HOME/.ssh/config.pre-dotfiles.bak"
fi
ln -s -f "$DOTFILES/ssh/config" "$HOME/.ssh/config"

# Tighten permissions on existing private keys
find "$HOME/.ssh" -maxdepth 1 -type f -name 'id_*' ! -name '*.pub' -exec chmod 600 {} \; 2>/dev/null || true

# Set as default shell
if [ "$(basename "$SHELL")" != "zsh" ]; then
  chsh -s "$(command -v zsh)"
fi
