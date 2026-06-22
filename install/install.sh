#!/usr/bin/env bash
#
# Lancer via curl :
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/lamboley/dotfiles/master/install/install.sh)"

set -euo pipefail

# ==========================================================
# Variables globales
# ==========================================================

DOTFILES="$HOME/.dotfiles"
REPO="https://github.com/lamboley/dotfiles.git"

IS_TERMUX=0
ARCH=""          # uname -m brut : x86_64 / aarch64       (helix, zellij)
ARCH_ARM64=""    # x86_64 -> x86_64 ; aarch64 -> arm64    (sshm)
ARCH_GO=""       # x86_64 -> amd64  ; aarch64 -> arm64    (chaîne Go)
SUDO=""
TMP_FILES=()     # fichiers mktemp à supprimer en sortie (safe Ctrl-C)

cleanup() {
  rm -rf /tmp/helix-extract /tmp/FiraCode.zip \
    "${TMP_FILES[@]}" 2>/dev/null || true
}
trap cleanup EXIT

# ==========================================================
# Utilitaires
# ==========================================================

check_cmd() { command -v "$1" >/dev/null 2>&1; }

need_cmd() {
  if ! check_cmd "$1"; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

# Lance une commande ; abandonne en cas d'échec.
ensure() {
  if ! "$@"; then
    echo "command failed: $*" >&2
    exit 1
  fi
}

has_gui() { [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; }

# Prompt oui/non via /dev/tty (survit à `curl | bash`). Pas de tty -> oui.
ask() {
  [[ ! -t 1 || ! -e /dev/tty ]] && return 0
  local ans
  printf '%s [Y/n] ' "$1"
  read -r ans < /dev/tty || return 0
  [[ "$ans" =~ ^[Nn] ]] && return 1
  return 0
}

# Vrai si au moins une des commandes manque.
any_missing() {
  local c
  for c in "$@"; do check_cmd "$c" || return 0; done
  return 1
}

# Un outil + sa config : présent -> redéploie la config ; absent -> installe puis déploie.
# $1 = commande ; $2 = prompt ("-" = sans demander) ; $3 = fn déploiement ("-" = aucune) ; $4... = commande d'install
brick() {
  local cmd="$1" prompt="$2" deploy_fn="$3"; shift 3
  if ! check_cmd "$cmd"; then
    [[ "$prompt" == "-" ]] || ask "$prompt" || return 0
    "$@" || true
  fi
  if check_cmd "$cmd" && [[ "$deploy_fn" != "-" ]]; then
    "$deploy_fn"
  fi
  return 0
}

# Dernier tag de release sans l'API GitHub (pas de rate-limit).
gh_latest_tag() {
  curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/$1/releases/latest" 2>/dev/null | sed -n 's#.*/tag/##p'
}

# Dernier tag ou échec explicite. $1 = owner/repo ; $2 = nom de l'outil. Affiche le tag.
need_tag() {
  local tag; tag="$(gh_latest_tag "$1")"
  [[ -n "$tag" ]] || { echo "Failed to resolve $2 version" >&2; return 1; }
  echo "$tag"
}

# Sauvegarde un vrai fichier (pas un lien) avant de le remplacer par un lien.
backup_if_real() {
  if [[ -e "$1" && ! -L "$1" ]]; then
    mv "$1" "$1.pre-dotfiles.bak"
  fi
}

# Télécharge un binaire GitHub, puis lance $2 pour l'extraire/installer.
# $1 = URL ; $2 = callback d'extraction (reçoit le chemin du fichier temp).
fetch_and_install() {
  local url="$1" extract_fn="$2"
  local tmp; tmp="$(mktemp)"
  TMP_FILES+=("$tmp")
  if ! curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o "$tmp" "$url"; then
    rm -f "$tmp"; return 1
  fi
  "$extract_fn" "$tmp" || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"
}

# Callbacks d'extraction : installent dans ~/.local/bin, retour non-nul si échec.
# extract_single_bin : un binaire depuis un .tar.gz, nommé par $EXTRACT_BIN.
extract_single_bin() {
  mkdir -p "$HOME/.local/bin"
  tar -C "$HOME/.local/bin" -xzf "$1" "$EXTRACT_BIN"
}

extract_helix() {
  # helix a besoin de hx + son dossier runtime ensemble.
  local dir="/tmp/helix-extract"
  rm -rf "$dir"; mkdir -p "$dir"
  tar -C "$dir" -xJf "$1" || return 1
  local hxdir="$dir/helix-${HELIX_TAG}-${ARCH}-linux"
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$hxdir/hx" "$HOME/.local/bin/hx" || return 1
  mkdir -p "$HOME/.config/helix"
  rm -rf "$HOME/.config/helix/runtime"
  cp -r "$hxdir/runtime" "$HOME/.config/helix/runtime"
  rm -rf "$dir"
}

# ==========================================================
# Détection / preflight
# ==========================================================

detect_env() {
  [[ -n "${TERMUX_VERSION:-}" ]] && IS_TERMUX=1

  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  ARCH_ARM64="x86_64"; ARCH_GO="amd64" ;;
    aarch64) ARCH_ARM64="arm64";  ARCH_GO="arm64" ;;
    *) echo "Unsupported architecture: $ARCH (expected x86_64 or aarch64)" >&2; exit 1 ;;
  esac

  if [[ "$IS_TERMUX" -eq 1 || "$(id -u)" -eq 0 ]]; then
    SUDO=""
  else
    need_cmd sudo
    SUDO="sudo"
  fi
}

