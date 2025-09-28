#!/bin/sh

if [ -f "${HOME}/.profile" ]; then
    cat ./aliases >> "${HOME}/.profile"
fi