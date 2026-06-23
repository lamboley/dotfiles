#!/usr/bin/env bash
#
# uninstall.sh - retire les outils installés en user-local par install.sh.
# Conserve : le dépôt ~/.dotfiles, les configs liées, ~/.ssh, les *.pre-dotfiles.bak.

set -euo pipefail

# ==========================================================
# Utilitaires
# ==========================================================

IS_TERMUX=0
[[ -n "${TERMUX_VERSION:-}" ]] && IS_TERMUX=1

# Demande confirmation via /dev/tty. Pas de tty -> on continue.
confirm() {
  [[ ! -t 1 || ! -e /dev/tty ]] && return 0
  local ans
  printf '%s [y/N] ' "$1"
  read -r ans < /dev/tty || return 1
  [[ "$ans" =~ ^[Yy] ]]
}

# rm -rf chaque chemin existant, en l'affichant.
rm_path() {
  local p
  for p in "$@"; do
    if [[ -e "$p" || -L "$p" ]]; then
      rm -rf "$p" && echo "  - $p"
    fi
  done
}

# Retire un dossier seulement s'il est vide.
rmdir_empty() {
  [[ -d "$1" ]] || return 0
  rmdir "$1" 2>/dev/null || true
}

# ==========================================================
# Désinstallation
# ==========================================================

main() {
  echo "Retire les outils user-local posés par install.sh."
  echo "Conservés : ~/.dotfiles, configs liées, ~/.ssh, sauvegardes .bak."
  confirm "Continuer ?" || { echo "Annulé."; exit 0; }

  # Sécurité : si fish est le shell de connexion, repasser sur bash avant de
  # le supprimer (sinon la prochaine connexion échoue).
  if [[ "$(basename "${SHELL:-}")" == "fish" ]] && command -v bash >/dev/null 2>&1; then
    chsh -s "$(command -v bash)" 2>/dev/null || true
    echo "Shell par défaut remis sur bash."
  fi

  echo "Binaires (~/.local/bin) :"
  local b
  for b in hx fish fzf eza zoxide keychain zellij sshm starship nvim bash-language-server; do
    rm_path "$HOME/.local/bin/$b"
  done

  echo "Données éditeurs :"
  rm_path "$HOME/.local/lib/nvim" "$HOME/.local/share/nvim" \
          "$HOME/.local/share/man/man1/nvim.1" "$HOME/.config/helix/runtime"

  echo "Go (chaîne + binaires go install) :"
  rm_path "$HOME/.local/go"
  for b in gopls ghq sshm; do
    rm_path "$HOME/go/bin/$b"
  done
  rmdir_empty "$HOME/go/bin"
  rmdir_empty "$HOME/go"

  echo "bash-language-server (npm) :"
  rm_path "$HOME/.local/lib/node_modules/bash-language-server"

  echo "Plugins zsh :"
  rm_path "$HOME/.zsh/plugins"
  rmdir_empty "$HOME/.zsh"

  echo "fisher / plugins fish :"
  rm_path "$HOME/.local/share/fisher" \
          "$HOME/.config/fish/completions" "$HOME/.config/fish/conf.d"
  # Nos fonctions fish sont des liens ; les plugins sont de vrais fichiers.
  if [[ -d "$HOME/.config/fish/functions" ]]; then
    find "$HOME/.config/fish/functions" -maxdepth 1 -type f -delete || true
  fi

  echo "Polices Nerd Font :"
  rm_path "$HOME"/.local/share/fonts/FiraCode*.ttf
  if [[ "$IS_TERMUX" -eq 1 ]]; then
    rm_path "$HOME/.termux/font.ttf"
  fi

  echo "Terminé. Relance install.sh pour réinstaller."
}

main "$@"
