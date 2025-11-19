set -U fish_greeting

alias .. "cd .."
alias ... "cd ../.."

alias mkdir "mkdir -p"

alias grep "grep --color=auto"

alias ls='ls --color=auto -l'
alias ll "ls -l"

alias vim "nvim"

alias sudo "sudo "

starship init fish | source
