#!/usr/bin/env bash
#
# Dotfiles installer for lamboley/dotfiles.
#
# Run via curl:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/lamboley/dotfiles/master/tools/install.sh)"
# Or download then run (recommended for interactive prompts):
#   curl -fsSL https://raw.githubusercontent.com/lamboley/dotfiles/master/tools/install.sh -o install.sh
#   bash install.sh
#
# Targets: Termux (native, bionic), Ubuntu/glibc (desktop, servers, proot),
# and Rocky/RHEL-family hosts (SSH bastion hardening only).
# Usage: install.sh [ubuntu|termux|rhel] [-y]  (see --help)
#
set -euo pipefail

# ==========================================================
# Globals
# ==========================================================
DOTFILES="$HOME/.dotfiles"
REPO="https://github.com/lamboley/dotfiles.git"

IS_TERMUX=0
IS_RHEL=0
ARCH=""
ARCH_ARM64=""    # x86_64 -> x86_64 ; aarch64 -> arm64   (sshm)
ARCH_AARCH64=""  # x86_64 -> x86_64 ; aarch64 -> aarch64 (zellij, helix)
ARCH_GO=""       # x86_64 -> amd64  ; aarch64 -> arm64   (Go toolchain)
SUDO=""
TARGET=""        # forced branch: ubuntu | termux | rhel (empty = auto-detect)
ASSUME_YES=0     # -y / --yes: skip all prompts (install everything)
FAILED_STEPS=()  # optional steps that failed (reported at the end)

# Clean up any leftover temp files on exit, even if the script dies mid-way.
cleanup() {
  rm -rf /tmp/helix-extract /tmp/FiraCode.zip 2>/dev/null || true
}
trap cleanup EXIT

# ==========================================================
# Output helpers (colors only when stdout is a terminal)
# ==========================================================
if [[ -t 1 ]]; then
  C_RED=$'\033[1;31m'; C_GREEN=$'\033[1;32m'
  C_BLUE=$'\033[1;34m'; C_RESET=$'\033[0m'
else
  C_RED=""; C_GREEN=""; C_BLUE=""; C_RESET=""
fi

# Logging in the Kubernetes hack/lib/logging.sh format:
#   +++ [MMDD HH:MM:SS] status line
#       indented continuation (4 spaces, no prefix)
#   !!! [MMDD HH:MM:SS] error line (stderr)
ts() { date +"[%m%d %H:%M:%S]"; }

info()      { printf '%s+++%s %s %s\n' "$C_BLUE" "$C_RESET" "$(ts)" "$*"; }
success()   { printf '%s+++%s %s %s\n' "$C_GREEN" "$C_RESET" "$(ts)" "$*"; }
# Continuation line under the current step (plain indentation, k8s-style).
detail()    { printf '    %s\n' "$*"; }
fmt_error() { printf '%s!!!%s %s %s\n' "$C_RED" "$C_RESET" "$(ts)" "$*" >&2; }

# ==========================================================
# Small utilities
# ==========================================================
check_cmd() { command -v "$1" >/dev/null 2>&1; }

need_cmd() {
  if ! check_cmd "$1"; then
    fmt_error "required command not found: $1"
    exit 1
  fi
}

# Run a command that must succeed, or abort with a clear message.
ensure() {
  if ! "$@"; then
    fmt_error "command failed: $*"
    exit 1
  fi
}

# Run an OPTIONAL step: if it fails, record it and keep going instead of
# aborting. A summary of failures is printed at the end. Use this for
# individual tools where one failure shouldn't sink the whole install.
# $1 = human label ; $2... = command
attempt() {
  local label="$1"; shift
  if ! "$@"; then
    fmt_error "step failed: $label (continuing)"
    FAILED_STEPS+=("$label")
  fi
  return 0
}

# Print a summary of optional steps that failed, if any.
report_failures() {
  if [[ "${#FAILED_STEPS[@]}" -gt 0 ]]; then
    fmt_error "Some optional steps failed: ${FAILED_STEPS[*]}"
    detail "The rest of the setup completed. You can re-run the script to retry."
  fi
}

