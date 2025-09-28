#!/bin/sh

if [ -f "${HOME}/.bash_aliases" ]; then
    cat ./aliases >> "${HOME}/.bash_aliases"
else
    cat ./aliases > "${HOME}/.bash_aliases"
fi