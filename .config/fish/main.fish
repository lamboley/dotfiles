# Author: Lucas Lamboley

function fish_user_key_bindings
    bind \cu update-dotfiles
end

function update-dotfiles --description "Updates my .dotfiles"
    cd ~/.dotfiles && git pull && bash ./install.sh
end

function update-packages --description "Update and upgrade apt packages"
    sudo apt install -y && sudo apt upgrade -y && sudo apt clean && sudo apt autoremove
end

function lucas-dtag --description "Delete a tag from git"
    if [[ "$#" -le 1 ]]; then
        log_error "Missing arguments"
        log_error "Usage: $0 <tag to delete>"
        exit 1
    fi

	# git tag --delete $(CURRENTTAG)
	# git push --delete origin $(CURRENTTAG)
end

set -U fish_greeting

set -gx EDITOR nvim