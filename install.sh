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
sudo apt-get install -y curl git zsh unzip

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

# Install WezTerm (GUI only)
if has_gui && ! command -v wezterm >/dev/null 2>&1; then
  curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm.gpg
  echo "deb [signed-by=/usr/share/keyrings/wezterm.gpg] https://apt.fury.io/wez/ * *" \
    | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
  sudo apt-get update -qq && sudo apt-get install -y wezterm
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

# Symlinks
ln -s -f "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
if has_gui; then
  ln -s -f "$DOTFILES/wezterm/.wezterm.lua" "$HOME/.wezterm.lua"
fi

# Set as default shell
if [ "$(basename "$SHELL")" != "zsh" ]; then
  chsh -s "$(command -v zsh)"
fi
