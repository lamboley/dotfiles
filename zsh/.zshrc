export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

source "$HOME/.dotfiles/zsh/functions.zsh"
export PATH="$HOME/.local/bin:$PATH"
