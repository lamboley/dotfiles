# Proot (Termux/Android): Rust temp_dir() résout vers un chemin hors rootfs,
# ce qui fait planter Zellij (atomic_create_dir sur ZELLIJ_TMP_DIR).
# On force TMPDIR vers un dossier garanti présent dans le rootfs.
if grep -qi proot /proc/version 2>/dev/null; then
  export TMPDIR="$HOME/.zellij-tmp"
  mkdir -p "$TMPDIR"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# History search with up/down arrows.
# Binds both normal (^[[A) and application (^[OA) cursor sequences so it works
# inside Zellij/tmux as well as in a bare terminal.
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

source "$HOME/.dotfiles/zsh/functions.zsh"
source "$HOME/.dotfiles/zsh/aliases.zsh"
export PATH="$HOME/.local/bin:$PATH"

eval "$(keychain --eval --quiet --agents ssh)"
