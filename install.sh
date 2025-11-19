#!/usr/bin/env bash

if ! tmux -V >/dev/null 2>&1; then
    echo "tmux is not installed"
fi

if ! fish --version >/dev/null 2>&1; then
    echo "fish is not installed"
fi

rm -f "${HOME}/.bash_aliases"
ln -s -f "${HOME}/.dotfiles/aliases" "${HOME}/.bash_aliases"

rm -f "${HOME}/.tmux.conf"
ln -s -f "${HOME}/.dotfiles/tmux.conf" "${HOME}/.tmux.conf"

mkdir -p "${HOME}/.config/fish"
rm -f "${HOME}/.config/fish/config.fish"
ln -s -f "${HOME}/.dotfiles/fish/config.fish" "${HOME}/.config/fish/config.fish"

mv ~/.config/nvim{,.bak}
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git
