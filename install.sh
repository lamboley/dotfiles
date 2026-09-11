#!/usr/bin/env bash
#
# Installe mes dotfiles en user-local (~/.local), sans sudo.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/lamboley/dotfiles/master/install.sh | bash -
#       or
#   ./install.sh
#
# Installe tous les outils de ALL_TOOLS, déploie les configs du dépôt et la
# config SSH, puis passe le shell de login à fish. Aucun argument, aucune
# variable d'environnement : le script fait toujours la même chose.

set -euo pipefail

# --------------------------------------------------------------------------------------------------
# helper functions for logs

log() {
  printf '\e[0;%sm%s[%04d]\e[0m %s\n' "$1" "$2" "${SECONDS}" "${3-}" >&2
  local message
  for message in "${@:4}"; do
    printf '           %s\n' "${message}" >&2
  done
}

info()  { log '30;46' INFO "$@"; }
warn()  { log '30;43' WARN "$@"; }
error() { log '97;41' ERRO "$@"; }
fatal() { log '97;41' FATA "$@"; exit 1; }

# --------------------------------------------------------------------------------------------------
# variables globales (le reste est résolu par setup_env)

REPO="https://github.com/lamboley/dotfiles.git"
DOTFILES="$HOME/.dotfiles"

# Outils gérés, dans l'ordre d'installation (go avant sshm, compilé avec sur Termux).
ALL_TOOLS="fish curl zoxide keychain go node nvim zellij sshm lazygit yazi fd alacritty"

IS_TERMUX=0
ARCH=""          # uname -m brut : x86_64 / aarch64
ARCH_ARM64=""    # x86_64 -> x86_64 ; aarch64 -> arm64  (nvim, sshm, lazygit)
ARCH_GO=""       # x86_64 -> amd64  ; aarch64 -> arm64  (go, node)
SUDO=""
PKG=""           # apt-get / dnf / yum de l'hôte (extras GUI uniquement)
DL=""            # téléchargeur résolu : curl (préféré) ou wget
TMP_FILES=()     # fichiers mktemp à supprimer en sortie (safe Ctrl-C)

