# Author: Lucas Lamboley

function fish_user_key_bindings
    bind \cu update-dotfiles
end

function update-dotfiles --description "Updates my .dotfiles"
    cd ~/.dotfiles && git pull && bash ./install.sh
end

function update-packages --description "Update and upgrade packages"
    sudo apt install -y && sudo apt upgrade -y && sudo apt clean && sudo apt autoremove
end

set -U fish_greeting

set -gx EDITOR nvim