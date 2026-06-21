# Update and upgrade system packages
update-packages() {
  if [ -n "$PREFIX" ] && [[ "$PREFIX" == *com.termux* ]]; then
    pkg update -y && pkg upgrade -y && apt clean -y && apt autoremove -y
  elif command -v apt >/dev/null 2>&1; then
    sudo apt update -y && sudo apt upgrade -y && sudo apt clean -y && sudo apt autoremove -y
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf -y upgrade && sudo dnf -y autoremove
  else
    echo "update-packages: no supported package manager found" >&2
    return 1
  fi
}

# Pull dotfiles from repository
update-dotfiles() {
  git -C "$HOME/.dotfiles" pull --rebase origin master
}

# Force keychain to load my ssh key
keychain-add() {
  eval "$(keychain --eval --agents ssh id_ed25519)"
}
