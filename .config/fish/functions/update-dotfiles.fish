function update-dotfiles --description 'Updates my .dotfiles'
    cd ~/.dotfiles && git pull && bash ./install.sh
end
