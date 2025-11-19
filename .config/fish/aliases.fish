# Author: Lucas Lamboley

# Add current directory to path
alias add-to-path 'set -U fish_user_paths (pwd) $fish_user_paths'

# Human readable sizes for `df`, `du`, `free`
alias df 'df -h'
alias du 'du -ch'
alias free 'free -m'

alias .. "cd .."
alias ... "cd ../.."

alias mkdir "mkdir -p"

alias grep "grep --color=auto"

alias vim "nvim"

alias sudo "sudo "

function ll --description "Scroll ll if theres more files that fit on screen"
    ls -l $argv --color=always | less -R -X -F
end

