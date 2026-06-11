alias sshm='sshm -c ~/.ssh/config'

alias mkdir='mkdir -p'
alias grep='grep --color=auto'

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons'
  alias ll='eza -la --icons --git'
  alias lt='eza -la --icons --sort newest'   # ls -lrt equivalent
  alias tree='eza --tree --icons'
else
  alias ll='ls -la'
  alias lt='ls -lrt'
fi

alias sudo='sudo '