has_gui() { [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; }

# Yes/no prompt that survives `curl | bash` by reading from /dev/tty.
# Non-interactive (no tty) or -y flag: returns "yes" so unattended
# installs are complete.
ask() {
  [[ "$ASSUME_YES" -eq 1 ]] && return 0
  [[ ! -t 1 || ! -e /dev/tty ]] && return 0
  local ans
  printf '%s+++%s %s %s [Y/n] ' "$C_BLUE" "$C_RESET" "$(ts)" "$1"
  read -r ans < /dev/tty || return 0
  [[ "$ans" =~ ^[Nn] ]] && return 1
  return 0
}

# One "brick" = a tool and its config, handled together:
#   - tool already present  -> (re)deploy its config, no question asked
#   - tool absent           -> ask; on yes, install then deploy its config
#   - user declines         -> skip both
# $1 = command to check ; $2 = prompt ; $3 = deploy function ("-" for none)
# $4... = install command
brick() {
  local cmd="$1" prompt="$2" deploy_fn="$3"; shift 3
  if ! check_cmd "$cmd"; then
    ask "$prompt" || return 0
    attempt "$cmd" "$@"
  fi
  if check_cmd "$cmd" && [[ "$deploy_fn" != "-" ]]; then
    "$deploy_fn"
  fi
  return 0
}

# Resolve a repo's latest release tag WITHOUT the GitHub API (no rate limit).
gh_latest_tag() {
  curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/$1/releases/latest" 2>/dev/null | sed -n 's#.*/tag/##p'
}

# Back up a real file (not a symlink) before replacing it with our symlink.
backup_if_real() {
  if [[ -e "$1" && ! -L "$1" ]]; then
    mv "$1" "$1.pre-dotfiles.bak"
    detail "Backed up existing $1 to $1.pre-dotfiles.bak"
  fi
}

# ==========================================================
# GitHub binary installer with a pluggable extraction step.
#   $1 = download URL
#   $2 = name of a function handling extraction; it receives the downloaded
#        file path as $1 and is responsible for installing the binary.
# The helper owns the common parts (download + cleanup); the callback owns
# the layout differences (single binary vs runtime dir, etc.).
# ==========================================================
fetch_and_install() {
  local url="$1" extract_fn="$2"
  local tmp; tmp="$(mktemp)"
  if ! curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o "$tmp" "$url"; then
    rm -f "$tmp"; return 1
  fi
  "$extract_fn" "$tmp" || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"
}

# Extraction callbacks ------------------------------------------------------
# All tools are installed user-local in ~/.local/bin (must be in PATH).
# Simple case: a .tar.gz containing a single binary.
# Uses $EXTRACT_BIN (set by caller) as the binary name inside the tarball.
# Callbacks return non-zero on failure so attempt() can record it.
extract_single_bin() {
  mkdir -p "$HOME/.local/bin"
  tar -C "$HOME/.local/bin" -xzf "$1" "$EXTRACT_BIN"
}

extract_helix() {
  # helix ships hx + a runtime dir that must live where hx looks for it.
  local dir="/tmp/helix-extract"
  rm -rf "$dir"; mkdir -p "$dir"
  tar -C "$dir" -xJf "$1" || return 1
  local hxdir="$dir/helix-${HELIX_TAG}-${ARCH_AARCH64}-linux"
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$hxdir/hx" "$HOME/.local/bin/hx" || return 1
  mkdir -p "$HOME/.config/helix"
  rm -rf "$HOME/.config/helix/runtime"
  cp -r "$hxdir/runtime" "$HOME/.config/helix/runtime"
  rm -rf "$dir"
}

# ==========================================================
# Detection / preflight
# ==========================================================
detect_env() {
  [[ -n "${TERMUX_VERSION:-}" ]] && IS_TERMUX=1
  command -v dnf >/dev/null 2>&1 && IS_RHEL=1

  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  ARCH_ARM64="x86_64"; ARCH_AARCH64="x86_64"; ARCH_GO="amd64" ;;
    aarch64) ARCH_ARM64="arm64";  ARCH_AARCH64="aarch64"; ARCH_GO="arm64" ;;
    *) fmt_error "Unsupported architecture: $ARCH (expected x86_64 or aarch64)"; exit 1 ;;
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
# Repo
# ==========================================================
clone_or_update_repo() {
  if [[ -d "$DOTFILES" ]]; then
    info "Updating dotfiles repo"
    ensure git -C "$DOTFILES" pull --rebase origin master
  else
    info "Cloning dotfiles repo"
    ensure git clone --depth=1 "$REPO" "$DOTFILES"
  fi
}

# ==========================================================
# Shared steps
# ==========================================================
clone_zsh_plugins() {
  mkdir -p "$HOME/.zsh/plugins"
  local p
  for p in zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
    [[ -d "$HOME/.zsh/plugins/$p" ]] || \
      ensure git clone --depth=1 "https://github.com/zsh-users/$p" "$HOME/.zsh/plugins/$p"
  done
}

