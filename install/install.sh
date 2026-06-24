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
ARCH_ARM64=""    # x86_64 -> x86_64 ; aarch64 -> arm64    (sshm, lazygit)
ARCH_GO=""       # x86_64 -> amd64  ; aarch64 -> arm64    (chaîne Go)
SUDO=""
PKG=""           # gestionnaire de paquets hôte : apt-get / dnf / yum (extras)
VERBOSE="${VERBOSE:-0}"   # VERBOSE=1 -> montre la sortie brute des commandes (debug)
TMP_FILES=()     # fichiers mktemp à supprimer en sortie (safe Ctrl-C)

cleanup() {
  rm -rf /tmp/helix-extract /tmp/FiraCode.zip \
    "${TMP_FILES[@]}" 2>/dev/null || true
}
trap cleanup EXIT

# ==========================================================
# Utilitaires
# ==========================================================

# Couleurs (désactivées si la sortie n'est pas un terminal).
if [[ -t 1 ]]; then
  C_STEP=$'\033[1;36m'; C_OK=$'\033[1;32m'; C_DIM=$'\033[2m'; C_WARN=$'\033[1;33m'; C_OFF=$'\033[0m'
else
  C_STEP=""; C_OK=""; C_DIM=""; C_WARN=""; C_OFF=""
fi

# Lignes de progression lisibles (toujours affichées).
say()  { printf '%s▸%s %s\n'   "$C_STEP" "$C_OFF" "$*"; }
ok()   { printf '  %s✓%s %s\n' "$C_OK"   "$C_OFF" "$*"; }
skip() { printf '  %s•%s %s\n' "$C_DIM"  "$C_OFF" "$*"; }
warn() { printf '  %s⚠%s %s\n' "$C_WARN" "$C_OFF" "$*" >&2; }

# Lance une commande en masquant sa sortie ; VERBOSE=1 la rend visible.
# À n'utiliser QUE pour des commandes non interactives (jamais sudo/chsh,
# sinon leur prompt de mot de passe serait masqué).
quiet() {
  if [[ "$VERBOSE" == "1" ]]; then "$@"; else "$@" >/dev/null 2>&1; fi
}

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
  if check_cmd "$cmd"; then
    skip "$cmd déjà présent"
  else
    [[ "$prompt" == "-" ]] || ask "$prompt" || { skip "$cmd ignoré"; return 0; }
    say "installation de $cmd…"
    quiet "$@" || true
    if check_cmd "$cmd"; then ok "$cmd installé"; else warn "$cmd : échec (relance avec VERBOSE=1)"; fi
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
  if ! curl -fsSL --retry 3 --retry-delay 2 --retry-all-errors -o "$tmp" "$url"; then
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

# fish : binaire unique auto-contenu (tar.xz) -> ~/.local/bin.
extract_fish() {
  mkdir -p "$HOME/.local/bin"
  tar -C "$HOME/.local/bin" -xJf "$1" fish
}

