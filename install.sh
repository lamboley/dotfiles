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

# Preflight checks
if ! command -v sudo >/dev/null 2>&1; then
  fmt_error "sudo is required to run this script"
  exit 1
fi

# Get the repo
if [ -d "$DOTFILES" ]; then
  git -C "$DOTFILES" pull --rebase origin master
else
  git clone --depth=1 "$REPO" "$DOTFILES" || { fmt_error "Failed to clone dotfiles"; exit 1; }
fi

# Update and install packages
sudo apt-get update -y && sudo apt-get upgrade -y && sudo apt-get autoremove -y
sudo apt-get install -y curl git zsh unzip ripgrep fd-find fzf eza keychain

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

# Install Neovim (nvim uses: x86_64 / arm64)
case "$ARCH" in
  x86_64)  NVIM_ARCH="x86_64" ;;
  aarch64) NVIM_ARCH="arm64" ;;
esac
curl -LO "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" \
  || { fmt_error "Failed to download neovim"; exit 1; }
sudo rm -rf "/opt/nvim-linux-${NVIM_ARCH}"
sudo tar -C /opt -xzf "nvim-linux-${NVIM_ARCH}.tar.gz" && rm -f "nvim-linux-${NVIM_ARCH}.tar.gz"
sudo ln -sf "/opt/nvim-linux-${NVIM_ARCH}/bin/nvim" /usr/local/bin/nvim

# Install lazygit (lazygit uses: x86_64 / arm64)
if ! command -v lazygit >/dev/null 2>&1; then
  case "$ARCH" in
    x86_64)  LG_ARCH="x86_64" ;;
    aarch64) LG_ARCH="arm64" ;;
  esac
  LAZYGIT_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
  curl -fsSL -o /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_${LG_ARCH}.tar.gz"
  sudo tar -C /usr/local/bin -xzf /tmp/lazygit.tar.gz lazygit
  rm -f /tmp/lazygit.tar.gz
fi

# Install zellij (zellij uses: x86_64 / aarch64)
if ! command -v zellij >/dev/null 2>&1; then
  case "$ARCH" in
    x86_64)  ZJ_ARCH="x86_64" ;;
    aarch64) ZJ_ARCH="aarch64" ;;
  esac
  curl -fsSL -o /tmp/zellij.tar.gz "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${ZJ_ARCH}-unknown-linux-musl.tar.gz"
  sudo tar -C /usr/local/bin -xzf /tmp/zellij.tar.gz zellij
  rm -f /tmp/zellij.tar.gz
fi

# Install sshm (interactive SSH host manager with tags)
# Naming differs from other projects: asset is sshm-linux-{amd64,arm64} and the
# extracted binary keeps that same name, so it must be renamed to sshm.
if ! command -v sshm >/dev/null 2>&1; then
  case "$ARCH" in
    x86_64)  SSHM_ARCH="amd64" ;;
    aarch64) SSHM_ARCH="arm64" ;;
  esac
  curl -fsSL -o /tmp/sshm.tar.gz "https://github.com/Gu1llaum-3/sshm/releases/latest/download/sshm-linux-${SSHM_ARCH}.tar.gz"
  sudo tar -C /usr/local/bin -xzf /tmp/sshm.tar.gz "sshm-linux-${SSHM_ARCH}"
  sudo mv "/usr/local/bin/sshm-linux-${SSHM_ARCH}" /usr/local/bin/sshm
  rm -f /tmp/sshm.tar.gz
fi

# Install Alacritty (GUI only)
if has_gui && ! command -v alacritty >/dev/null 2>&1; then
  sudo apt-get install -y software-properties-common
  sudo add-apt-repository -y ppa:aslatter/ppa
  sudo apt-get update -qq && sudo apt-get install -y alacritty
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