# Symlink each file/dir from the repo's helix/ folder into ~/.config/helix/.
# The directory itself stays real so the helix runtime/ (installed by
# extract_helix or pkg) can live alongside without polluting the repo.
# -n: replace an existing symlink-to-dir instead of descending into it.
deploy_editor_configs() {
  mkdir -p "$HOME/.config/helix"
  local f
  for f in "$DOTFILES"/helix/*; do
    ln -sfn "$f" "$HOME/.config/helix/$(basename "$f")"
  done
}

# zsh config: plugins, .zshrc symlink, default shell.
deploy_zsh_config() {
  clone_zsh_plugins
  backup_if_real "$HOME/.zshrc"
  ln -sf "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
  set_default_shell
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
    chsh -s "$(command -v zsh)" || \
      detail "Could not change shell automatically; run 'chsh -s zsh' manually."
  fi
}

# Language servers for Helix (Go + Bash).
# $1 = package manager for nodejs ("pkg" or "apt-get").
install_helix_lsp() {
  info "Installing Helix language servers"

  if check_cmd go && ! check_cmd gopls; then
    go install golang.org/x/tools/gopls@latest \
      || fmt_error "Failed to install gopls (continuing)"
  fi

  if ! check_cmd bash-language-server; then
    if check_cmd npm; then
      ensure npm install -g bash-language-server
    elif ask "bash-language-server requires Node.js. Install it?"; then
      case "$1" in
        pkg)     ensure pkg install -y nodejs ;;
        apt-get) ensure $SUDO apt-get install -y nodejs npm ;;
      esac
      ensure npm install -g bash-language-server
    else
      detail "Skipping bash-language-server (Node.js declined)."
    fi
  fi
}

# ==========================================================
# TERMUX branch
# ==========================================================
install_termux() {
  info "Termux detected — installing via pkg"

  if ask "Update system packages (pkg update/upgrade)?"; then
    ensure pkg update -y
    ensure pkg upgrade -y
  fi

  # Script prerequisites — installed without asking.
  ensure pkg install -y git curl unzip openssh

  # Bricks: tool + its config, deployed together (see brick()).
  brick zsh "Install zsh and its tools (fzf, eza, zoxide)?" \
    deploy_zsh_config pkg install -y zsh fzf eza zoxide
  brick zellij "Install zellij?" deploy_zellij_config pkg install -y zellij
  brick hx "Install helix?" deploy_editor_configs pkg install -y helix
  brick starship "Install starship?" - pkg install -y starship
  brick go "Install golang?" - pkg install -y golang
  if check_cmd go; then
    brick sshm "Install sshm?" - go install github.com/Gu1llaum-3/sshm@latest
  fi

  # Persistent ssh-agent via termux-services (pairs with AddKeysToAgent).
  if ! check_cmd sv-enable && ask "Enable a persistent ssh-agent (termux-services)?"; then
    attempt "termux-services" pkg install -y termux-services
    if check_cmd sv-enable; then
      sv-enable ssh-agent 2>/dev/null \
        || detail "Restart Termux, then run: sv-enable ssh-agent"
    fi
  fi

  # Nerd Font: on Termux the font is an APP setting (~/.termux/font.ttf)
  if [[ ! -f "$HOME/.termux/font.ttf" ]] && ask "Install the Nerd Font?"; then
    mkdir -p "$HOME/.termux"
    attempt "Nerd Font" curl -fL --retry 3 --retry-all-errors -o "$HOME/.termux/font.ttf" \
      "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FiraCode/Regular/FiraCodeNerdFont-Regular.ttf"
    if [[ -f "$HOME/.termux/font.ttf" ]] && check_cmd termux-reload-settings; then
      termux-reload-settings
    fi
  fi

  if ask "Deploy the hardened SSH client config (config.d)?"; then
    setup_ssh
  fi

  if ask "Install Helix language servers (gopls, bash-ls)?"; then
    install_helix_lsp pkg
  fi

  report_failures
  success "Termux setup complete. Restart Termux to land in zsh."
}

# ==========================================================
# UBUNTU / glibc branch
# ==========================================================
install_apt_packages() {
  info "apt packages"

  if ask "Update system packages (apt update/upgrade)?"; then
    ensure $SUDO apt-get update -y
    $SUDO apt-get upgrade -y && $SUDO apt-get autoremove -y
  else
    # Package lists are still needed to install anything below.
    ensure $SUDO apt-get update -y
  fi

  # Script prerequisites — installed without asking.
  ensure $SUDO apt-get install -y curl git unzip
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
  HELIX_TAG="$(gh_latest_tag helix-editor/helix)"
  [[ -n "$HELIX_TAG" ]] || { fmt_error "Failed to resolve helix version"; return 1; }
  fetch_and_install \
    "https://github.com/helix-editor/helix/releases/download/${HELIX_TAG}/helix-${HELIX_TAG}-${ARCH_AARCH64}-linux.tar.xz" \
    extract_helix
}

install_zellij_glibc() {
  check_cmd zellij && return 0
  EXTRACT_BIN=zellij fetch_and_install \
    "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${ARCH_AARCH64}-unknown-linux-musl.tar.gz" \
    extract_single_bin
}

install_sshm_glibc() {
  check_cmd sshm && return 0
  local tag; tag="$(gh_latest_tag Gu1llaum-3/sshm)"
  [[ -n "$tag" ]] || { fmt_error "Failed to resolve sshm version"; return 1; }
  EXTRACT_BIN=sshm fetch_and_install \
    "https://github.com/Gu1llaum-3/sshm/releases/download/${tag}/sshm_Linux_${ARCH_ARM64}.tar.gz" \
    extract_single_bin
}

# Go toolchain, user-local: ~/.local/go (add ~/.local/go/bin to PATH).
install_go_glibc() {
  check_cmd go && return 0
  local ver
  ver="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)"
  [[ -n "$ver" ]] || { fmt_error "Failed to resolve Go version"; return 1; }
  local tmp; tmp="$(mktemp)"
  if ! curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o "$tmp" \
    "https://go.dev/dl/${ver}.linux-${ARCH_GO}.tar.gz"; then
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

install_ubuntu() {
  info "Ubuntu/glibc target"

  # Tools are installed user-local; make sure the directory exists.
  mkdir -p "$HOME/.local/bin"

  install_apt_packages

  # Bricks: tool + its config, deployed together (see brick()).
  # $SUDO is intentionally unquoted: it disappears when empty.
  brick zsh "Install zsh and its tools (fzf, eza, zoxide, keychain)?" \
    deploy_zsh_config $SUDO apt-get install -y zsh fzf eza zoxide keychain
  brick go "Install golang (~/.local/go)?" - install_go_glibc
  brick hx "Install helix?" deploy_editor_configs install_helix_glibc
  brick zellij "Install zellij?" deploy_zellij_config install_zellij_glibc
  brick sshm "Install sshm?" - install_sshm_glibc
  brick starship "Install starship?" - install_starship_glibc
  if has_gui; then
    brick alacritty "Install alacritty?" deploy_alacritty_config install_alacritty_gui
    if ask "Install the Nerd Font?"; then
      attempt "Nerd Font" install_nerd_font_gui
    fi
  fi

  if ask "Deploy the hardened SSH client config (config.d)?"; then
    setup_ssh
  fi

  if ask "Install Helix language servers (gopls, bash-ls)?"; then
    install_helix_lsp apt-get
  fi

  report_failures
  success "Ubuntu setup complete."
}

# ==========================================================
# ROCKY / RHEL-family branch (SSH bastion: hardening only)
# No zsh, no tools — this host is only a ProxyJump relay.
# Deploys ssh/sshd_hardening.conf into /etc/ssh/sshd_config.d/
# with a lockout guard and config validation before restart.
# ==========================================================
bootstrap_rhel() {
  check_cmd git || ensure $SUDO dnf -y install git
}

install_rhel_bastion() {
  info "Rocky/RHEL-family target — SSH bastion"

  if ask "Update system packages (dnf update)?"; then
    ensure $SUDO dnf -y update
  fi

  if ! ask "Apply sshd hardening (keys only, no root)?"; then
    detail "sshd hardening skipped."
    report_failures
    return 0
  fi

  # Lockout guard: never disable password auth without a working key.
  if [[ ! -s "$HOME/.ssh/authorized_keys" ]]; then
    fmt_error "No ~/.ssh/authorized_keys found."
    fmt_error "Add your public key first or you will lock yourself out."
    exit 1
  fi

  # Copy (not symlink): /etc must not depend on a file in \$HOME.
  ensure $SUDO install -m 600 -o root -g root \
    "$DOTFILES/ssh/sshd_hardening.conf" \
    /etc/ssh/sshd_config.d/00-hardening.conf

  # Validate before restarting; roll back if the config is broken.
  if $SUDO sshd -t; then
    ensure $SUDO systemctl restart sshd
    success "sshd hardened. Test a NEW connection before closing this one."
  else
    $SUDO rm -f /etc/ssh/sshd_config.d/00-hardening.conf
    fmt_error "sshd config validation failed — hardening removed, sshd untouched."
    exit 1
  fi

  report_failures
  success "Bastion setup complete."
}

# ==========================================================
# Main
# ==========================================================
usage() {
  cat <<'EOF'
Usage: install.sh [target] [-y]

  target     force the install branch instead of auto-detecting:
               ubuntu   apt-based desktop/server setup
               termux   Termux/Android setup
               rhel     Rocky/RHEL bastion (sshd hardening)
  -y, --yes  answer yes to every prompt (unattended install)
EOF
}

main() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -y|--yes)          ASSUME_YES=1 ;;
      ubuntu|termux|rhel) TARGET="$arg" ;;
      -h|--help)         usage; exit 0 ;;
      *) fmt_error "unknown option: $arg"; usage; exit 1 ;;
    esac
  done

  detect_env

  # Make user-local install locations visible to this script run itself:
  # without this, gopls installation cannot find the Go toolchain that
  # install_go_glibc just placed in ~/.local/go.
  export PATH="$HOME/.local/bin:$HOME/.local/go/bin:$HOME/go/bin:$PATH"

  # Forced target overrides detection (proot, containers, testing...).
  case "$TARGET" in
    termux) IS_TERMUX=1; IS_RHEL=0 ;;
    rhel)   IS_TERMUX=0; IS_RHEL=1 ;;
    ubuntu) IS_TERMUX=0; IS_RHEL=0 ;;
  esac
  [[ -n "$TARGET" ]] && detail "Forced target: $TARGET"

  [[ "$IS_RHEL" -eq 1 ]] && bootstrap_rhel
  preflight
  clone_or_update_repo

  if [[ "$IS_TERMUX" -eq 1 ]]; then
    install_termux
  elif [[ "$IS_RHEL" -eq 1 ]]; then
    install_rhel_bastion
  else
    install_ubuntu
  fi
}

main "$@"
#!/usr/bin/env bash
#
# Dotfiles installer for lamboley/dotfiles.
#
# Run via curl:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/lamboley/dotfiles/master/tools/install.sh)"
# Or download then run (recommended for interactive prompts):
#   curl -fsSL https://raw.githubusercontent.com/lamboley/dotfiles/master/tools/install.sh -o install.sh
#   bash install.sh
#
# Targets: Termux (native, bionic) and Ubuntu/glibc (desktop, servers, proot).
#
set -euo pipefail

# ==========================================================
# Globals
# ==========================================================
DOTFILES="$HOME/.dotfiles"
REPO="https://github.com/lamboley/dotfiles.git"

IS_TERMUX=0
IS_RHEL=0
ARCH=""
ARCH_ARM64=""    # x86_64 -> x86_64 ; aarch64 -> arm64   (sshm)
ARCH_AARCH64=""  # x86_64 -> x86_64 ; aarch64 -> aarch64 (zellij, helix)
ARCH_GO=""       # x86_64 -> amd64  ; aarch64 -> arm64   (Go toolchain)
SUDO=""
TARGET=""        # forced branch: ubuntu | termux | rhel (empty = auto-detect)
ASSUME_YES=0     # -y / --yes: skip all prompts (install everything)
FAILED_STEPS=()  # optional steps that failed (reported at the end)

# Clean up any leftover temp files on exit, even if the script dies mid-way.
cleanup() {
  rm -rf /tmp/helix-extract /tmp/FiraCode.zip 2>/dev/null || true
}
trap cleanup EXIT

# ==========================================================
# Output helpers (colors only when stdout is a terminal)
# ==========================================================
if [[ -t 1 ]]; then
  C_RED=$'\033[1;31m'; C_GREEN=$'\033[1;32m'
  C_BLUE=$'\033[1;34m'; C_RESET=$'\033[0m'
else
  C_RED=""; C_GREEN=""; C_BLUE=""; C_RESET=""
fi

# Logging in the Kubernetes hack/lib/logging.sh format:
#   +++ [MMDD HH:MM:SS] status line
#       indented continuation (4 spaces, no prefix)
#   !!! [MMDD HH:MM:SS] error line (stderr)
ts() { date +"[%m%d %H:%M:%S]"; }

info()      { printf '%s+++%s %s %s\n' "$C_BLUE" "$C_RESET" "$(ts)" "$*"; }
success()   { printf '%s+++%s %s %s\n' "$C_GREEN" "$C_RESET" "$(ts)" "$*"; }
# Continuation line under the current step (plain indentation, k8s-style).
detail()    { printf '    %s\n' "$*"; }
fmt_error() { printf '%s!!!%s %s %s\n' "$C_RED" "$C_RESET" "$(ts)" "$*" >&2; }

# ==========================================================
# Small utilities
# ==========================================================
check_cmd() { command -v "$1" >/dev/null 2>&1; }

need_cmd() {
  if ! check_cmd "$1"; then
    fmt_error "required command not found: $1"
    exit 1
  fi
}

# Run a command that must succeed, or abort with a clear message.
ensure() {
  if ! "$@"; then
    fmt_error "command failed: $*"
    exit 1
  fi
}

# Run an OPTIONAL step: if it fails, record it and keep going instead of
# aborting. A summary of failures is printed at the end. Use this for
# individual tools where one failure shouldn't sink the whole install.
# $1 = human label ; $2... = command
attempt() {
  local label="$1"; shift
  if ! "$@"; then
    fmt_error "step failed: $label (continuing)"
    FAILED_STEPS+=("$label")
  fi
  return 0
}

# Print a summary of optional steps that failed, if any.
report_failures() {
  if [[ "${#FAILED_STEPS[@]}" -gt 0 ]]; then
    fmt_error "Some optional steps failed: ${FAILED_STEPS[*]}"
    detail "The rest of the setup completed. You can re-run the script to retry."
  fi
}

has_gui() { [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; }

# Yes/no prompt that survives `curl | bash` by reading from /dev/tty.
# Non-interactive (no tty) or -y flag: returns "yes" so unattended
# installs are complete.
ask() {
  [[ "$ASSUME_YES" -eq 1 ]] && return 0
  [[ ! -t 1 || ! -e /dev/tty ]] && return 0
  local ans
  printf '%s+++%s %s %s [Y/n] ' "$C_BLUE" "$C_RESET" "$(ts)" "$1"
  read -r ans < /dev/tty || return 0
  [[ "$ans" =~ ^[Nn] ]] && return 1
  return 0
}

# Resolve a repo's latest release tag WITHOUT the GitHub API (no rate limit).
gh_latest_tag() {
  curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/$1/releases/latest" 2>/dev/null | sed -n 's#.*/tag/##p'
}