# node : tarball nodejs.org -> ~/.local (bin/ + lib/ suffisent pour node+npm ;
# include/share/ et LICENSE/README du tarball ignorés).
extract_node() {
  mkdir -p "$HOME/.local"
  local top; top="$(tar -tJf "$1" 2>/dev/null | head -1 | cut -d/ -f1)"
  [[ -n "$top" ]] || return 1
  tar -C "$HOME/.local" --strip-components=1 -xJf "$1" "$top/bin" "$top/lib"
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

  # Gestionnaire de paquets de l'hôte glibc (extras confort/GUI uniquement :
  # unzip, alacritty). Les binaires principaux viennent de GitHub en
  # user-local, indépendamment de la distro. Vide -> ces extras se sautent.
  if [[ "$IS_TERMUX" -eq 0 ]]; then
    if check_cmd apt-get; then PKG="apt-get"
    elif check_cmd dnf; then PKG="dnf"
    elif check_cmd yum; then PKG="yum"
    fi
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
    say "mise à jour du dépôt dotfiles…"
    quiet git -C "$DOTFILES" pull --rebase origin master || warn "git pull a échoué (VERBOSE=1 pour les détails)"
  else
    say "clonage du dépôt dotfiles…"
    quiet git clone --depth=1 "$REPO" "$DOTFILES" \
      || { echo "git clone failed (VERBOSE=1 pour les détails)" >&2; exit 1; }
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
# (tide, z). Non-fatal : réseau requis au 1er passage.
install_fisher() {
  check_cmd fish || return 0
  say "fisher + plugins fish (tide, z)…"
  quiet fish -c '
    if not functions -q fisher
      curl -sSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
      fisher install jorgebucaran/fisher
    end
    fisher update
  ' || warn "fisher a échoué (réseau ? relance avec VERBOSE=1)"
}

# Déploie la config helix + ses language servers (gopls, bash-ls).
deploy_helix_termux() {
  deploy_editor_configs
  install_helix_lsp pkg
}

deploy_helix_glibc() {
  deploy_editor_configs
  install_helix_lsp "$PKG"
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
  say "configuration SSH…"
  mkdir -p "$HOME/.ssh/cm" "$HOME/.ssh/config.d"
  chmod 700 "$HOME/.ssh" "$HOME/.ssh/cm" "$HOME/.ssh/config.d"
  chmod 600 "$DOTFILES/ssh/config"

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
  if [[ "$IS_TERMUX" -eq 1 ]]; then
    # Termux : chsh attend le NOM du shell (fish), PAS le chemin complet ;
    # fish est déjà inscrit dans $PREFIX/etc/shells par `pkg install fish`.
    if chsh -s fish; then
      ok "shell changé en fish (chsh)"
    else
      warn "chsh a échoué. Relance à la main : chsh -s fish"
    fi
  elif [[ -n "$SUDO" ]] && check_cmd usermod; then
    # glibc + root : usermod édite /etc/passwd, plus fiable que chsh (pas de PAM).
    if $SUDO usermod -s "$fishbin" "$(id -un)"; then
      ok "shell changé en fish (usermod)"
    else
      warn "usermod a échoué — à la main : sudo usermod -s $fishbin $(id -un)"
    fi
  elif chsh -s "$fishbin"; then
    ok "shell changé en fish (chsh)"
  else
    # chsh échoue souvent si le shell n'est pas dans /etc/shells ou sans droits :
    # on propose la commande root équivalente, qui contourne ces restrictions.
    warn "chsh a échoué. Pour forcer le changement (root requis), lance :"
    printf '      sudo usermod -s %s %s\n' "$fishbin" "$(id -un)" >&2
  fi
}

# node : binaires officiels nodejs.org -> ~/.local (glibc ; Termux reste `pkg`).
install_node_glibc() {
  check_cmd node && return 0
  local ver arch
  ver="$(curl -fsSL https://nodejs.org/dist/index.json 2>/dev/null \
    | tr '{' '\n' | grep '"lts":"' | head -1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  [[ -n "$ver" ]] || { echo "Failed to resolve Node LTS version" >&2; return 1; }
  case "$ARCH_GO" in
    amd64) arch=x64 ;;
    arm64) arch=arm64 ;;
    *) return 1 ;;
  esac
  fetch_and_install \
    "https://nodejs.org/dist/${ver}/node-${ver}-linux-${arch}.tar.xz" \
    extract_node
}

