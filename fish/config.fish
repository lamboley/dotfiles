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

    # Thème tide (prompt) — Catppuccin Mocha (blocs surface1 + texte vif)
    set -g tide_pwd_bg_color 45475a
    set -g tide_pwd_color_dirs 89dceb
    set -g tide_pwd_color_anchors cdd6f4
    set -g tide_pwd_color_truncated_dirs 6c7086
    set -g tide_git_bg_color 45475a
    set -g tide_git_bg_color_unstable 45475a
    set -g tide_git_bg_color_urgent 45475a
    set -g tide_git_color_branch cba6f7
    set -g tide_git_color_dirty f9e2af
    set -g tide_git_color_staged a6e3a1
    set -g tide_git_color_untracked f5c2e7
    set -g tide_git_color_conflicted f38ba8
    set -g tide_git_color_operation fab387
    set -g tide_git_color_stash 94e2d5
    set -g tide_git_color_upstream 6c7086
    set -g tide_character_color a6e3a1
    set -g tide_character_color_failure f38ba8
    set -g tide_status_bg_color 45475a
    set -g tide_status_color a6e3a1
    set -g tide_status_bg_color_failure 45475a
    set -g tide_status_color_failure f38ba8

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