# Back up a real file (not a symlink) before replacing it with our symlink.
backup_if_real() {
  if [[ -e "$1" && ! -L "$1" ]]; then
    mv "$1" "$1.pre-dotfiles.bak"
    detail "Backed up existing $1 to $1.pre-dotfiles.bak"
  fi
}

# ==========================================================
# GitHub binary installer with a pluggable extraction step.
#   $1 = download URL
#   $2 = name of a function handling extraction; it receives the downloaded
#        file path as $1 and is responsible for installing the binary.
# The helper owns the common parts (download + cleanup); the callback owns
# the layout differences (single binary vs runtime dir, etc.).
# ==========================================================
fetch_and_install() {
  local url="$1" extract_fn="$2"
  local tmp; tmp="$(mktemp)"
  if ! curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o "$tmp" "$url"; then
    rm -f "$tmp"; return 1
  fi
  "$extract_fn" "$tmp" || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"
}

# Extraction callbacks ------------------------------------------------------
# All tools are installed user-local in ~/.local/bin (must be in PATH).
# Simple case: a .tar.gz containing a single binary.
# Uses $EXTRACT_BIN (set by caller) as the binary name inside the tarball.
# Callbacks return non-zero on failure so attempt() can record it.
extract_single_bin() {
  mkdir -p "$HOME/.local/bin"
  tar -C "$HOME/.local/bin" -xzf "$1" "$EXTRACT_BIN"
}

