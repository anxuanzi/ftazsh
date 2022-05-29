################# DO NOT MODIFY THIS FILE #######################
####### PLACE YOUR CONFIGS IN ~/.config/ftazsh/zshrc FOLDER #######
#################################################################

# This file is created by ftazsh setup.
# Place all your .zshrc configurations / overrides in a single or multiple files under ~/.config/ftazsh/zshrc/ folder
# Your original .zshrc is backed up at ~/.zshrc-backup-%y-%m-%d


# Load ftazsh configurations
source "$HOME/.config/ftazsh/ftazshrc.zsh"

# Any zshrc configurations under the folder ~/.config/ftazsh/zshrc/ will override the default ftazsh configs.
# Place all of your personal configurations over there
ZSH_CONFIGS_DIR="$HOME/.config/ftazsh/zshrc"

if [ "$(ls -A $ZSH_CONFIGS_DIR)" ]; then
    for file in "$ZSH_CONFIGS_DIR"/*; do
        source "$file"
    done
fi

# Now source oh-my-zsh.sh so that any plugins added in ~/.config/ftazsh/zshrc/* files also get loaded
source $ZSH/oh-my-zsh.sh


# Configs that can only work after "source $ZSH/oh-my-zsh.sh", such as Aliases that depend oh-my-zsh plugins

# Now source fzf.zsh , otherwise Ctr+r is overwritten by ohmyzsh
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPS="--extended"

alias k="k -h"       # show human readable file sizes, in kb, mb etc
