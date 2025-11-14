#!/usr/bin/env bash

if [ -f "${HOME}/.bash_aliases" ]; then
    cat ./aliases >> "${HOME}/.bash_aliases"
else
    cat ./aliases > "${HOME}/.bash_aliases"
fi

if [ -f "${HOME}/.config/fish/config.fish" ]; then
    cat ./config.fish >> "${HOME}/.config/fish/config.fish"
else
    mkdir -p ${HOME}/.config/fish/
    cat ./config.fish > "${HOME}/.config/fish/config.fish"
fi

if [ -f "${HOME}/.tmux.conf" ]; then
    cat ./tmux.conf >> "${HOME}/.tmux.conf"
else
    cat ./tmux.conf > "${HOME}/.tmux.conf"
fi

if [ -f "${HOME}/.vimrc" ]; then
    cat ./vimrc >> "${HOME}/.vimrc"
else
    cat ./vimrc > "${HOME}/.vimrc"
fi
