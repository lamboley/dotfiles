if status is-interactive
and not set -q TMUX
    exec tmux
end

set fish_greeting ""

alias ll "ls -l"

starship init fish | source
