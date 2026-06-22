# Update and upgrade system packages
update-packages() {
  if [ -n "$PREFIX" ] && [[ "$PREFIX" == *com.termux* ]]; then
    pkg update -y && pkg upgrade -y && apt clean -y && apt autoremove -y
  elif command -v apt >/dev/null 2>&1; then
    sudo apt update -y && sudo apt upgrade -y && sudo apt clean -y && sudo apt autoremove -y
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf -y upgrade && sudo dnf -y autoremove
  fi
}

# Add an SSH key to the keychain agent, or list available keys with -l
keychain-add() {
  # List SSH key in ~/.ssh/
  if [[ "$1" == "-l" ]]; then
    find "$HOME/.ssh" -type f -name "*.pub" | while read -r public; do
      private="${public%.pub}"
      echo "${private##*/}"
    done

    return
  fi

  # load a SSH Key in persistent agent
  eval "$(keychain --eval --agents ssh "${1:-id_ed25519}")"
}

