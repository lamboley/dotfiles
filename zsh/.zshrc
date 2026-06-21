# Configure le PATH
typeset -U path PATH
export PATH="$HOME/.local/bin:$HOME/.local/go/bin:$HOME/go/bin:$PATH"

# Configure le runtime de `Helix` pour `Termux`
if [ -n "${PREFIX:-}" ] && [ -d "$PREFIX/opt/helix/runtime" ]; then
  export HELIX_RUNTIME="$PREFIX/opt/helix/runtime"
fi

# Charge le plugin `zsh-completions`
[ -d "$HOME/.zsh/plugins/zsh-completions/src" ] && \
  fpath=("$HOME/.zsh/plugins/zsh-completions/src" $fpath)

# Configure le plugin `zsh-completions`
autoload -Uz compinit
compinit -C # -C: Skip l'audit de sécurité
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Charge ma config zsh
[ -f "$HOME/.dotfiles/zsh/functions.zsh" ] && source "$HOME/.dotfiles/zsh/functions.zsh"
[ -f "$HOME/.dotfiles/zsh/aliases.zsh" ]   && source "$HOME/.dotfiles/zsh/aliases.zsh"

# Démarre keychain (les clés se chargent à la demande : keychain-add)
if ! grep -qi proot /proc/version 2>/dev/null && command -v keychain >/dev/null 2>&1; then
  eval "$(keychain --eval --quiet --agents ssh)"
fi

# Configure ssh agent socket pour `Termux`
if [ -n "${PREFIX:-}" ] && [ -S "$PREFIX/var/run/ssh-agent.socket" ]; then
  export SSH_AUTH_SOCK="$PREFIX/var/run/ssh-agent.socket"
fi

# Charge `fzf`
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

# Charge le plugin `zsh-autosuggestions`
for d in \
  "${PREFIX:-}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "$HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"; do
  [ -f "$d" ] && { source "$d"; break; }
done

# Charge `zoxide`
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# Charge le plugin `zsh-syntax-highlighting`
for d in \
  "${PREFIX:-}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "$HOME/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
  [ -f "$d" ] && { source "$d"; break; }
done
unset d

# Charge `starship`
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