extract_helix() {
  # helix ships hx + a runtime dir that must live where hx looks for it.
  local dir="/tmp/helix-extract"
  rm -rf "$dir"; mkdir -p "$dir"
  tar -C "$dir" -xJf "$1" || return 1
  local hxdir="$dir/helix-${HELIX_TAG}-${ARCH_AARCH64}-linux"
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$hxdir/hx" "$HOME/.local/bin/hx" || return 1
  mkdir -p "$HOME/.config/helix"
  rm -rf "$HOME/.config/helix/runtime"
  cp -r "$hxdir/runtime" "$HOME/.config/helix/runtime"
  rm -rf "$dir"
}

# ==========================================================
# Detection / preflight
# ==========================================================
detect_env() {
  [[ -n "${TERMUX_VERSION:-}" ]] && IS_TERMUX=1
  command -v dnf >/dev/null 2>&1 && IS_RHEL=1

  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  ARCH_ARM64="x86_64"; ARCH_AARCH64="x86_64"; ARCH_GO="amd64" ;;
    aarch64) ARCH_ARM64="arm64";  ARCH_AARCH64="aarch64"; ARCH_GO="arm64" ;;
    *) fmt_error "Unsupported architecture: $ARCH (expected x86_64 or aarch64)"; exit 1 ;;
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
# Repo
# ==========================================================
clone_or_update_repo() {
  if [[ -d "$DOTFILES" ]]; then
    info "Updating dotfiles repo"
    ensure git -C "$DOTFILES" pull --rebase origin master
  else
    info "Cloning dotfiles repo"
    ensure git clone --depth=1 "$REPO" "$DOTFILES"
  fi
}