# Language servers Helix (Go + Bash). $1 = "pkg" (Termux, node natif) sinon glibc.
install_helix_lsp() {
  if check_cmd gopls && check_cmd bash-language-server; then
    return 0
  fi

  if check_cmd go && ! check_cmd gopls; then
    say "LSP Go (gopls)…"
    quiet go install golang.org/x/tools/gopls@latest || warn "gopls : échec"
  fi

  if ! check_cmd bash-language-server; then
    if ! check_cmd npm && ask "bash-language-server requires Node.js. Install it?"; then
      say "Node.js (pour le LSP bash)…"
      if [[ "$1" == "pkg" ]]; then
        quiet pkg install -y nodejs || true      # Termux : node natif (tarball glibc incompatible)
      else
        quiet install_node_glibc || true         # glibc : node user-local depuis nodejs.org
      fi
    fi
    # Install global dans ~/.local (sans sudo) ; non-fatal - c'est un confort.
    if check_cmd npm; then
      say "LSP Bash (bash-language-server)…"
      mkdir -p "$HOME/.local/bin" "$HOME/.local/lib"
      quiet npm install -g --prefix "$HOME/.local" bash-language-server || warn "bash-language-server : échec"
    fi
  fi
}

# ==========================================================
# Branche TERMUX
# ==========================================================

install_termux() {
  say "prérequis Termux (git, unzip, openssh)…"
  ensure quiet pkg install -y git unzip openssh

  # Outils de base - installés sans demander sur tous les OS.
  if any_missing zoxide; then
    say "zoxide…"
    quiet pkg install -y zoxide || true
  fi
  brick fish - deploy_fish_config pkg install -y fish
  brick zellij - deploy_zellij_config pkg install -y zellij
  brick go - - pkg install -y golang
  brick hx - deploy_helix_termux pkg install -y helix
  brick lazygit - deploy_lazygit_config pkg install -y lazygit
  if check_cmd go; then
    brick sshm - - go install github.com/Gu1llaum-3/sshm@latest
  fi

  # ssh-agent persistant via termux-services.
  if ! check_cmd sv-enable && ask "Enable a persistent ssh-agent (termux-services)?"; then
    say "termux-services (ssh-agent persistant)…"
    quiet pkg install -y termux-services || true
    if check_cmd sv-enable; then
      sv-enable ssh-agent 2>/dev/null || true
    fi
  fi

  # Nerd Font = réglage app Termux (~/.termux/font.ttf).
  if [[ ! -f "$HOME/.termux/font.ttf" ]]; then
    say "police FiraCode Nerd Font (Termux)…"
    mkdir -p "$HOME/.termux"
    quiet curl -fsSL --retry 3 --retry-all-errors -o "$HOME/.termux/font.ttf" \
      "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FiraCode/Regular/FiraCodeNerdFont-Regular.ttf" || true
    if [[ -f "$HOME/.termux/font.ttf" ]] && check_cmd termux-reload-settings; then
      termux-reload-settings
    fi
  fi

  setup_ssh
}

# ==========================================================
# Branche glibc (Debian/Ubuntu, RHEL/Rocky/Fedora)
# ==========================================================

# Confort uniquement : git est déjà garanti par le preflight, unzip ne sert
# qu'aux polices GUI. Sauté sans gestionnaire/sans sudo (non bloquant).
install_system_extras() {
  [[ -n "$PKG" ]] || return 0
  [[ -n "$SUDO" || "$(id -u)" -eq 0 ]] || return 0
  check_cmd unzip && return 0
  say "unzip (polices GUI) via $PKG…"   # sudo : stdout masqué, stderr/prompt gardés
  $SUDO "$PKG" install -y unzip >/dev/null || warn "unzip : échec"
}

install_nerd_font_gui() {
  if has_gui && [[ ! -f "$HOME/.local/share/fonts/FiraCodeNerdFont-Regular.ttf" ]]; then
    say "police FiraCode Nerd Font…"
    mkdir -p "$HOME/.local/share/fonts"
    quiet curl -fsSL -o /tmp/FiraCode.zip \
      https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip \
      || { warn "téléchargement police : échec"; return 0; }
    quiet unzip -o /tmp/FiraCode.zip -d "$HOME/.local/share/fonts" || true
    rm -f /tmp/FiraCode.zip
    quiet fc-cache -f || true
  fi
}

