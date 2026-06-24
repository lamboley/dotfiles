#!/usr/bin/env bash
#
# install.sh - install ma config
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
ARCH_ARM64=""    # x86_64 -> x86_64 ; aarch64 -> arm64    (sshm, nvim)
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

# nvim : tarball prefix (bin/ + lib/ + share/) déballé dans ~/.local.
extract_nvim() {
  mkdir -p "$HOME/.local"
  tar -C "$HOME/.local" --strip-components=1 -xzf "$1"
}

# fish : binaire unique auto-contenu (tar.xz) -> ~/.local/bin.
extract_fish() {
  mkdir -p "$HOME/.local/bin"
  tar -C "$HOME/.local/bin" -xJf "$1" fish
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

  # sudo seulement si nécessaire ET disponible. Absent -> on continue sans :
  # tout s'installe en user-local, les rares étapes apt (GUI) se sautent.
  if [[ "$IS_TERMUX" -eq 1 || "$(id -u)" -eq 0 ]] || ! check_cmd sudo; then
    SUDO=""
  else
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

# Lie helix/* du dépôt dans ~/.config/helix/ (le dossier reste réel pour que
# runtime/ cohabite). -n : remplace un lien-vers-dossier, ne descend pas dedans.
deploy_editor_configs() {
  mkdir -p "$HOME/.config/helix"
  local f
  for f in "$DOTFILES"/helix/*; do
    ln -sfn "$f" "$HOME/.config/helix/$(basename "$f")"
  done
}

# Lie nvim/init.lua du dépôt dans ~/.config/nvim/.
deploy_nvim_config() {
  mkdir -p "$HOME/.config/nvim"
  backup_if_real "$HOME/.config/nvim/init.lua"
  ln -sf "$DOTFILES/nvim/init.lua" "$HOME/.config/nvim/init.lua"
}

# Config fish (shell principal) : config + fonctions + plugins (fisher).
deploy_fish_config() {
  mkdir -p "$HOME/.config/fish/functions"
  backup_if_real "$HOME/.config/fish/config.fish"
  ln -sf "$DOTFILES/fish/config.fish" "$HOME/.config/fish/config.fish"
  ln -sf "$DOTFILES/fish/fish_plugins" "$HOME/.config/fish/fish_plugins"
  local f
  for f in "$DOTFILES"/fish/functions/*.fish; do
    ln -sf "$f" "$HOME/.config/fish/functions/$(basename "$f")"
  done
  install_fisher
  set_default_shell
}

# fisher (gestionnaire de plugins fish) + installe ceux du fish_plugins
# (tide, z, fzf.fish). Non-fatal : réseau requis au 1er passage.
install_fisher() {
  check_cmd fish || return 0
  fish -c '
    if not functions -q fisher
      curl -sSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
      fisher install jorgebucaran/fisher
    end
    fisher update
  ' || true
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

deploy_lazygit_config() {
  mkdir -p "$HOME/.config/lazygit"
  ln -sf "$DOTFILES/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
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
  check_cmd fish || return 0
  [[ "$(basename "${SHELL:-}")" == "fish" ]] && return 0
  local fishbin; fishbin="$(command -v fish)"
  # fish user-local doit figurer dans /etc/shells pour que chsh l'accepte.
  if [[ -f /etc/shells ]] && ! grep -qxF "$fishbin" /etc/shells; then
    echo "$fishbin" | $SUDO tee -a /etc/shells >/dev/null 2>&1 || true
  fi
  # `usermod` édite /etc/passwd directement (root) : pas de PAM, pas de
  # restriction "shell courant absent de /etc/shells". Plus fiable que
  # `chsh` quand sudo est dispo. Sans sudo, fallback sur chsh interactif.
  if [[ -n "$SUDO" ]] && check_cmd usermod; then
    $SUDO usermod -s "$fishbin" "$(id -un)" || true
  else
    chsh -s "$fishbin" || true
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
        pkg)
          pkg install -y nodejs || true
          ;;
        apt-get)
          if [[ -n "$SUDO" || "$(id -u)" -eq 0 ]]; then
            $SUDO apt-get install -y nodejs npm || true
          fi
          ;;
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
  # Prérequis (sans demander).
  ensure pkg install -y git unzip openssh

  # Outils de base - installés sans demander sur tous les OS.
  if any_missing fzf eza zoxide; then
    pkg install -y fzf eza zoxide || true
  fi
  brick fish - deploy_fish_config pkg install -y fish
  brick zellij - deploy_zellij_config pkg install -y zellij
  brick go - - pkg install -y golang
  brick hx - deploy_helix_termux pkg install -y helix
  brick nvim "Install neovim?" deploy_nvim_config pkg install -y neovim
  brick lazygit - deploy_lazygit_config pkg install -y lazygit
  if check_cmd go; then
    brick sshm - - go install github.com/Gu1llaum-3/sshm@latest
    brick ghq "Install ghq?" - go install github.com/x-motemen/ghq@latest
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

  setup_ssh
}

# ==========================================================
# Branche DEBIAN / glibc
# ==========================================================

# Confort uniquement : git est déjà garanti par le preflight, unzip ne sert
# qu'aux polices GUI. Sauté sans sudo (non bloquant).
install_apt_packages() {
  [[ -n "$SUDO" || "$(id -u)" -eq 0 ]] || return 0
  $SUDO apt-get install -y unzip || true
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

install_nvim_glibc() {
  check_cmd nvim && return 0
  local tag; tag="$(need_tag neovim/neovim nvim)" || return 1
  fetch_and_install \
    "https://github.com/neovim/neovim/releases/download/${tag}/nvim-linux-${ARCH_ARM64}.tar.gz" \
    extract_nvim
}

# fish : binaire standalone GitHub -> ~/.local/bin (asset = uname -m brut).
install_fish_glibc() {
  check_cmd fish && return 0
  local tag; tag="$(need_tag fish-shell/fish-shell fish)" || return 1
  fetch_and_install \
    "https://github.com/fish-shell/fish-shell/releases/download/${tag}/fish-${tag}-linux-${ARCH}.tar.xz" \
    extract_fish
}

# fzf : binaire unique (.tar.gz, chaîne Go amd64/arm64) -> ~/.local/bin.
install_fzf_glibc() {
  check_cmd fzf && return 0
  local tag; tag="$(need_tag junegunn/fzf fzf)" || return 1
  EXTRACT_BIN=fzf fetch_and_install \
    "https://github.com/junegunn/fzf/releases/download/${tag}/fzf-${tag#v}-linux_${ARCH_GO}.tar.gz" \
    extract_single_bin
}

# eza : binaire unique (membre ./eza, asset gnu) -> ~/.local/bin.
install_eza_glibc() {
  check_cmd eza && return 0
  local tag; tag="$(need_tag eza-community/eza eza)" || return 1
  EXTRACT_BIN=./eza fetch_and_install \
    "https://github.com/eza-community/eza/releases/download/${tag}/eza_${ARCH}-unknown-linux-gnu.tar.gz" \
    extract_single_bin
}

# zoxide : binaire zoxide seul (man/complétions du tarball ignorés) -> ~/.local/bin.
install_zoxide_glibc() {
  check_cmd zoxide && return 0
  local tag; tag="$(need_tag ajeetdsouza/zoxide zoxide)" || return 1
  EXTRACT_BIN=zoxide fetch_and_install \
    "https://github.com/ajeetdsouza/zoxide/releases/download/${tag}/zoxide-${tag#v}-${ARCH}-unknown-linux-musl.tar.gz" \
    extract_single_bin
}

# keychain : script unique publié tel quel (pas de tarball, tag sans v) -> ~/.local/bin.
install_keychain() {
  check_cmd keychain && return 0
  local tag; tag="$(need_tag danielrobbins/keychain keychain)" || return 1
  fetch_and_install \
    "https://github.com/danielrobbins/keychain/releases/download/${tag}/keychain" \
    install_keychain_bin
}

install_keychain_bin() {
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$1" "$HOME/.local/bin/keychain"
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

# lazygit : binaire unique (.tar.gz, chaîne Go ; asset linux minuscule) -> ~/.local/bin.
install_lazygit_glibc() {
  check_cmd lazygit && return 0
  local tag; tag="$(need_tag jesseduffield/lazygit lazygit)" || return 1
  EXTRACT_BIN=lazygit fetch_and_install \
    "https://github.com/jesseduffield/lazygit/releases/download/${tag}/lazygit_${tag#v}_linux_${ARCH_ARM64}.tar.gz" \
    extract_single_bin
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

# alacritty : pas de binaire standalone officiel -> reste apt (PPA, GUI).
# Nécessite sudo ; sauté sinon.
install_alacritty_gui() {
  [[ -n "$SUDO" || "$(id -u)" -eq 0 ]] || return 0
  if has_gui && ! check_cmd alacritty; then
    $SUDO apt-get install -y software-properties-common || return 0
    $SUDO add-apt-repository -y ppa:aslatter/ppa || return 0
    $SUDO apt-get update -qq || true
    $SUDO apt-get install -y alacritty || true
  fi
}

deploy_alacritty_config() {
  if has_gui; then
    mkdir -p "$HOME/.config/alacritty"
    ln -sf "$DOTFILES/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
  fi
}

install_debian() {
  mkdir -p "$HOME/.local/bin"

  install_apt_packages

  brick fish - deploy_fish_config install_fish_glibc
  brick fzf - - install_fzf_glibc
  brick eza - - install_eza_glibc
  brick zoxide - - install_zoxide_glibc
  brick keychain - - install_keychain
  brick go - - install_go_glibc
  brick hx - deploy_helix_debian install_helix_glibc
  brick nvim "Install neovim?" deploy_nvim_config install_nvim_glibc
  brick zellij - deploy_zellij_config install_zellij_glibc
  brick sshm - - install_sshm_glibc
  brick lazygit - deploy_lazygit_config install_lazygit_glibc
  brick ghq "Install ghq?" - go install github.com/x-motemen/ghq@latest
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