# ==========================================================
# Shared steps
# ==========================================================
clone_zsh_plugins() {
  mkdir -p "$HOME/.zsh/plugins"
  local p
  for p in zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
    [[ -d "$HOME/.zsh/plugins/$p" ]] || \
      ensure git clone --depth=1 "https://github.com/zsh-users/$p" "$HOME/.zsh/plugins/$p"
  done
}

# Symlink each file/dir from the repo's helix/ folder into ~/.config/helix/.
# The directory itself stays real so the helix runtime/ (installed by
# extract_helix or pkg) can live alongside without polluting the repo.
# -n: replace an existing symlink-to-dir instead of descending into it.
deploy_editor_configs() {
  mkdir -p "$HOME/.config/helix"
  local f
  for f in "$DOTFILES"/helix/*; do
    ln -sfn "$f" "$HOME/.config/helix/$(basename "$f")"
  done
}

deploy_common_symlinks() {
  backup_if_real "$HOME/.zshrc"
  ln -sf "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
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
    chsh -s "$(command -v zsh)" || \
      detail "Could not change shell automatically; run 'chsh -s zsh' manually."
  fi
}

# Language servers for Helix (Go + Bash).
# $1 = package manager for nodejs ("pkg" or "apt-get").
install_helix_lsp() {
  info "Installing Helix language servers"

  if check_cmd go && ! check_cmd gopls; then
    go install golang.org/x/tools/gopls@latest \
      || fmt_error "Failed to install gopls (continuing)"
  fi

  if ! check_cmd bash-language-server; then
    if check_cmd npm; then
      ensure npm install -g bash-language-server
    elif ask "bash-language-server requires Node.js. Install it?"; then
      case "$1" in
        pkg)     ensure pkg install -y nodejs ;;
        apt-get) ensure $SUDO apt-get install -y nodejs npm ;;
      esac
      ensure npm install -g bash-language-server
    else
      detail "Skipping bash-language-server (Node.js declined)."
    fi
  fi
}

# ==========================================================
# TERMUX branch
# ==========================================================
install_termux() {
  info "Termux detected — installing via pkg"

  if ask "Update system packages (pkg update/upgrade)?"; then
    ensure pkg update -y
    ensure pkg upgrade -y
  fi

  # Script prerequisites — installed without asking.
  ensure pkg install -y git curl unzip openssh

  # zsh and the CLI tools its config relies on, as one brick.
  if ask "Install zsh and its tools (fzf, eza, zoxide)?"; then
    attempt "zsh + tools" pkg install -y zsh fzf eza zoxide
  fi

  # One question per remaining tool; skipped if already installed.
  local entry pkgname cmd
  for entry in zellij:zellij starship:starship \
               golang:go helix:hx; do
    pkgname="${entry%%:*}"; cmd="${entry##*:}"
    if ! check_cmd "$cmd" && ask "Install $pkgname?"; then
      attempt "$pkgname" pkg install -y "$pkgname"
    fi
  done

  if check_cmd go && ! check_cmd sshm && ask "Install sshm?"; then
    attempt "sshm" go install github.com/Gu1llaum-3/sshm@latest
  fi

  # Persistent ssh-agent via termux-services (pairs with AddKeysToAgent).
  if ! check_cmd sv-enable && ask "Enable a persistent ssh-agent (termux-services)?"; then
    attempt "termux-services" pkg install -y termux-services
    if check_cmd sv-enable; then
      sv-enable ssh-agent 2>/dev/null \
        || detail "Restart Termux, then run: sv-enable ssh-agent"
    fi
  fi

  # Nerd Font: on Termux the font is an APP setting (~/.termux/font.ttf)
  if [[ ! -f "$HOME/.termux/font.ttf" ]] && ask "Install the Nerd Font?"; then
    mkdir -p "$HOME/.termux"
    attempt "Nerd Font" curl -fL --retry 3 --retry-all-errors -o "$HOME/.termux/font.ttf" \
      "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FiraCode/Regular/FiraCodeNerdFont-Regular.ttf"
    if [[ -f "$HOME/.termux/font.ttf" ]] && check_cmd termux-reload-settings; then
      termux-reload-settings
    fi
  fi

  if ask "Deploy zsh (plugins, .zshrc) and configs (helix, zellij)?"; then
    clone_zsh_plugins
    deploy_editor_configs
    deploy_common_symlinks
    set_default_shell
  fi

  if ask "Deploy the hardened SSH client config (config.d)?"; then
    setup_ssh
  fi

  if ask "Install Helix language servers (gopls, bash-ls)?"; then
    install_helix_lsp pkg
  fi

  report_failures
  success "Termux setup complete. Restart Termux to land in zsh."
}

# ==========================================================
# UBUNTU / glibc branch
# ==========================================================
install_apt_packages() {
  info "apt packages"

  if ask "Update system packages (apt update/upgrade)?"; then
    ensure $SUDO apt-get update -y
    $SUDO apt-get upgrade -y && $SUDO apt-get autoremove -y
  else
    # Package lists are still needed to install anything below.
    ensure $SUDO apt-get update -y
  fi

  # Script prerequisites — installed without asking.
  ensure $SUDO apt-get install -y curl git unzip

  # zsh and the CLI tools its config relies on, as one brick.
  if ask "Install zsh and its tools (fzf, eza, zoxide, keychain)?"; then
    attempt "zsh + tools" $SUDO apt-get install -y \
      zsh fzf eza zoxide keychain
  fi
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
  HELIX_TAG="$(gh_latest_tag helix-editor/helix)"
  [[ -n "$HELIX_TAG" ]] || { fmt_error "Failed to resolve helix version"; return 1; }
  fetch_and_install \
    "https://github.com/helix-editor/helix/releases/download/${HELIX_TAG}/helix-${HELIX_TAG}-${ARCH_AARCH64}-linux.tar.xz" \
    extract_helix
}

install_zellij_glibc() {
  check_cmd zellij && return 0
  EXTRACT_BIN=zellij fetch_and_install \
    "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${ARCH_AARCH64}-unknown-linux-musl.tar.gz" \
    extract_single_bin
}

install_sshm_glibc() {
  check_cmd sshm && return 0
  local tag; tag="$(gh_latest_tag Gu1llaum-3/sshm)"
  [[ -n "$tag" ]] || { fmt_error "Failed to resolve sshm version"; return 1; }
  EXTRACT_BIN=sshm fetch_and_install \
    "https://github.com/Gu1llaum-3/sshm/releases/download/${tag}/sshm_Linux_${ARCH_ARM64}.tar.gz" \
    extract_single_bin
}

# Go toolchain, user-local: ~/.local/go (add ~/.local/go/bin to PATH).
install_go_glibc() {
  check_cmd go && return 0
  local ver
  ver="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)"
  [[ -n "$ver" ]] || { fmt_error "Failed to resolve Go version"; return 1; }
  local tmp; tmp="$(mktemp)"
  if ! curl -fL --retry 3 --retry-delay 2 --retry-all-errors -o "$tmp" \
    "https://go.dev/dl/${ver}.linux-${ARCH_GO}.tar.gz"; then
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

install_ubuntu() {
  info "Ubuntu/glibc target"

  # Tools are installed user-local; make sure the directory exists.
  mkdir -p "$HOME/.local/bin"

  install_apt_packages

  if ! check_cmd go && ask "Install golang (~/.local/go)?"; then
    attempt "golang" install_go_glibc
  fi
  if ! check_cmd hx && ask "Install helix?"; then
    attempt "helix" install_helix_glibc
  fi
  if ! check_cmd zellij && ask "Install zellij?"; then
    attempt "zellij" install_zellij_glibc
  fi
  if ! check_cmd sshm && ask "Install sshm?"; then
    attempt "sshm" install_sshm_glibc
  fi
  if ! check_cmd starship && ask "Install starship?"; then
    attempt "starship" install_starship_glibc
  fi
  if has_gui; then
    if ! check_cmd alacritty && ask "Install alacritty?"; then
      attempt "alacritty" install_alacritty_gui
    fi
    if ask "Install the Nerd Font?"; then
      attempt "Nerd Font" install_nerd_font_gui
    fi
  fi

  if ask "Deploy zsh (plugins, .zshrc) and configs (helix, zellij, alacritty)?"; then
    clone_zsh_plugins
    deploy_editor_configs
    deploy_common_symlinks
    deploy_alacritty_config
    set_default_shell
  fi

  if ask "Deploy the hardened SSH client config (config.d)?"; then
    setup_ssh
  fi

  if ask "Install Helix language servers (gopls, bash-ls)?"; then
    install_helix_lsp apt-get
  fi

  report_failures
  success "Ubuntu setup complete."
}

# ==========================================================
# ROCKY / RHEL-family branch (SSH bastion: hardening only)
# No zsh, no tools — this host is only a ProxyJump relay.
# Deploys ssh/sshd_hardening.conf into /etc/ssh/sshd_config.d/
# with a lockout guard and config validation before restart.
# ==========================================================
bootstrap_rhel() {
  check_cmd git || ensure $SUDO dnf -y install git
}

install_rhel_bastion() {
  info "Rocky/RHEL-family target — SSH bastion"

  if ask "Update system packages (dnf update)?"; then
    ensure $SUDO dnf -y update
  fi

  if ! ask "Apply sshd hardening (keys only, no root)?"; then
    detail "sshd hardening skipped."
    report_failures
    return 0
  fi

  # Lockout guard: never disable password auth without a working key.
  if [[ ! -s "$HOME/.ssh/authorized_keys" ]]; then
    fmt_error "No ~/.ssh/authorized_keys found."
    fmt_error "Add your public key first or you will lock yourself out."
    exit 1
  fi

  # Copy (not symlink): /etc must not depend on a file in \$HOME.
  ensure $SUDO install -m 600 -o root -g root \
    "$DOTFILES/ssh/sshd_hardening.conf" \
    /etc/ssh/sshd_config.d/00-hardening.conf

  # Validate before restarting; roll back if the config is broken.
  if $SUDO sshd -t; then
    ensure $SUDO systemctl restart sshd
    success "sshd hardened. Test a NEW connection before closing this one."
  else
    $SUDO rm -f /etc/ssh/sshd_config.d/00-hardening.conf
    fmt_error "sshd config validation failed — hardening removed, sshd untouched."
    exit 1
  fi

  report_failures
  success "Bastion setup complete."
}

# ==========================================================
# Main
# ==========================================================
usage() {
  cat <<'EOF'
Usage: install.sh [target] [-y]

  target     force the install branch instead of auto-detecting:
               ubuntu   apt-based desktop/server setup
               termux   Termux/Android setup
               rhel     Rocky/RHEL bastion (sshd hardening)
  -y, --yes  answer yes to every prompt (unattended install)
EOF
}

main() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -y|--yes)          ASSUME_YES=1 ;;
      ubuntu|termux|rhel) TARGET="$arg" ;;
      -h|--help)         usage; exit 0 ;;
      *) fmt_error "unknown option: $arg"; usage; exit 1 ;;
    esac
  done

  detect_env

  # Forced target overrides detection (proot, containers, testing...).
  case "$TARGET" in
    termux) IS_TERMUX=1; IS_RHEL=0 ;;
    rhel)   IS_TERMUX=0; IS_RHEL=1 ;;
    ubuntu) IS_TERMUX=0; IS_RHEL=0 ;;
  esac
  [[ -n "$TARGET" ]] && detail "Forced target: $TARGET"

  [[ "$IS_RHEL" -eq 1 ]] && bootstrap_rhel
  preflight
  clone_or_update_repo

  if [[ "$IS_TERMUX" -eq 1 ]]; then
    install_termux
  elif [[ "$IS_RHEL" -eq 1 ]]; then
    install_rhel_bastion
  else
    install_ubuntu
  fi
}

main "$@"
