# Author: Lucas Lamboley

function fish_user_key_bindings
    bind \cu update-dotfiles
end

function update-dotfiles --description "Updates my .dotfiles"
    cd ~/.dotfiles && git pull && bash ./install.sh
end

# Disable fish welcome message
set -U fish_greeting