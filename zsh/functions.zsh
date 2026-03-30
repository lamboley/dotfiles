update-packages() {
  sudo apt update -y && sudo apt upgrade -y && sudo apt clean -y && sudo apt autoremove -y
}

update-dotfiles() {
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/lamboley/dotfiles/master/install.sh)"
}
