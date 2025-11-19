# Author: Lucas Lamboley

set -qU XDG_CONFIG_HOME; or set -Ux XDG_CONFIG_HOME $HOME/.config

source $XDG_CONFIG_HOME/fish/main.fish
source $XDG_CONFIG_HOME/fish/aliases.fish

starship init fish | source
