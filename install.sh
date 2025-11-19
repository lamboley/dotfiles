#!/bin/bash

if [ $(id -u) = 0 ]; then
    ./dependency.sh
fi

sudo -p "Root password to install dependencies: " apt update -y && apt install -y neovim fish kitty curl

mkdir -p "${HOME}/.config/fish"
rm -f "${HOME}/.config/fish/config.fish"
ln -s -f "${HOME}/.dotfiles/.config/fish/config.fish" "${HOME}/.config/fish/config.fish"

fish_update_completions

mkdir -p "${HOME}/.config/kitty"
rm -f "${HOME}/.config/kitty/kitty.conf"
ln -s -f "${HOME}/.dotfiles/.config/kitty/kitty.conf" "${HOME}/.config/kitty/kitty.conf"

mv ~/.config/nvim{,.bak} 2>/dev/null
git clone https://github.com/LazyVim/starter ~/.config/nvim 2>/dev/null
rm -rf ~/.config/nvim/.git
