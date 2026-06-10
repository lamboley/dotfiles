# ~/.zshrc — no framework, prompt via starship

# --- PATH ---
export PATH="$HOME/.local/bin:$HOME/.local/go/bin:$HOME/go/bin:$PATH"

# --- zellij: auto-start, one persistent session reattached ---
if command -v zellij >/dev/null 2>&1 \
  && [ -z "${ZELLIJ:-}" ] && [ -z "${SSH_CONNECTION:-}" ] && [ -t 1 ]; then
  zellij attach -c main
fi

# --- Helix runtime (Termux: the package puts it in opt/, hx cannot find it alone) ---
[ -d "$PREFIX/opt/helix/runtime" ] && export HELIX_RUNTIME="$PREFIX/opt/helix/runtime"

# --- History ---
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY

# --- zsh-completions: must be in fpath BEFORE compinit ---
[ -d "$HOME/.zsh/plugins/zsh-completions/src" ] && \
  fpath=("$HOME/.zsh/plugins/zsh-completions/src" $fpath)

# --- Completion ---
autoload -Uz compinit
# -C: use the cache without re-auditing permissions on every startup
compinit -C
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# --- Personal aliases & functions ---
[ -f "$HOME/.dotfiles/zsh/functions.zsh" ] && source "$HOME/.dotfiles/zsh/functions.zsh"
[ -f "$HOME/.dotfiles/zsh/aliases.zsh" ]   && source "$HOME/.dotfiles/zsh/aliases.zsh"

# --- keychain ---
if ! grep -qi proot /proc/version 2>/dev/null && command -v keychain >/dev/null 2>&1; then
  eval "$(keychain --eval --quiet --agents ssh)"
fi

# --- ssh-agent (termux-services) ---
[ -S "$PREFIX/var/run/ssh-agent.socket" ] && \
  export SSH_AUTH_SOCK="$PREFIX/var/run/ssh-agent.socket"

# --- fzf: keybindings + completion (Ctrl+R, Ctrl+T, Alt+C) ---
# `fzf --zsh` needs fzf >= 0.48; Ubuntu LTS ships an older one, so fall
# back to the scripts shipped with the distro package.
if command -v fzf >/dev/null 2>&1; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    for f in /usr/share/doc/fzf/examples/key-bindings.zsh \
             /usr/share/doc/fzf/examples/completion.zsh; do
      [ -f "$f" ] && source "$f"
    done
    unset f
  fi
fi

# --- Plugins ---
for d in \
  "$PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "$HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"; do
  [ -f "$d" ] && { source "$d"; break; }
done

# --- zoxide: smarter cd (z / zi) — after compinit, before syntax-highlighting ---
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# zsh-syntax-highlighting MUST be sourced last
for d in \
  "$PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "$HOME/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
  [ -f "$d" ] && { source "$d"; break; }
done

# --- Prompt (starship, at the very bottom) ---
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
