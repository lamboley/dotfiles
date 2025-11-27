# Author: Lucas Lamboley

bind \cu update-dotfiles
bind \cy update-packages

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

fish_add_path -g "$HOME/.local/bin"