cleanup() {
  [[ ${#TMP_FILES[@]} -gt 0 ]] && rm -rf "${TMP_FILES[@]}" 2>/dev/null
  return 0
}
trap cleanup EXIT

# --------------------------------------------------------------------------------------------------
# utilitaires

# Masque la sortie d'une commande. JAMAIS sur du sudo/chsh : leur prompt de mot
# de passe serait masqué avec.
quiet() { "$@" >/dev/null 2>&1; }

check_cmd() { command -v "$1" >/dev/null 2>&1; }

has_gui() { [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; }

# Sauvegarde un vrai fichier (pas un lien) avant de le remplacer par un lien.
backup_if_real() {
  [[ -e "$1" && ! -L "$1" ]] && mv "$1" "$1.pre-dotfiles.bak"
  return 0
}

dl_file() {
  [[ "$DL" == "wget" ]] && { wget -q --tries=3 --retry-connrefused -O "$2" "$1"; return; }
  curl -fsSL --retry 3 --retry-delay 2 --retry-all-errors -o "$2" "$1"
}

dl_stdout() {
  [[ "$DL" == "wget" ]] && { wget -qO- "$1"; return; }
  curl -fsSL "$1"
}

# Télécharge une URL dans un fichier temporaire et affiche son chemin.
fetch() {
  local tmp; tmp="$(mktemp)"; TMP_FILES+=("$tmp")
  dl_file "$1" "$tmp" || return 1
  echo "$tmp"
}

# Dernier tag de release sans l'API GitHub (pas de rate-limit) : la redirection
# de /releases/latest suffit. curl lit %{url_effective}, wget l'en-tête Location.
gh_latest_tag() {
  local url="https://github.com/$1/releases/latest"
  [[ "$DL" == "wget" ]] && { wget --max-redirect=0 -S --spider "$url" 2>&1 \
    | tr -d '\r' | sed -n 's#.*Location:.*/tag/\([^ ]*\).*#\1#p' | head -1; return; }
  curl -fsSLI -o /dev/null -w '%{url_effective}' "$url" 2>/dev/null | sed -n 's#.*/tag/##p'
}

# Télécharge l'asset d'une release GitHub -> chemin du fichier temporaire.
# $1 = owner/repo ; $2 = nom de l'asset, où @TAG@ (tag), @VER@ (tag sans le v),
# @ARCH@ et @ARM64@ sont remplacés.
gh_asset() {
  local tag asset="$2"
  tag="$(gh_latest_tag "$1")"
  [[ -n "$tag" ]] || { error "$1 : version introuvable"; return 1; }
  asset="${asset//@TAG@/$tag}";   asset="${asset//@VER@/${tag#v}}"
  asset="${asset//@ARCH@/$ARCH}"; asset="${asset//@ARM64@/$ARCH_ARM64}"
  fetch "https://github.com/$1/releases/download/${tag}/${asset}"
}

# Extrait une archive dans $2. Le format se lit aux octets magiques : fetch()
# nomme ses fichiers en mktemp, sans extension. tar reconnaît seul gz/xz ; pour
# les zip unzip n'est pas garanti -> python3 (toujours là sur Rocky/Debian),
# puis bsdtar.
unpack() {
  [[ "$(head -c2 "$1")" == "PK" ]] || { tar -C "$2" -xf "$1"; return; }
  if check_cmd unzip; then unzip -q -o "$1" -d "$2"
  elif check_cmd python3; then python3 -m zipfile -e "$1" "$2"
  elif check_cmd bsdtar; then bsdtar -xf "$1" -C "$2"
  else error "zip : unzip, python3 ou bsdtar requis"; return 1
  fi
}

# Installe des binaires pris dans une archive -> ~/.local/bin.
# $1 = archive ; $2… = noms des binaires à y trouver.
install_bins() {
  [[ -f "${1:-}" ]] || return 1
  local dir bin path; dir="$(mktemp -d)"; TMP_FILES+=("$dir")
  unpack "$1" "$dir" || return 1
  for bin in "${@:2}"; do
    path="$(find "$dir" -type f -name "$bin" | head -1)"
    [[ -n "$path" ]] || { error "$bin introuvable dans l'archive"; return 1; }
    install -m 755 "$path" "$HOME/.local/bin/$bin"
  done
}

# Installe des sous-dossiers d'une archive (bin/, lib/, share/) -> ~/.local.
install_tree() {
  [[ -f "${1:-}" ]] || return 1
  local d globs=()
  for d in "${@:2}"; do globs+=("*/$d"); done
  tar -C "$HOME/.local" --strip-components=1 --wildcards -xf "$1" "${globs[@]}"
}

# --------------------------------------------------------------------------------------------------
# installeurs user-local (glibc ; sur Termux tout passe par `pkg`, cf. termux_cmd)

install_fish()    { install_bins "$(gh_asset fish-shell/fish-shell 'fish-@TAG@-linux-@ARCH@.tar.xz')" fish; }
install_zoxide()  { install_bins "$(gh_asset ajeetdsouza/zoxide 'zoxide-@VER@-@ARCH@-unknown-linux-musl.tar.gz')" zoxide; }
install_sshm()    { install_bins "$(gh_asset Gu1llaum-3/sshm 'sshm_Linux_@ARM64@.tar.gz')" sshm; }
install_lazygit() { install_bins "$(gh_asset jesseduffield/lazygit 'lazygit_@VER@_linux_@ARM64@.tar.gz')" lazygit; }
install_fd()      { install_bins "$(gh_asset sharkdp/fd 'fd-@TAG@-@ARCH@-unknown-linux-musl.tar.gz')" fd; }
install_yazi()    { install_bins "$(gh_asset sxyazi/yazi 'yazi-@ARCH@-unknown-linux-musl.zip')" yazi ya; }
install_nvim()    { install_tree "$(gh_asset neovim/neovim 'nvim-linux-@ARM64@.tar.gz')" bin lib share; }

# Pas de binaire Linux officiel chez curl : stunnel/static-curl est le build de
# référence (musl). Sert de repli quand l'hôte n'a que wget.
install_curl() { install_bins "$(gh_asset stunnel/static-curl 'curl-linux-@ARCH@-musl-@TAG@.tar.xz')" curl; }

# zellij publie sous /latest/download : aucun tag à résoudre.
install_zellij() {
  install_bins "$(fetch "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${ARCH}-unknown-linux-musl.tar.gz")" zellij
}

# keychain : script shell sans dépendance. On reste en 2.x — la 3.0 est une
# réécriture Python (.pyz) et `latest` pointe à tort sur sa beta, donc l'API
# filtrée sur 2.N.N plutôt que gh_asset.
install_keychain() {
  local tag tmp
  tag="$(dl_stdout 'https://api.github.com/repos/danielrobbins/keychain/releases?per_page=30' 2>/dev/null \
    | grep -oE '"tag_name": *"2\.[0-9]+\.[0-9]+"' | grep -oE '2\.[0-9]+\.[0-9]+' | sort -V | tail -1)"
  [[ -n "$tag" ]] || { error "keychain : version 2.x introuvable"; return 1; }
  tmp="$(fetch "https://github.com/danielrobbins/keychain/releases/download/${tag}/keychain")" || return 1
  install -m 755 "$tmp" "$HOME/.local/bin/keychain"
}

# Chaîne Go -> ~/.local/go (le PATH inclut ~/.local/go/bin).
install_go() {
  local ver tmp
  ver="$(dl_stdout 'https://go.dev/VERSION?m=text' | head -n1)"
  [[ -n "$ver" ]] || { error "go : version introuvable"; return 1; }
  tmp="$(fetch "https://go.dev/dl/${ver}.linux-${ARCH_GO}.tar.gz")" || return 1
  rm -rf "$HOME/.local/go"
  tar -C "$HOME/.local" -xf "$tmp"
}

# Node LTS (résolue via l'index JSON) : requis par les serveurs LSP web de Neovim.
install_node() {
  local ver arch=x64
  [[ "$ARCH_GO" == "arm64" ]] && arch=arm64
  ver="$(dl_stdout https://nodejs.org/dist/index.json 2>/dev/null \
    | tr '{' '\n' | grep '"lts":"' | head -1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  [[ -n "$ver" ]] || { error "node : version LTS introuvable"; return 1; }
  install_tree "$(fetch "https://nodejs.org/dist/${ver}/node-${ver}-linux-${arch}.tar.xz")" bin lib
}

# alacritty : pas de binaire standalone officiel -> PPA apt (Debian/Ubuntu).
install_alacritty() {
  [[ "$PKG" == "apt-get" ]] || { error "alacritty : PPA apt requis"; return 1; }
  [[ -n "$SUDO" || "$(id -u)" -eq 0 ]] || { error "alacritty : sudo requis"; return 1; }
  $SUDO apt-get install -y software-properties-common >/dev/null || return 1
  $SUDO add-apt-repository -y ppa:aslatter/ppa >/dev/null || return 1
  $SUDO apt-get update -qq >/dev/null || true
  $SUDO apt-get install -y alacritty >/dev/null
}

# --------------------------------------------------------------------------------------------------
# configs du dépôt (symlinks) — deploy_<outil> est appelé après l'install

deploy_fish() {
  mkdir -p "$HOME/.config/fish/functions"
  backup_if_real "$HOME/.config/fish/config.fish"
  ln -sf "$DOTFILES/fish/config.fish" "$HOME/.config/fish/config.fish"
  ln -sf "$DOTFILES/fish/fish_plugins" "$HOME/.config/fish/fish_plugins"
  local f
  for f in "$DOTFILES"/fish/functions/*.fish; do
    [[ -e "$f" ]] && ln -sf "$f" "$HOME/.config/fish/functions/$(basename "$f")"
  done
  ensure_curl   # fisher exige curl, sans repli wget
  install_fisher
}

deploy_zellij() {
  mkdir -p "$HOME/.config/zellij"
  ln -sf "$DOTFILES/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
  ln -sfn "$DOTFILES/zellij/layouts" "$HOME/.config/zellij/layouts"
}

deploy_lazygit() {
  mkdir -p "$HOME/.config/lazygit"
  ln -sf "$DOTFILES/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
}

# Config multi-fichiers : ~/.config/nvim devient un lien vers nvim/.
deploy_nvim() {
  if [[ -L "$HOME/.config/nvim" ]]; then
    rm -f "$HOME/.config/nvim"
  elif [[ -e "$HOME/.config/nvim" ]]; then
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.pre-dotfiles.bak"
  fi
  mkdir -p "$HOME/.config"
  ln -sfn "$DOTFILES/nvim" "$HOME/.config/nvim"
}

deploy_alacritty() {
  has_gui || return 0
  mkdir -p "$HOME/.config/alacritty"
  ln -sf "$DOTFILES/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
}

# Amorce curl quand l'hôte n'a que wget : fisher n'a pas de repli.
ensure_curl() {
  check_cmd curl && return 0
  [[ "$IS_TERMUX" -eq 0 && "$DL" == "wget" ]] || return 0
  info "curl absent -> curl statique user-local (requis par fisher)"
  if quiet install_curl; then
    DL="curl"
  else
    warn "curl statique : échec — plugins fish indisponibles"
  fi
  return 0
}

# fisher + les plugins de fish_plugins (tide, z). Non-fatal : réseau requis au
# 1er passage. fisher 4.x télécharge avec curl EN DUR, d'où le garde-fou.
install_fisher() {
  check_cmd fish || return 0
  check_cmd curl || { warn "fisher nécessite curl (absent) — plugins fish sautés"; return 0; }
  info "fisher + plugins fish (tide, z)"
  quiet fish -c '
    if not functions -q fisher
      curl -sSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
      fisher install jorgebucaran/fisher
    end
    fisher update
  ' || warn "fisher a échoué (réseau ?)"
  return 0
}

setup_ssh() {
  info "configuration SSH"
  mkdir -p "$HOME/.ssh/cm" "$HOME/.ssh/config.d"
  chmod 700 "$HOME/.ssh" "$HOME/.ssh/cm" "$HOME/.ssh/config.d"
  chmod 600 "$DOTFILES/ssh/config"
  [[ -z "$(ls -A "$HOME/.ssh/config.d" 2>/dev/null)" ]] \
    && cp "$DOTFILES/ssh/config.d/00-example.conf" "$HOME/.ssh/config.d/00-example.conf"
  chmod 600 "$HOME"/.ssh/config.d/*.conf 2>/dev/null || true
  backup_if_real "$HOME/.ssh/config"
  ln -sf "$DOTFILES/ssh/config" "$HOME/.ssh/config"
  find "$HOME/.ssh" -maxdepth 1 -type f -name 'id_*' ! -name '*.pub' \
    -exec chmod 600 {} \; 2>/dev/null || true
}

# Shell de login : seule étape à demander sudo. usermod écrit /etc/passwd
# directement (pas de PAM, pas de contrainte /etc/shells) et passe là où chsh
# échoue ; sans sudo on retombe sur chsh. Termux : chsh veut le NOM du shell.
set_default_shell() {
  check_cmd fish || return 0
  [[ "$(basename "${SHELL:-}")" == "fish" ]] && return 0
  local fishbin ok=1; fishbin="$(command -v fish)"
  if [[ -f /etc/shells ]] && ! grep -qxF "$fishbin" /etc/shells; then
    echo "$fishbin" | $SUDO tee -a /etc/shells >/dev/null 2>&1 || true
  fi
  if [[ "$IS_TERMUX" -eq 1 ]]; then
    chsh -s fish && ok=0
  elif [[ -n "$SUDO" ]] && check_cmd usermod; then
    $SUDO usermod -s "$fishbin" "$(id -un)" && ok=0
  else
    chsh -s "$fishbin" && ok=0
  fi
  [[ "$ok" -eq 0 ]] && { info "shell de login changé en fish"; return 0; }
  warn "changement de shell échoué. À la main (root requis) :" \
    "sudo usermod -s $fishbin $(id -un)"
}

# --------------------------------------------------------------------------------------------------
# installation

# Sur Termux tout vient de `pkg` : seuls les noms qui diffèrent (ou les paquets
# absents, "-") sont listés ici.
termux_cmd() {
  case "$1" in
    keychain|alacritty) echo "-" ;;
    go)   echo "pkg install -y golang" ;;
    node) echo "pkg install -y nodejs" ;;
    nvim) echo "pkg install -y neovim" ;;
    sshm) echo "go install github.com/Gu1llaum-3/sshm@latest" ;;
    *)    echo "pkg install -y $1" ;;
  esac
}

# Un outil : déjà là -> on redéploie juste sa config ; absent -> install puis config.
install_tool() {
  local tool="$1" cmd
  if check_cmd "$tool"; then
    info "$tool déjà présent"
  else
    cmd="$(termux_cmd "$tool")"
    if [[ "$IS_TERMUX" -eq 1 && "$cmd" == "-" ]]; then
      info "$tool : pas de paquet Termux, sauté"
      return 0
    fi
    info "installation de $tool"
    if [[ "$IS_TERMUX" -eq 1 ]]; then
      # shellcheck disable=SC2086  # commande en chaîne : découpage voulu
      quiet $cmd || true
    else
      quiet "install_$tool" || true
    fi
    if check_cmd "$tool"; then info "$tool installé"; else warn "$tool : échec"; fi
  fi
  # Config déployée seulement si l'outil est bien là : sinon deploy_nvim, par
  # exemple, mettrait de côté une config existante pour un binaire absent.
  check_cmd "$tool" || return 0
  declare -F "deploy_$tool" >/dev/null && "deploy_$tool"
  return 0
}

# Nerd Font : réglage applicatif sur Termux, dossier de polices sinon (GUI only).
install_nerd_font() {
  local repo="https://github.com/ryanoasis/nerd-fonts" zip
  if [[ "$IS_TERMUX" -eq 1 ]]; then
    [[ -f "$HOME/.termux/font.ttf" ]] && return 0
    info "police FiraCode Nerd Font"
    mkdir -p "$HOME/.termux"
    quiet dl_file "$repo/raw/master/patched-fonts/FiraCode/Regular/FiraCodeNerdFont-Regular.ttf" \
      "$HOME/.termux/font.ttf" || return 0
    check_cmd termux-reload-settings && termux-reload-settings
    return 0
  fi
  has_gui || return 0
  [[ -f "$HOME/.local/share/fonts/FiraCodeNerdFont-Regular.ttf" ]] && return 0
  info "police FiraCode Nerd Font"
  mkdir -p "$HOME/.local/share/fonts"
  zip="$(fetch "$repo/releases/latest/download/FiraCode.zip")" \
    || { warn "téléchargement police : échec"; return 0; }
  quiet unpack "$zip" "$HOME/.local/share/fonts" || true
  quiet fc-cache -f || true
  return 0
}

# Confort : git est déjà garanti par verify_prereqs, unzip ne sert qu'aux
# polices GUI. Sauté sans gestionnaire de paquets ou sans sudo.
install_system_extras() {
  [[ -n "$PKG" && ( -n "$SUDO" || "$(id -u)" -eq 0 ) ]] || return 0
  check_cmd unzip && return 0
  info "unzip (polices GUI) via $PKG"   # sudo : stdout masqué, prompt gardé
  $SUDO "$PKG" install -y unzip >/dev/null || warn "unzip : échec"
  return 0
}

install_dotfiles() {
  local t
  if [[ "$IS_TERMUX" -eq 1 ]]; then
    info "prérequis Termux (git, unzip, openssh, curl, ssh-agent persistant)"
    quiet pkg install -y git unzip openssh curl || fatal "pkg install a échoué"
    quiet pkg install -y termux-services || true
    check_cmd sv-enable && quiet sv-enable ssh-agent || true
  else
    mkdir -p "$HOME/.local/bin"
    install_system_extras
  fi

  for t in $ALL_TOOLS; do
    # alacritty : terminal GUI, inutile sur un serveur, et seul le PPA apt le fournit.
    if [[ "$t" == "alacritty" ]] && { ! has_gui || [[ "$PKG" != "apt-get" ]]; }; then
      continue
    fi
    install_tool "$t"
  done

  install_nerd_font
  setup_ssh
  set_default_shell
  info "installation terminée — ouvre un nouveau terminal pour démarrer fish."
}

# --------------------------------------------------------------------------------------------------
# environnement

setup_env() {
  [[ -n "${TERMUX_VERSION:-}" ]] && IS_TERMUX=1

  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  ARCH_ARM64="x86_64"; ARCH_GO="amd64" ;;
    aarch64) ARCH_ARM64="arm64";  ARCH_GO="arm64" ;;
    *) fatal "architecture non supportée : $ARCH (attendu x86_64 ou aarch64)" ;;
  esac

  # sudo seulement s'il est nécessaire ET disponible : tout s'installe en
  # user-local, seules les rares étapes apt (GUI) se sautent sans lui.
  if [[ "$IS_TERMUX" -eq 1 || "$(id -u)" -eq 0 ]] || ! check_cmd sudo; then
    SUDO=""
  else
    SUDO="sudo"
  fi

  # Gestionnaire de paquets de l'hôte : extras confort/GUI uniquement (unzip,
  # alacritty). Les binaires viennent de GitHub, indépendamment de la distro.
  if [[ "$IS_TERMUX" -eq 0 ]]; then
    if check_cmd apt-get; then PKG="apt-get"
    elif check_cmd dnf; then PKG="dnf"
    elif check_cmd yum; then PKG="yum"
    fi
  fi

  # curl préféré (plus portable), wget en repli : l'un des deux suffit.
  if check_cmd curl; then DL="curl"
  elif check_cmd wget; then DL="wget"
  fi

  export PATH="$HOME/.local/bin:$HOME/.local/go/bin:$HOME/go/bin:$PATH"
  return 0
}

# git et un téléchargeur doivent préexister : ils servent à récupérer tout le
# reste. Manquants, on les liste d'un coup avec la commande qui les installe.
verify_prereqs() {
  local c missing=()
  for c in git uname sed; do
    check_cmd "$c" || missing+=("$c")
  done
  [[ -n "$DL" ]] || missing+=("curl")   # ni curl ni wget -> on suggère curl
  [[ ${#missing[@]} -eq 0 ]] && return 0

  local hint="pkg install -y ${missing[*]}"
  [[ "$IS_TERMUX" -eq 1 ]] || hint="${SUDO:+sudo }${PKG:-apt-get} install -y ${missing[*]}"
  fatal "commande(s) requise(s) manquante(s) : ${missing[*]}" "installe-les : $hint"
}

clone_or_update_repo() {
  if [[ ! -d "$DOTFILES" ]]; then
    info "clonage du dépôt dotfiles"
    quiet git clone --depth=1 "$REPO" "$DOTFILES" || fatal "git clone a échoué"
    return 0
  fi
  if ! git -C "$DOTFILES" diff --quiet || ! git -C "$DOTFILES" diff --cached --quiet; then
    fatal "modifications non committées dans $DOTFILES"
  fi
  info "mise à jour du dépôt dotfiles"
  quiet git -C "$DOTFILES" pull --rebase origin master || warn "git pull a échoué"
  return 0
}

# --------------------------------------------------------------------------------------------------
# run

{
  setup_env

  [[ $# -eq 0 ]] || fatal "install.sh ne prend pas d'argument"

  verify_prereqs
  clone_or_update_repo
  install_dotfiles
}
