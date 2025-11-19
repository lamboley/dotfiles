#!/bin/bash

rm -f "${HOME}/.bash_aliases"
ln -s -f "${HOME}/.dotfiles/aliases" "${HOME}/.bash_aliases"

mkdir -p "${HOME}/.tmux/plugins"
git clone git@github.com:o0th/tmux-nova.git ${HOME}/.tmux/plugins/tmux-nova

rm -f "${HOME}/.tmux.conf"
ln -s -f "${HOME}/.dotfiles/tmux.conf" "${HOME}/.tmux.conf"

mkdir -p "${HOME}/.config/fish"
rm -f "${HOME}/.config/fish/config.fish"
ln -s -f "${HOME}/.dotfiles/fish/config.fish" "${HOME}/.config/fish/config.fish"

mkdir -p "${HOME}/.config/kitty"
rm -f "${HOME}/.config/kitty/kitty.conf"
ln -s -f "${HOME}/.dotfiles/kitty/kitty.conf" "${HOME}/.config/kitty/kitty.conf"

mv ~/.config/nvim{,.bak}
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git
