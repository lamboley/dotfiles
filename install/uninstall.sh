#!/usr/bin/env bash
#
# Dotfiles uninstaller for lamboley/dotfiles.
# Modeled on Homebrew's uninstall.sh: build the removal list first,
# show exactly what will happen, confirm once, then keep going on
# individual failures and report them at the end.
#
# Removes: symlinks pointing into ~/.dotfiles (restoring *.pre-dotfiles.bak
# backups), deployed configs, zsh plugins, user-local tools installed by
# tools/install.sh, and optionally the repo itself.
# Never removes system packages (apt/pkg/dnf) — they are listed at the end.
#
set -u

DOTFILES="$HOME/.dotfiles"

# ==========================================================
# Logging (same Kubernetes-style format as install.sh)
# ==========================================================
ts() { date +"[%m%d %H:%M:%S]"; }
info()      { printf '+++ %s %s\n' "$(ts)" "$*"; }
detail()    { printf '    %s\n' "$*"; }
fmt_error() { printf '!!! %s %s\n' "$(ts)" "$*" >&2; }

abort() {
  fmt_error "$@"
  exit 1
}

# ==========================================================
# Options (brew-style)
# ==========================================================
opt_force=""
opt_quiet=""
opt_dry_run=""
opt_keep_repo=""
opt_skip_caches=""

# Global status: did any individual step fail?
failed=false

usage() {
  cat <<EOS
Dotfiles Uninstaller
Usage: [NONINTERACTIVE=1] $0 [options]
    -f, --force      Uninstall without prompting (implied by NONINTERACTIVE).
    -q, --quiet      Suppress informational output.
    -n, --dry-run    Show what would be removed without removing anything.
    --keep-repo      Keep the ~/.dotfiles repository itself.
    --skip-caches    Skip removal of tool caches (~/.cache/uv, ~/.cache/go-build).
    -h, --help       Display this message.
EOS
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f | --force)   opt_force=1 ;;
    -q | --quiet)   opt_quiet=1 ;;
    -n | --dry-run) opt_dry_run=1 ;;
    --keep-repo)    opt_keep_repo=1 ;;
    --skip-caches)  opt_skip_caches=1 ;;
    -h | --help)    usage ;;
    *)
      fmt_error "Unrecognized option: '$1'"
      usage 1
      ;;
  esac
  shift
done

say() { [[ -n "${opt_quiet}" ]] || info "$@"; }

# Run a step; on failure, record it and keep going (brew's `system`).
system() {
  if ! "$@"; then
    fmt_error "Failed during: $*"
    failed=true
  fi
}

