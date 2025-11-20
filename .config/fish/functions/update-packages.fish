function update-packages --description 'Update and upgrade apt packages'
    sudo apt install -y && sudo apt upgrade -y && sudo apt clean -y && sudo apt autoremove -y
end
