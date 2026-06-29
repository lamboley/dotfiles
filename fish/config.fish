set -gx PATH $HOME/bin $PATH
set -gx PATH $HOME/.local/bin $PATH
set -gx PATH $HOME/.local/go/bin $HOME/go/bin $PATH

set -gx COLORTERM truecolor

set -gx EDITOR nvim
set -gx VISUAL nvim

if status is-interactive
    set -g fish_greeting ""

    alias ll='ls -la'
    alias lt='ls -lrt'
    alias mkdir='mkdir -p'
    alias grep='grep --color=auto'
    alias sshm='sshm -c ~/.ssh/config'
    alias g git
    alias lg lazygit
    alias c claude

    # Agent SSH avec Keychain
    if command -q keychain
        keychain --quiet
        set -l kf $HOME/.keychain/(hostname)-fish
        test -e $kf; and source $kf
    end

    # Agent SSH pour Termux
    if set -q PREFIX; and test -S $PREFIX/var/run/ssh-agent.socket
        set -gx SSH_AUTH_SOCK $PREFIX/var/run/ssh-agent.socket
    end
end

