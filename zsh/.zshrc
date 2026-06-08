# ~/.zshrc — sans framework, prompt via starship

# --- PATH ---
export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"

# --- Historique ---
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY

# --- zsh-completions : doit être dans le fpath AVANT compinit ---
[ -d "$HOME/.zsh/plugins/zsh-completions/src" ] && \
  fpath=("$HOME/.zsh/plugins/zsh-completions/src" $fpath)

# --- Complétion ---
autoload -Uz compinit
# -C : utilise le cache sans re-auditer les permissions à chaque démarrage
compinit -C
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# --- Aliases & fonctions perso ---
[ -f "$HOME/.dotfiles/zsh/functions.zsh" ] && source "$HOME/.dotfiles/zsh/functions.zsh"
[ -f "$HOME/.dotfiles/zsh/aliases.zsh" ]   && source "$HOME/.dotfiles/zsh/aliases.zsh"

# --- keychain ---
if ! grep -qi proot /proc/version 2>/dev/null && command -v keychain >/dev/null 2>&1; then
  eval "$(keychain --eval --quiet --agents ssh)"
fi

# --- fzf : keybindings + completion (Ctrl+R, Ctrl+T, Alt+C) ---
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh) 2>/dev/null

# --- Plugins ---
for d in \
  "$PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "$HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"; do
  [ -f "$d" ] && { source "$d"; break; }
done

# --- zoxide : smarter cd (z / zi) — après compinit, avant syntax-highlighting ---
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# zsh-syntax-highlighting DOIT être sourcé en dernier
for d in \
  "$PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "$HOME/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
  [ -f "$d" ] && { source "$d"; break; }
done

# --- Prompt (starship, tout en bas) ---
eval "$(starship init zsh)"
