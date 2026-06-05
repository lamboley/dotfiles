# Éditeur
alias vim='nvim'

# sshs : ne lister que TES hôtes (sinon il ajoute /etc/ssh → .host, machine/.host de systemd)
alias sshs='sshs --config ~/.ssh/config'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias p='cd ~/projects'

# Fichiers
alias mkdir='mkdir -p'
alias ls='eza --icons'
alias ll='eza -la --icons --git'
alias pll='pwd && ll'
alias tree='eza --tree --icons'
alias grep='grep --color=auto'

# Docker
alias dk='docker'
alias dkps='docker ps -a'
alias dkr='docker run'
alias dki='docker images'
alias dks='docker service'

# Git
alias gitt='git tag'
alias gitpt='git push --tags'

# Outils
alias tf='terraform'
alias ngt='nginx -t'

# L'espace final permet d'utiliser un alias juste après sudo / watch
alias sudo='sudo '
alias watch='watch '
