#!/bin/bash

sudo apt update -y && sudo apt install -y neovim fish curl

if [ ! command -v kitty >/dev/null 2>&1 ]; then
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
fi

if [ ! command -v starship >/dev/null 2>&1 ]; then
    curl -sS https://starship.rs/install.sh | sh
fi

mkdir -p "${HOME}/.config/fish"
rm -f "${HOME}/.config/fish/config.fish"

ln -s -f "${HOME}/.dotfiles/.config/fish/main.fish" "${HOME}/.config/fish/main.fish"
ln -s -f "${HOME}/.dotfiles/.config/fish/aliases.fish" "${HOME}/.config/fish/aliases.fish"
ln -s -f "${HOME}/.dotfiles/.config/fish/config.fish" "${HOME}/.config/fish/config.fish"

mkdir -p "${HOME}/.config/kitty"
rm -f "${HOME}/.config/kitty/kitty.conf"
ln -s -f "${HOME}/.dotfiles/.config/kitty/kitty.conf" "${HOME}/.config/kitty/kitty.conf"

rm -Rf ${HOME}/.config/nvim
git clone https://github.com/LazyVim/starter ${HOME}/.config/nvim
rm -rf ~/.config/nvim/.git
