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

# Install Neovim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz \
  || { fmt_error "Failed to download neovim"; exit 1; }
sudo rm -rf /opt/nvim-linux-x86_64
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz && rm -f nvim-linux-x86_64.tar.gz
sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim

# Install lazygit
if ! command -v lazygit >/dev/null 2>&1; then
  LAZYGIT_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
  curl -fsSL -o /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  sudo tar -C /usr/local/bin -xzf /tmp/lazygit.tar.gz lazygit
  rm -f /tmp/lazygit.tar.gz
fi

# Install zellij
if ! command -v zellij >/dev/null 2>&1; then
  curl -fsSL -o /tmp/zellij.tar.gz "https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz"
  sudo tar -C /usr/local/bin -xzf /tmp/zellij.tar.gz zellij
  rm -f /tmp/zellij.tar.gz
fi

# Install sshm (interactive SSH host manager with tags)
if ! command -v sshm >/dev/null 2>&1; then
  curl -fsSL -o /tmp/sshm.tar.gz "https://github.com/Gu1llaum-3/sshm/releases/latest/download/sshm_Linux_x86_64.tar.gz"
  sudo tar -C /usr/local/bin -xzf /tmp/sshm.tar.gz sshm
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
