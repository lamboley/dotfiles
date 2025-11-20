#!/bin/bash

set -e

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

function log_info() {
    now=$(date +'%Y/%m/%d %H:%M:%S')
    echo >&2 -e "${now} [\033[4;32mINFO\033[0m] $*"
}

log_info "Update apt cache..."
sudo apt update -y

log_info "Install curl..."
sudo apt install -y curl

log_info "Install neovim..."
sudo apt install -y neovim

log_info "Install neovim..."
sudo apt install -y fish

log_info "Install kitty..."
sudo apt install -y kitty

log_info "Install or update starship..."
curl -sS https://starship.rs/install.sh | sh

log_info "Configure fish"

rm -Rf "${HOME}/.config/fish"

mkdir -p "${HOME}/.config/fish"
mkdir -p "${HOME}/.config/fish/functions"

ln -s -f "${script_dir}/.config/fish/main.fish" "${HOME}/.config/fish/main.fish"
ln -s -f "${script_dir}/.config/fish/aliases.fish" "${HOME}/.config/fish/aliases.fish"
ln -s -f "${script_dir}/.config/fish/config.fish" "${HOME}/.config/fish/config.fish"
ln -s -f "${script_dir}/.config/fish/functions/update-dotfiles.fish" "${HOME}/.config/fish/functions/update-dotfiles.fish"
ln -s -f "${script_dir}/.config/fish/functions/update-packages.fish" "${HOME}/.config/fish/functions/update-packages.fish"

log_info "Configure kitty"

rm -Rf "${HOME}/.config/kitty/"
rm -f "${HOME}/.local/share/applications/kitty.desktop"

mkdir -p "${HOME}/.config/kitty"
mkdir -p "${HOME}/.local/share/applications"

ln -s -f "${script_dir}/.config/kitty/kitty.conf" "${HOME}/.config/kitty/kitty.conf"
ln -s -f "${script_dir}/.config/kitty/current-theme.conf" "${HOME}/.config/kitty/current-theme.conf"
ln -s -f "${script_dir}/.local/share/applications/kitty.desktop" "${HOME}/.local/share/applications/kitty.desktop"

log_info "Configure neovim"

rm -Rf "${HOME}/.config/nvim"
git clone https://github.com/LazyVim/starter "${HOME}/.config/nvim"
rm -Rf "${HOME}/.config/nvim/.git"
