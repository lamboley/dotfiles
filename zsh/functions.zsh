#!/usr/bin/env zsh
#
# functions.zsh - fonctions interactives, sourcé depuis .zshrc.

# Met à jour les paquets système.
function update-packages() {
  emulate -L zsh

  if [[ -n "${PREFIX:-}" && "${PREFIX}" == *com.termux* ]]; then
    pkg update -y && pkg upgrade -y && apt clean -y && apt autoremove -y
  elif (( $+commands[apt] )); then
    sudo apt update -y && sudo apt upgrade -y && sudo apt clean -y && sudo apt autoremove -y
  fi
}

# Ajoute une clé SSH dans l'agent via keychain.
#
# Usage:
#   keychain-add [-l] [<clé>]
#
# Options:
#     <clé> Nom de la clé à charger (défaut: id_ed25519).
#     -l    Liste les clés SSH disponibles dans $HOME/.ssh.
function keychain-add() {
  emulate -L zsh

  if [[ "${1:-}" == "-l" ]]; then
    local pubkey
    for pubkey in "${HOME}"/.ssh/*.pub(N); do
      print -r -- "${${pubkey:t}%.pub}"
    done
    return
  fi

  eval "$(keychain --eval --agents ssh "${1:-id_ed25519}")"
}
