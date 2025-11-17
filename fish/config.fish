if status is-interactive
and not set -q TMUX
    tmux new-session -A -s main
end

set fish_greeting ""

alias ll "ls -l"

starship init fish | source
