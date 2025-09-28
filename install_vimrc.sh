#!/bin/sh

if [ ! -f "${HOME}/.vimrc" ]; then
    cat ./vimrc > "${HOME}/.vimrc"
fi