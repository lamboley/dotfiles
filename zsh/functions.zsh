update-packages() {
  sudo apt update -y && sudo apt upgrade -y && sudo apt clean -y && sudo apt autoremove -y
}

update-dotfiles() {
  sh "$HOME/.dotfiles/tools/install.sh"
}
