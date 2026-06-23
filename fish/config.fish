# config.fish

# PATH (prepend de nos emplacements user-local).
set -gx PATH $HOME/.local/bin $HOME/.local/go/bin $HOME/go/bin $PATH

# Runtime Helix pour Termux.
if set -q PREFIX; and test -d $PREFIX/opt/helix/runtime
    set -gx HELIX_RUNTIME $PREFIX/opt/helix/runtime
end

# Socket ssh-agent pour Termux.
if set -q PREFIX; and test -S $PREFIX/var/run/ssh-agent.socket
    set -gx SSH_AUTH_SOCK $PREFIX/var/run/ssh-agent.socket
end

if status is-interactive
    # Démarre keychain (clés à la demande : keychain-add). On source le
    # fichier fish que keychain génère (~/.keychain/<host>-fish).
    if command -q keychain; and not grep -qi proot /proc/version 2>/dev/null
        keychain --quiet
        set -l kf $HOME/.keychain/(hostname)-fish
        test -e $kf; and source $kf
    end

    # Alias.
    alias mkdir='mkdir -p'
    alias grep='grep --color=auto'
    alias sshm='sshm -c ~/.ssh/config'

    if command -q eza
        alias ls='eza --icons'
        alias ll='eza -la --icons --git'
        alias lt='eza -la --icons --sort newest'
        alias tree='eza --tree --icons'
    else
        alias ll='ls -la'
        alias lt='ls -lrt'
    end
end

# Note : autosuggestions / coloration / complétion sont NATIVES dans fish.
# Prompt (tide), fuzzy-find (fzf.fish), saut de dossier (z) = plugins fisher.
