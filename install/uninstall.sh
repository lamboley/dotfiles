#!/usr/bin/env bash
#
# uninstall.sh - retire UNIQUEMENT les versions apt/pkg des outils désormais
# fournis en user-local par install.sh (pour éviter les doublons).
# Ne touche à RIEN d'autre : ni ~/.local, ni les configs, ni ~/.ssh.

set -euo pipefail

# Outils fournis en user-local et susceptibles d'exister en paquet système.
PACKAGES=(fish fzf eza zoxide keychain zsh starship)

confirm() {
  [[ ! -t 1 || ! -e /dev/tty ]] && return 0
  local ans
  printf '%s [y/N] ' "$1"
  read -r ans < /dev/tty || return 1
  [[ "$ans" =~ ^[Yy] ]]
}

# Vrai si $1 est le shell de connexion en cours : anti-lockout, on ne purge
# jamais le shell sous lequel on tourne (sinon plus de terminal).
shell_in_use() {
  [[ "$1" == "$(basename "${SHELL:-}")" ]] && return 0
  if command -v getent >/dev/null 2>&1; then
    local login_sh
    login_sh="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)"
    [[ "$1" == "$(basename "$login_sh")" ]] && return 0
  fi
  return 1
}

main() {
  echo "Retire UNIQUEMENT les versions apt/pkg de : ${PACKAGES[*]}"
  echo "Rien d'autre n'est touché (~/.local, configs et ~/.ssh conservés)."
  confirm "Continuer ?" || { echo "Annulé."; exit 0; }

  local pkg installed=()

  if command -v apt-get >/dev/null 2>&1; then
    # apt purge nécessite root (on retire des paquets installés en root).
    local sudo=""
    if [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
      sudo="sudo"
    fi
    for pkg in "${PACKAGES[@]}"; do
      if shell_in_use "$pkg"; then
        echo "  (conservé : $pkg est ton shell de connexion)"
        continue
      fi
      dpkg -s "$pkg" >/dev/null 2>&1 && installed+=("$pkg")
    done
    if [[ ${#installed[@]} -eq 0 ]]; then
      echo "Aucun paquet apt à retirer."
    else
      echo "apt purge : ${installed[*]}"
      $sudo apt-get purge -y "${installed[@]}"
    fi
  elif command -v pkg >/dev/null 2>&1; then
    # Termux : pas de sudo.
    for pkg in "${PACKAGES[@]}"; do
      if shell_in_use "$pkg"; then
        echo "  (conservé : $pkg est ton shell de connexion)"
        continue
      fi
      command -v "$pkg" >/dev/null 2>&1 && installed+=("$pkg")
    done
    if [[ ${#installed[@]} -eq 0 ]]; then
      echo "Aucun paquet pkg à retirer."
    else
      echo "pkg uninstall : ${installed[*]}"
      pkg uninstall -y "${installed[@]}"
    fi
  else
    echo "Ni apt ni pkg détecté — rien à faire."
  fi
}

main "$@"