preflight() {
  need_cmd curl
  need_cmd git
  need_cmd uname
  need_cmd sed
}

# ==========================================================
# Dépôt
# ==========================================================

clone_or_update_repo() {
  if [[ -d "$DOTFILES" ]]; then
    if ! git -C "$DOTFILES" diff --quiet || ! git -C "$DOTFILES" diff --cached --quiet; then
      echo "Uncommitted changes in $DOTFILES." >&2
      exit 1
    fi
    ensure git -C "$DOTFILES" pull --rebase origin master
  else
    ensure git clone --depth=1 "$REPO" "$DOTFILES"
  fi
}

# ==========================================================
# Étapes partagées
# ==========================================================

clone_zsh_plugins() {
  mkdir -p "$HOME/.zsh/plugins"
  local p
  for p in zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
    [[ -d "$HOME/.zsh/plugins/$p" ]] || \
      ensure git clone --depth=1 "https://github.com/zsh-users/$p" "$HOME/.zsh/plugins/$p"
  done
}

# Lie helix/* du dépôt dans ~/.config/helix/ (le dossier reste réel pour que
# runtime/ cohabite). -n : remplace un lien-vers-dossier, ne descend pas dedans.
deploy_editor_configs() {
  mkdir -p "$HOME/.config/helix"
  local f
  for f in "$DOTFILES"/helix/*; do
    ln -sfn "$f" "$HOME/.config/helix/$(basename "$f")"
  done
}

# Config zsh : plugins, lien .zshrc, shell par défaut.
deploy_zsh_config() {
  clone_zsh_plugins
  backup_if_real "$HOME/.zshrc"
  ln -sf "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
  set_default_shell
}

# Déploie la config helix + ses language servers (gopls, bash-ls).
deploy_helix_termux() {
  deploy_editor_configs
  install_helix_lsp pkg
}

deploy_helix_debian() {
  deploy_editor_configs
  install_helix_lsp apt-get
}

deploy_zellij_config() {
  mkdir -p "$HOME/.config/zellij"
  ln -sf "$DOTFILES/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
}

setup_ssh() {
  mkdir -p "$HOME/.ssh/cm" "$HOME/.ssh/config.d"
  chmod 700 "$HOME/.ssh" "$HOME/.ssh/cm" "$HOME/.ssh/config.d"
  chmod 600 "$DOTFILES/ssh/config" "$DOTFILES/ssh/hardening.conf"
  ln -sf "$DOTFILES/ssh/hardening.conf" "$HOME/.ssh/hardening.conf"

  if [[ -z "$(ls -A "$HOME/.ssh/config.d" 2>/dev/null)" ]]; then
    cp "$DOTFILES/ssh/config.d/00-example.conf" "$HOME/.ssh/config.d/00-example.conf"
  fi
  chmod 600 "$HOME"/.ssh/config.d/*.conf 2>/dev/null || true

  backup_if_real "$HOME/.ssh/config"
  ln -sf "$DOTFILES/ssh/config" "$HOME/.ssh/config"

  find "$HOME/.ssh" -maxdepth 1 -type f -name 'id_*' ! -name '*.pub' \
    -exec chmod 600 {} \; 2>/dev/null || true
}

set_default_shell() {
  if [[ "$(basename "${SHELL:-}")" != "zsh" ]] && check_cmd zsh; then
    chsh -s "$(command -v zsh)" || true
  fi
}

# Language servers Helix (Go + Bash). $1 = gestionnaire de paquets node (pkg|apt-get).
install_helix_lsp() {
  if check_cmd gopls && check_cmd bash-language-server; then
    return 0
  fi

  if check_cmd go && ! check_cmd gopls; then
    go install golang.org/x/tools/gopls@latest || true
  fi

  if ! check_cmd bash-language-server; then
    if ! check_cmd npm && ask "bash-language-server requires Node.js. Install it?"; then
      case "$1" in
        pkg)     ensure pkg install -y nodejs ;;
        apt-get) ensure $SUDO apt-get install -y nodejs npm ;;
      esac
    fi
    # Install global dans ~/.local (sans sudo) ; non-fatal - c'est un confort.
    if check_cmd npm; then
      mkdir -p "$HOME/.local/bin" "$HOME/.local/lib"
      npm install -g --prefix "$HOME/.local" bash-language-server || true
    fi
  fi
}

# ==========================================================
# Branche TERMUX
# ==========================================================

install_termux() {
  # Rafraîchit seulement les listes de paquets (l'upgrade système = update-packages()).
  ensure pkg update -y

  # Prérequis (sans demander).
  ensure pkg install -y git unzip openssh

  # Outils de base - installés sans demander sur tous les OS.
  if any_missing zsh fzf eza zoxide; then
    pkg install -y zsh fzf eza zoxide || true
  fi
  check_cmd zsh && deploy_zsh_config
  brick zellij - deploy_zellij_config pkg install -y zellij
  brick starship - - pkg install -y starship
  brick go - - pkg install -y golang
  brick hx - deploy_helix_termux pkg install -y helix
  if check_cmd go; then
    brick sshm - - go install github.com/Gu1llaum-3/sshm@latest
  fi

  # ssh-agent persistant via termux-services.
  if ! check_cmd sv-enable && ask "Enable a persistent ssh-agent (termux-services)?"; then
    pkg install -y termux-services || true
    if check_cmd sv-enable; then
      sv-enable ssh-agent 2>/dev/null || true
    fi
  fi

  # Nerd Font = réglage app Termux (~/.termux/font.ttf).
  if [[ ! -f "$HOME/.termux/font.ttf" ]]; then
    mkdir -p "$HOME/.termux"
    curl -fL --retry 3 --retry-all-errors -o "$HOME/.termux/font.ttf" \
      "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FiraCode/Regular/FiraCodeNerdFont-Regular.ttf" || true
    if [[ -f "$HOME/.termux/font.ttf" ]] && check_cmd termux-reload-settings; then
      termux-reload-settings
    fi
  fi

  # ssh est un prérequis, donc sa config client durcie se déploie toujours.
  setup_ssh
}

# ==========================================================
# Branche DEBIAN / glibc
# ==========================================================

install_apt_packages() {
  ensure $SUDO apt-get install -y git unzip
}

install_nerd_font_gui() {
  if has_gui && [[ ! -f "$HOME/.local/share/fonts/FiraCodeNerdFont-Regular.ttf" ]]; then
    mkdir -p "$HOME/.local/share/fonts"
    curl -fsSL -o /tmp/FiraCode.zip \
      https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
    unzip -o /tmp/FiraCode.zip -d "$HOME/.local/share/fonts"
    rm -f /tmp/FiraCode.zip
    fc-cache -f
  fi
}

install_helix_glibc() {
  check_cmd hx && return 0
  HELIX_TAG="$(need_tag helix-editor/helix helix)" || return 1
  fetch_and_install \
    "https://github.com/helix-editor/helix/releases/download/${HELIX_TAG}/helix-${HELIX_TAG}-${ARCH}-linux.tar.xz" \
    extract_helix
}

install_zellij_glibc() {
  check_cmd zellij && return 0
  EXTRACT_BIN=zellij fetch_and_install \
    "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${ARCH}-unknown-linux-musl.tar.gz" \
    extract_single_bin
}

install_sshm_glibc() {
  check_cmd sshm && return 0
  local tag; tag="$(need_tag Gu1llaum-3/sshm sshm)" || return 1
  local url="https://github.com/Gu1llaum-3/sshm/releases/download/${tag}/sshm_Linux_${ARCH_ARM64}.tar.gz"
  EXTRACT_BIN=sshm fetch_and_install "$url" extract_single_bin
}

# Chaîne Go -> ~/.local/go (besoin de ~/.local/go/bin dans le PATH).
install_go_glibc() {
  check_cmd go && return 0
  local ver
  ver="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)"
  [[ -n "$ver" ]] || { echo "Failed to resolve Go version" >&2; return 1; }
  local file="${ver}.linux-${ARCH_GO}.tar.gz"
  local tmp; tmp="$(mktemp)"
  TMP_FILES+=("$tmp")
  if ! curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o "$tmp" \
    "https://go.dev/dl/${file}"; then
    rm -f "$tmp"; return 1
  fi
  rm -rf "$HOME/.local/go"
  mkdir -p "$HOME/.local"
  tar -C "$HOME/.local" -xzf "$tmp" || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"
}

install_starship_glibc() {
  check_cmd starship && return 0
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://starship.rs/install.sh | \
    sh -s -- --yes --bin-dir "$HOME/.local/bin"
}

install_alacritty_gui() {
  if has_gui && ! check_cmd alacritty; then
    $SUDO apt-get install -y software-properties-common
    $SUDO add-apt-repository -y ppa:aslatter/ppa
    $SUDO apt-get update -qq && $SUDO apt-get install -y alacritty
  fi
}

deploy_alacritty_config() {
  if has_gui; then
    mkdir -p "$HOME/.config/alacritty"
    ln -sf "$DOTFILES/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
  fi
}

install_debian() {
  # Les outils s'installent en user-local ; on s'assure que le dossier existe.
  mkdir -p "$HOME/.local/bin"

  install_apt_packages

  # Outils de base - sans demander. $SUDO non quoté : disparaît si vide.
  if any_missing zsh fzf eza zoxide keychain; then
    $SUDO apt-get install -y zsh fzf eza zoxide keychain || true
  fi
  check_cmd zsh && deploy_zsh_config
  brick go - - install_go_glibc
  brick hx - deploy_helix_debian install_helix_glibc
  brick zellij - deploy_zellij_config install_zellij_glibc
  brick sshm - - install_sshm_glibc
  brick starship - - install_starship_glibc
  if has_gui; then
    brick alacritty "Install alacritty?" deploy_alacritty_config install_alacritty_gui
    install_nerd_font_gui || true
  fi

  setup_ssh
}

# ==========================================================
# Main
# ==========================================================

main() {
  detect_env

  export PATH="$HOME/.local/bin:$HOME/.local/go/bin:$HOME/go/bin:$PATH"

  preflight
  clone_or_update_repo

  if [[ "$IS_TERMUX" -eq 1 ]]; then
    install_termux
  else
    install_debian
  fi
}

main "$@"
