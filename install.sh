#!/usr/bin/env bash

if ! tmux -V >/dev/null 2>&1; then
    echo "tmux is not installed"
fi

if ! fish --version >/dev/null 2>&1; then
    echo "fish is not installed"
fi

cd "$(dirname "$0")"

install() {
    if [ -f "${HOME}/.bash_aliases" ]; then
        if [ -L "${HOME}/.bash_aliases" ]; then
            rm -f "${HOME}/.bash_aliases"
        fi
    fi
    ln -s -f "${HOME}/.dotfiles/aliases" "${HOME}/.bash_aliases"

    if [ -f "${HOME}/.tmux.conf" ]; then
        if [ -L "${HOME}/.tmux.conf" ]; then
            rm -f "${HOME}/.tmux.conf"
        fi
    fi
    ln -s -f "${HOME}/.dotfiles/tmux.conf" "${HOME}/.tmux.conf"

    if [ -f "${HOME}/.config/fish/config.fish" ]; then
        if [ -L "${HOME}/.config/fish/config.fish" ]; then
            rm -f "${HOME}/.config/fish/config.fish"
        fi
    fi
    ln -s -f "${HOME}/.dotfiles/fish/config.fish" "${HOME}/.config/fish/config.fish"

    if [ -f "${HOME}/.config/fish/functions/fish_greeting.fish" ]; then
        if [ -L "${HOME}/.config/fish/functions/fish_greeting.fish" ]; then
            rm -f "${HOME}/.config/fish/functions/fish_greeting.fish"
        fi
    fi
    ln -s -f "${HOME}/.dotfiles/fish/functions/fish_greeting.fish" "${HOME}/.config/fish/functions/fish_greeting.fish"
}

install