install_helix_glibc() {
  check_cmd hx && return 0
  HELIX_TAG="$(need_tag helix-editor/helix helix)" || return 1
  fetch_and_install \
    "https://github.com/helix-editor/helix/releases/download/${HELIX_TAG}/helix-${HELIX_TAG}-${ARCH}-linux.tar.xz" \
    extract_helix
}

# fish : binaire standalone GitHub -> ~/.local/bin (asset = uname -m brut).
install_fish_glibc() {
  check_cmd fish && return 0
  local tag; tag="$(need_tag fish-shell/fish-shell fish)" || return 1
  fetch_and_install \
    "https://github.com/fish-shell/fish-shell/releases/download/${tag}/fish-${tag}-linux-${ARCH}.tar.xz" \
    extract_fish
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
  if ! curl -fsSL --retry 3 --retry-delay 2 --retry-all-errors -o "$tmp" \
    "https://go.dev/dl/${file}"; then
    rm -f "$tmp"; return 1
  fi
  rm -rf "$HOME/.local/go"
  mkdir -p "$HOME/.local"
  tar -C "$HOME/.local" -xzf "$tmp" || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"
}

# alacritty : pas de binaire standalone officiel -> PPA apt (Debian/Ubuntu, GUI).
# Hors apt (RHEL…) ou sans sudo : sauté (un serveur n'a de toute façon pas de GUI).
install_alacritty_gui() {
  [[ "$PKG" == "apt-get" ]] || return 0
  [[ -n "$SUDO" || "$(id -u)" -eq 0 ]] || return 0
  if has_gui && ! check_cmd alacritty; then
    say "alacritty (PPA apt)…"   # sudo : stdout masqué, stderr/prompt gardés
    $SUDO apt-get install -y software-properties-common >/dev/null || return 0
    $SUDO add-apt-repository -y ppa:aslatter/ppa >/dev/null || return 0
    $SUDO apt-get update -qq >/dev/null || true
    $SUDO apt-get install -y alacritty >/dev/null || warn "alacritty : échec"
  fi
}

deploy_alacritty_config() {
  if has_gui; then
    mkdir -p "$HOME/.config/alacritty"
    ln -sf "$DOTFILES/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
  fi
}

install_glibc() {
  mkdir -p "$HOME/.local/bin"

  install_system_extras

  brick fish - deploy_fish_config install_fish_glibc
  brick zoxide - - install_zoxide_glibc
  brick keychain - - install_keychain
  brick go - - install_go_glibc
  brick hx - deploy_helix_glibc install_helix_glibc
  brick zellij - deploy_zellij_config install_zellij_glibc
  brick sshm - - install_sshm_glibc
  brick lazygit - deploy_lazygit_config install_lazygit_glibc
  if has_gui; then
    brick alacritty "Install alacritty?" deploy_alacritty_config install_alacritty_gui
    install_nerd_font_gui || true
  fi

  setup_ssh
}

# ==========================================================
# Main
# ==========================================================

# Installe toute la config (comportement par défaut, sans argument).
install_all() {
  preflight
  clone_or_update_repo

  if [[ "$IS_TERMUX" -eq 1 ]]; then
    install_termux
  else
    install_glibc
  fi

  ok "installation terminée — ouvre un nouveau terminal pour démarrer fish."
}

# Termux -> paquet `pkg` ; glibc -> fonction de build user-local.
# $1 = nom du paquet termux ; $2 = fonction d'install glibc.
pkg_or_build() {
  if [[ "$IS_TERMUX" -eq 1 ]]; then
    pkg install -y "$1"
  else
    "$2"
  fi
}

