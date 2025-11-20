# Author: Lucas Lamboley

function fish_user_key_bindings
    bind \cu update-dotfiles
end

function update-dotfiles --description "Updates my .dotfiles"
    cd ~/.dotfiles && git pull && bash ./install.sh
end

function update-packages --description "Update and upgrade apt packages"
    sudo apt install -y && sudo apt upgrade -y && sudo apt clean -y && sudo apt autoremove -y
end

function lucas-ctag --description "Create a tag from git"
    if [ -z "$argv" ];
        echo "Missing arguments"
        echo "Usage: $0 <tag to create>"
        return
    else
        git tag $argv[1] && git push --tags
    end
end

function lucas-dtag --description "Delete a tag from git"
    if [ -z "$argv" ];
        echo "Missing arguments"
        echo "Usage: $0 <tag to delete>"
        return
    else
        git tag --delete $argv[1]
        git push --delete origin $argv[1]
    end
end

set -U fish_greeting

set -gx EDITOR nvim