# ==========================================================
# Discovery: build the removal list FIRST (brew-style)
# ==========================================================
# A symlink is ours only if it points into the dotfiles repo. This is the
# safety net: a .zshrc the user wrote themselves is never touched.
is_repo_link() {
  [[ -L "$1" && "$(readlink "$1")" == "${DOTFILES}"/* ]]
}

# Pretty print: resolve symlinks, mark directories (brew-style).
pretty_print_pathnames() {
  local p
  for p in "$@"; do
    if [[ -L "${p}" ]]; then
      printf '%s -> %s\n' "${p}" "$(readlink "${p}")"
    elif [[ -d "${p}" ]]; then
      echo "${p}/"
    else
      echo "${p}"
    fi
  done
}

# Symlinks deployed by install.sh (only kept if they point into the repo).
link_candidates=(
  "$HOME/.zshrc"
  "$HOME/.config/zellij/config.kdl"
  "$HOME/.config/alacritty/alacritty.toml"
  "$HOME/.ssh/config"
  "$HOME/.ssh/hardening.conf"
)
if [[ -d "$HOME/.config/helix" ]]; then
  for p in "$HOME/.config/helix"/*; do
    link_candidates+=("${p}")
  done
fi

links=()
backups=()
for p in "${link_candidates[@]}"; do
  if is_repo_link "${p}"; then
    links+=("${p}")
    [[ -e "${p}.pre-dotfiles.bak" ]] && backups+=("${p}.pre-dotfiles.bak")
  fi
done

# Plain files/directories created by install.sh.
plain_candidates=(
  "$HOME/.config/helix/runtime"
  "$HOME/.zsh/plugins/zsh-autosuggestions"
  "$HOME/.zsh/plugins/zsh-syntax-highlighting"
  "$HOME/.zsh/plugins/zsh-completions"
  "$HOME/.ssh/config.d/00-example.conf"
  "$HOME/.ssh/cm"
  "$HOME/.termux/font.ttf"
  "$HOME/.local/go"
  "$HOME/.local/share/uv"
)
# User-local binaries installed by install.sh (never system packages).
for t in hx zellij sshm starship shellcheck golangci-lint uv uvx pre-commit; do
  plain_candidates+=("$HOME/.local/bin/${t}")
done
# Go-installed binaries (only ours; ~/go may contain the user's own code).
plain_candidates+=("$HOME/go/bin/gopls" "$HOME/go/bin/sshm")
if [[ -z "${opt_skip_caches}" ]]; then
  plain_candidates+=("$HOME/.cache/uv" "$HOME/.cache/go-build")
fi

plain=()
for p in "${plain_candidates[@]}"; do
  [[ -e "${p}" || -L "${p}" ]] && plain+=("${p}")
done

# Root-owned bastion drop-in (removed with sudo, sshd restarted after).
sshd_dropin="/etc/ssh/sshd_config.d/00-hardening.conf"
remove_dropin=""
[[ -e "${sshd_dropin}" ]] && remove_dropin=1

# The repo itself, unless --keep-repo.
remove_repo=""
if [[ -z "${opt_keep_repo}" && -d "${DOTFILES}" ]]; then
  remove_repo=1
fi

# ==========================================================
# Announce and confirm (brew-style: list everything, one question)
# ==========================================================
if [[ "${#links[@]}" -eq 0 && "${#plain[@]}" -eq 0 \
  && -z "${remove_dropin}" && -z "${remove_repo}" ]]; then
  say "Nothing to uninstall."
  exit 0
fi

if [[ -z "${opt_quiet}" ]]; then
  dry_str="${opt_dry_run:+would}"
  info "This script ${dry_str:-will} remove:"
  pretty_print_pathnames "${links[@]}" "${plain[@]}"
  [[ -n "${remove_dropin}" ]] && echo "${sshd_dropin} (sudo, sshd will be restarted)"
  [[ -n "${remove_repo}" ]] && echo "${DOTFILES}/"
  if [[ "${#backups[@]}" -gt 0 ]]; then
    info "and restore these backups:"
    pretty_print_pathnames "${backups[@]}"
  fi
fi

# shellcheck disable=SC2016
if [[ -n "${NONINTERACTIVE-}" ]]; then
  say 'Running in non-interactive mode because `$NONINTERACTIVE` is set.'
  opt_force=1
fi

if [[ -t 0 && -z "${opt_force}" && -z "${opt_dry_run}" ]]; then
  read -rp "Are you sure you want to uninstall the dotfiles? [y/N] "
  [[ "${REPLY}" == [yY]* ]] || abort "Aborted."
fi

# Refuse to delete a repo with unsaved work unless forced.
if [[ -n "${remove_repo}" && -z "${opt_dry_run}" && -z "${opt_force}" ]]; then
  if ! git -C "${DOTFILES}" diff --quiet 2>/dev/null \
    || ! git -C "${DOTFILES}" diff --cached --quiet 2>/dev/null \
    || [[ -n "$(git -C "${DOTFILES}" log --branches --not --remotes 2>/dev/null)" ]]; then
    abort "Uncommitted or unpushed work in ${DOTFILES}. Push it or re-run with --force."
  fi
fi

# ==========================================================
# Removal
# ==========================================================
say "Removing dotfiles symlinks..."
for p in "${links[@]}"; do
  if [[ -n "${opt_dry_run}" ]]; then
    echo "Would unlink ${p}"
  else
    system rm -f "${p}"
    # Restore the pre-dotfiles file if we backed one up.
    if [[ -e "${p}.pre-dotfiles.bak" ]]; then
      system mv "${p}.pre-dotfiles.bak" "${p}"
      say "Restored ${p} from backup"
    fi
  fi
done

say "Removing deployed files and user-local tools..."
for p in "${plain[@]}"; do
  if [[ -n "${opt_dry_run}" ]]; then
    echo "Would delete ${p}"
  else
    if ! err="$(rm -fr "${p}" 2>&1)"; then
      fmt_error "Failed to delete ${p}"
      echo "${err}"
      failed=true
    fi
  fi
done

# bash-language-server was installed through npm -g.
if command -v npm >/dev/null 2>&1 \
  && npm ls -g bash-language-server >/dev/null 2>&1; then
  if [[ -n "${opt_dry_run}" ]]; then
    echo "Would run: npm uninstall -g bash-language-server"
  else
    system npm uninstall -g bash-language-server
  fi
fi

# Termux: disable the ssh-agent service (termux-services itself is kept).
if command -v sv-disable >/dev/null 2>&1; then
  if [[ -n "${opt_dry_run}" ]]; then
    echo "Would run: sv-disable ssh-agent"
  else
    sv-disable ssh-agent 2>/dev/null || true
  fi
fi

# Bastion: remove the sshd hardening drop-in and restart sshd.
if [[ -n "${remove_dropin}" ]]; then
  if [[ -n "${opt_dry_run}" ]]; then
    echo "Would delete ${sshd_dropin} and restart sshd"
  else
    say "Removing sshd hardening (this re-enables the distro defaults)..."
    system sudo rm -f "${sshd_dropin}"
    if sudo sshd -t 2>/dev/null; then
      system sudo systemctl restart sshd
    else
      fmt_error "sshd config invalid after removal; sshd NOT restarted."
      failed=true
    fi
  fi
fi

# The repository, last.
if [[ -n "${remove_repo}" ]]; then
  if [[ -n "${opt_dry_run}" ]]; then
    echo "Would delete ${DOTFILES}"
  else
    if ! err="$(rm -fr "${DOTFILES}" 2>&1)"; then
      fmt_error "Failed to delete ${DOTFILES}"
      echo "${err}"
      failed=true
    fi
  fi
fi

[[ -n "${opt_dry_run}" ]] && exit 0

# ==========================================================
# Report (brew-style: partial-failure status + residuals)
# ==========================================================
if [[ -z "${opt_quiet}" ]]; then
  if [[ "${failed}" == true ]]; then
    fmt_error "Dotfiles partially uninstalled (some steps failed)."
    detail "Review the errors above and re-run this script to retry."
  else
    info "Dotfiles uninstalled."
  fi

  detail "Not removed (system packages): zsh, fzf, eza, zoxide, keychain,"
  detail "git, curl, unzip and anything installed via apt/pkg/dnf."
  if [[ "$(basename "${SHELL:-}")" == "zsh" ]]; then
    detail "Your login shell is still zsh; run 'chsh -s /bin/bash' to revert."
  fi
fi

[[ "${failed}" != true ]]