# install.sh install <outil> : (ré)installe un seul outil en user-local.
# Les shells (fish) sont volontairement exclus -> install complète seulement.
cmd_install() {
  need_cmd curl
  case "${1:-}" in
    zellij)   pkg_or_build zellij   install_zellij_glibc;  deploy_zellij_config ;;
    lazygit)  pkg_or_build lazygit  install_lazygit_glibc; deploy_lazygit_config ;;
    zoxide)   pkg_or_build zoxide   install_zoxide_glibc ;;
    keychain) pkg_or_build keychain install_keychain ;;
    go)       pkg_or_build golang   install_go_glibc ;;
    sshm)
      if [[ "$IS_TERMUX" -eq 1 ]]; then
        need_cmd go; go install github.com/Gu1llaum-3/sshm@latest
      else
        install_sshm_glibc
      fi
      ;;
    hx)
      if [[ "$IS_TERMUX" -eq 1 ]]; then
        pkg install -y helix; deploy_helix_termux
      else
        install_helix_glibc; deploy_helix_glibc
      fi
      ;;
    fish|zsh) echo "shell exclu (risque de lockout) : passe par l'install complète." >&2; exit 1 ;;
    *) echo "usage: install.sh install <zellij|lazygit|zoxide|keychain|go|sshm|hx>" >&2; exit 1 ;;
  esac
}

# Retire un binaire des emplacements user-local connus (~/.local/bin, ~/go/bin).
rm_user_bin() {
  local bin="$1" found=0 dir
  for dir in "$HOME/.local/bin" "$HOME/go/bin"; do
    if [[ -e "$dir/$bin" || -L "$dir/$bin" ]]; then
      rm -f "$dir/$bin"; echo "retiré : $dir/$bin"; found=1
    fi
  done
  [[ "$found" -eq 1 ]] || echo "déjà absent : $bin"
}

# Retire un binaire user-local + ses symlinks de config (jamais un vrai fichier).
# $1 = nom du binaire ; $2... = liens de config à retirer.
uninstall_local() {
  local bin="$1"; shift
  rm_user_bin "$bin"
  local link
  for link in "$@"; do
    [[ -L "$link" ]] && { rm -f "$link"; echo "retiré : $link"; }
  done
}

# install.sh uninstall <outil> : retire la version user-local (binaire +
# symlinks de config). Shells exclus pour éviter le lockout.
cmd_uninstall() {
  local f
  case "${1:-}" in
    zellij)   uninstall_local zellij   "$HOME/.config/zellij/config.kdl" ;;
    lazygit)  uninstall_local lazygit  "$HOME/.config/lazygit/config.yml" ;;
    zoxide)   uninstall_local zoxide ;;
    keychain) uninstall_local keychain ;;
    sshm)     uninstall_local sshm ;;
    go)
      if [[ -d "$HOME/.local/go" ]]; then
        rm -rf "$HOME/.local/go"; echo "retiré : ~/.local/go (toolchain Go ; ~/go/bin conservé)"
      else
        echo "déjà absent : ~/.local/go"
      fi
      ;;
    hx)
      uninstall_local hx
      for f in "$HOME"/.config/helix/*; do
        [[ -L "$f" ]] && { rm -f "$f"; echo "retiré : $f"; }
      done
      [[ -d "$HOME/.config/helix/runtime" ]] && { rm -rf "$HOME/.config/helix/runtime"; echo "retiré : ~/.config/helix/runtime"; }
      ;;
    fish|zsh) echo "shell exclu (risque de lockout) : retire-le à la main si besoin." >&2; exit 1 ;;
    *) echo "usage: install.sh uninstall <zellij|lazygit|zoxide|keychain|go|sshm|hx>" >&2; exit 1 ;;
  esac
}

main() {
  detect_env

  export PATH="$HOME/.local/bin:$HOME/.local/go/bin:$HOME/go/bin:$PATH"

  case "${1:-}" in
    "")        install_all ;;
    install)   shift; cmd_install   "$@" ;;
    uninstall) shift; cmd_uninstall "$@" ;;
    *) echo "usage: install.sh [install <outil> | uninstall <outil>]" >&2; exit 1 ;;
  esac
}

main "$@"
