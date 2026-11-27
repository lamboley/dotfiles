fish_add_path -g /usr/local/go/bin $HOME/.local/go/bin $HOME/go/bin $HOME/.local/bin $HOME/bin

set -gx COLORTERM truecolor

set -gx EDITOR emacs
set -gx VISUAL emacs

if status is-interactive
    set -g fish_greeting ""

    stty -ixon

    alias ll 'ls -l'
    alias lla 'ls -la'
    alias llt 'ls -lrt'
    alias mkdir 'mkdir -p'
    alias grep 'grep --color=auto'
    alias sshm 'sshm -c ~/.ssh/config'
    alias g git
    alias lg lazygit
    alias c claude
    alias d docker
    alias vim nvim
    alias e 'emacs -nw .'
    alias gmt 'go mod tidy'
    alias gmv 'go mod verify'
    alias gl 'golangci-lint'
    alias glf 'golangci-lint fmt'
    alias glr 'golangci-lint run'
    alias m make

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
