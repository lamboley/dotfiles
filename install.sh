#!/bin/bash

function log_info() {
    echo -e "\033[0;103m[INFO]\033[0m $*"
}

log_info "Installs packages neovim, fish and curl."
sudo apt update -y && sudo apt install -y neovim fish curl

command_kitty=$(command -v kitty)
if [ ! "$command_kitty" ]; then
    log_info "... Installing kitty"
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
else
    log_info "--- Kitty already installed."
fi

command_starship=$(command -v starship)
if [ ! "$command_starship" ]; then
    log_info "... Installing starship"
    curl -sS https://starship.rs/install.sh | sh
else
    log_info "--- starship already installed."
fi

log_info "... Configuring fish"

mkdir -p "${HOME}/.config/fish"
rm -f "${HOME}/.config/fish/config.fish"

ln -s -f "${HOME}/.dotfiles/.config/fish/main.fish" "${HOME}/.config/fish/main.fish"
ln -s -f "${HOME}/.dotfiles/.config/fish/aliases.fish" "${HOME}/.config/fish/aliases.fish"
ln -s -f "${HOME}/.dotfiles/.config/fish/config.fish" "${HOME}/.config/fish/config.fish"

log_info "... Configuring kitty"

mkdir -p "${HOME}/.config/kitty"
rm -f "${HOME}/.config/kitty/kitty.conf"
ln -s -f "${HOME}/.dotfiles/.config/kitty/kitty.conf" "${HOME}/.config/kitty/kitty.conf"

log_info "... Configuring neovim"

rm -Rf "${HOME}/.config/nvim"
git clone https://github.com/LazyVim/starter "${HOME}/.config/nvim"
rm -Rf ~/.config/nvim/.git
