# fish_add_path is idempotent, so nested shells do not stack duplicates the
# way three unconditional `set -gx PATH ... $PATH` lines did. -g keeps this
# global rather than universal, so config.fish stays the single source of
# truth instead of state leaking into fish_variables.
fish_add_path -g $HOME/.local/go/bin $HOME/go/bin $HOME/.local/bin $HOME/bin

set -gx COLORTERM truecolor

set -gx EDITOR nvim
set -gx VISUAL nvim

if status is-interactive
    set -g fish_greeting ""

    # Ctrl-S/Ctrl-Q servent au controle de flux (XOFF/XON) par defaut, ce qui
    # gele le terminal au lieu de transmettre la touche a nvim.
    stty -ixon

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

