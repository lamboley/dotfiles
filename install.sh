#!/bin/bash

function log_info() {
    current_time=$(date "+%Y/%m/%d %H:%M:%S")
    echo -e "${current_time} [\033[4;32mINFO\033[0m] $*"
}

log_info "Install neovim, fish, curl and kitty"
sudo apt update -y && sudo apt install -y neovim fish curl kitty

command_starship=$(command -v starship)
if [ ! "$command_starship" ]; then
    log_info "Install starship.rs"
    curl -sS https://starship.rs/install.sh | sh
else
    log_info "Starship is already installed"
fi

log_info "Configure fish"

rm -Rf "${HOME}/.config/fish"

mkdir -p "${HOME}/.config/fish"
mkdir -p "${HOME}/.config/fish/functions"

ln -s -f "${HOME}/.dotfiles/.config/fish/main.fish" "${HOME}/.config/fish/main.fish"
ln -s -f "${HOME}/.dotfiles/.config/fish/aliases.fish" "${HOME}/.config/fish/aliases.fish"
ln -s -f "${HOME}/.dotfiles/.config/fish/config.fish" "${HOME}/.config/fish/config.fish"
ln -s -f "${HOME}/.dotfiles/.config/fish/functions/update-dotfiles.fish" "${HOME}/.config/fish/functions/update-dotfiles.fish"
ln -s -f "${HOME}/.dotfiles/.config/fish/functions/update-packages.fish" "${HOME}/.config/fish/functions/update-packages.fish"

log_info "Configure kitty"

rm -Rf "${HOME}/.config/kitty/"
rm -f "${HOME}/.local/share/applications/kitty.desktop"

mkdir -p "${HOME}/.config/kitty"
mkdir -p "${HOME}/.local/share/applications"

ln -s -f "${HOME}/.dotfiles/.config/kitty/kitty.conf" "${HOME}/.config/kitty/kitty.conf"
ln -s -f "${HOME}/.dotfiles/.config/kitty/current-theme.conf" "${HOME}/.config/kitty/current-theme.conf"
ln -s -f "${HOME}/.dotfiles/.local/share/applications/kitty.desktop" "${HOME}/.local/share/applications/kitty.desktop"

log_info "Configure neovim"

rm -Rf "${HOME}/.config/nvim"
git clone https://github.com/LazyVim/starter "${HOME}/.config/nvim"
rm -Rf "${HOME}/.config/nvim/.git"
