alias sshm='sshm -c ~/.ssh/config'

alias mkdir='mkdir -p'
alias grep='grep --color=auto'

# eza : seulement si présent, sinon ls/ll/tree restent les commandes standard
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons'
  alias ll='eza -la --icons --git'
  alias tree='eza --tree --icons'
else
  alias ll='ls -la'
fi

# Le trailing space fait que le mot suivant est aussi expansé en alias
alias sudo='sudo '
