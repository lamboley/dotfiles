set -gx PATH $HOME/.local/bin $HOME/.local/go/bin $HOME/go/bin $PATH

# Helix et zellij ne détectent le truecolor que via COLORTERM.
set -gx COLORTERM truecolor

set -gx EDITOR hx
set -gx VISUAL hx

# fix: Le Helix provenant des paquets Termux ne trouve pas le dossier runtime.
if set -q PREFIX; and test -d $PREFIX/opt/helix/runtime
    set -gx HELIX_RUNTIME $PREFIX/opt/helix/runtime
end

# Socket ssh-agent pour Termux.
if set -q PREFIX; and test -S $PREFIX/var/run/ssh-agent.socket
    set -gx SSH_AUTH_SOCK $PREFIX/var/run/ssh-agent.socket
end

if status is-interactive
    set -g fish_greeting ""

    if command -q keychain
        keychain --quiet
        set -l kf $HOME/.keychain/(hostname)-fish
        test -e $kf; and source $kf
    end

    alias mkdir='mkdir -p'
    alias grep='grep --color=auto'
    alias sshm='sshm -c ~/.ssh/config'

    alias ll='ls -la'
    alias lt='ls -lrt'
end
