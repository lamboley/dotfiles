#!/bin/bash

if ! [ $(id -u) = 0 ]; then
    echo "script must be run as root"
    exit 1
fi

apt update -y && apt upgrade -y
apt install -y neovim fish kitty curl

curl -sS https://starship.rs/install.sh | sh
