#!/bin/bash

apt update -y
apt upgrade -y
apt install -y neovim fish tmux
curl -sS https://starship.rs/install.sh | sh
