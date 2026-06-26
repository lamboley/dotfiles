set -gx PATH $HOME/bin $PATH
set -gx PATH $HOME/.local/bin $PATH
set -gx PATH $HOME/.local/go/bin $HOME/go/bin $PATH

set -gx COLORTERM truecolor

set -gx EDITOR nvim
set -gx VISUAL nvim

if status is-interactive
    # Supprime le message de bienvenu
    set -g fish_greeting ""

    # Alias
    alias ll='ls -la'
    alias lt='ls -lrt'
    alias mkdir='mkdir -p'
    alias grep='grep --color=auto'
    alias sshm='sshm -c ~/.ssh/config'
    alias g git
    alias c claude

    # Thème tide (prompt) — dracula (blocs current-line + texte vif)
    set -g tide_pwd_bg_color 44475a
    set -g tide_pwd_color_dirs 8be9fd
    set -g tide_pwd_color_anchors f8f8f2
    set -g tide_pwd_color_truncated_dirs 6272a4
    set -g tide_git_bg_color 44475a
    set -g tide_git_bg_color_unstable 44475a
    set -g tide_git_bg_color_urgent 44475a
    set -g tide_git_color_branch bd93f9
    set -g tide_git_color_dirty f1fa8c
    set -g tide_git_color_staged 50fa7b
    set -g tide_git_color_untracked ff79c6
    set -g tide_git_color_conflicted ff5555
    set -g tide_git_color_operation ffb86c
    set -g tide_git_color_stash 8be9fd
    set -g tide_git_color_upstream 6272a4
    set -g tide_character_color 50fa7b
    set -g tide_character_color_failure ff5555
    set -g tide_status_bg_color 44475a
    set -g tide_status_color 50fa7b
    set -g tide_status_bg_color_failure 44475a
    set -g tide_status_color_failure ff5555

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
