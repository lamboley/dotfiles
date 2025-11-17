if status is-interactive
and not set -q TMUX
    exec tmux
end

set fish_greeting ""

alias ll "ls -l"
alias vim "nvim"

starship init fish | source
