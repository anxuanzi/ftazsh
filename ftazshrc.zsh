# ftazshrc.zsh - Main configuration file for ftazsh
# This file contains the core settings for the ftazsh framework

#------------------------------------------------------------------------------
# TERMINAL SETTINGS
#------------------------------------------------------------------------------
export TERM="xterm-256color"

#------------------------------------------------------------------------------
# OH MY ZSH CONFIGURATION
#------------------------------------------------------------------------------
# Path to your oh-my-zsh installation
export ZSH=$HOME/.config/ftazsh/oh-my-zsh

# Theme configuration
ZSH_THEME="powerlevel10k/powerlevel10k"

#------------------------------------------------------------------------------
# OH MY ZSH OPTIONS
#------------------------------------------------------------------------------
# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

#------------------------------------------------------------------------------
# PLUGINS
#------------------------------------------------------------------------------
# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH/custom/plugins/
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    zsh-autosuggestions     # Fish-like autosuggestions
    zsh-syntax-highlighting # Syntax highlighting for commands
    history-substring-search # Fish-like history search
    systemd                 # Systemd commands and aliases
    extract                 # Extract various archive formats
    z                       # Jump to frequently used directories
    sudo                    # Press ESC twice to add sudo to previous command
    fzf-tab                 # Tab completion with fzf
    git                     # Git aliases and functions
    python                  # Python aliases and functions
    docker                  # Docker aliases and functions
    pip                     # Pip completion and aliases
    # Disabled plugins (remove # to enable)
    # lol                   # Fun commands
    # pyenv                 # Python version management
    # redis-cli             # Redis CLI aliases and completion
    # zsh-wakatime          # Enable if you use wakatime with 'https://github.com/wbingli/zsh-wakatime'
)

# Plugins can be added in your own config file under ~/.config/ftazsh/zshrc/ like this:
# plugins+=(zsh-nvm)

# Remove plugins from the default list above in your own config file using:
# plugins=(${plugins:#pluginname})
# Example: plugins=(${plugins:#zsh-autosuggestions})

#------------------------------------------------------------------------------
# HISTORY CONFIGURATION
#------------------------------------------------------------------------------
SAVEHIST=50000      # Save up to 50,000 lines in history (oh-my-zsh default is 10,000)
#setopt hist_ignore_all_dups # Don't record duplicated entries in history during a single session

#------------------------------------------------------------------------------
# PATH CONFIGURATION
#------------------------------------------------------------------------------
# Add to PATH to run programs installed with pipx or "pip install --user"
export PATH=$PATH:~/.local/bin

# To give this path preference instead of system paths to run the latest version of tools,
# add the following to your personal config. Due to security concerns this is not done by default.
# export PATH=~/.local/bin:$PATH

# Add ftazsh bin directory to PATH
export PATH=$PATH:~/.config/ftazsh/bin

# Add npm packages to PATH
NPM_PACKAGES="${HOME}/.npm"
PATH="$NPM_PACKAGES/bin:$PATH"

#------------------------------------------------------------------------------
# TOOL CONFIGURATION
#------------------------------------------------------------------------------
# Marker - command bookmarker
[[ -s "$HOME/.config/ftazsh/marker/marker.sh" ]] && source "$HOME/.config/ftazsh/marker/marker.sh"

#------------------------------------------------------------------------------
# ALIASES
#------------------------------------------------------------------------------
# Network aliases
alias myip="wget -qO- https://wtfismyip.com/text"	# Quickly show external IP address

# OS-specific aliases
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS specific aliases
    alias l="ls -lAhrtF"    # Show all except . .. , sort by recent, / at the end of folders
else
    # Linux specific aliases
    alias l="ls --hyperlink=auto -lAhrtF"    # Show all except . .. , sort by recent, / at the end of folders, clickable
    alias ip="ip --color=auto"
fi

# General aliases
alias e="exit"

# EZA aliases (better ls command)
# To install eza: 
# macOS: brew install eza
# Linux: sudo apt install eza / sudo dnf install eza
alias a='eza -la --git --colour-scale all -g --smart-group --icons always'  # The new ls; add --hyperlink if you like
alias aa='eza -la --git --colour-scale all -g --smart-group --icons always -s modified -r' # Sort by newest

#------------------------------------------------------------------------------
# CUSTOM FUNCTIONS
#------------------------------------------------------------------------------
# Cheat sheets (github.com/chubin/cheat.sh), find out how to use commands
# Example: cheat tar
# For language specific questions supply 2 args: first for language, second as the question
# Example: cheat python3 "execute external program"
cheat() {
    if [ "$2" ]; then
        curl "https://cheat.sh/$1/$2+$3+$4+$5+$6+$7+$8+$9+${10}"
    else
        curl "https://cheat.sh/$1"
    fi
}

# Matrix screen saver! Will run if you have installed "cmatrix"
# TMOUT=900
# TRAPALRM() { if command -v cmatrix &> /dev/null; then cmatrix -sb; fi }

# Run a speedtest from the command line
speedtest() {
    curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
}

# Get a random dad joke
dadjoke() {
    curl https://icanhazdadjoke.com
}

# Find geo info from IP
ipgeo() {
    # Specify ip or your ip will be used
    if [ "$1" ]; then
        curl "http://api.db-ip.com/v2/free/$1"
    else
        curl "http://api.db-ip.com/v2/free/$(myip)"
    fi
}

#------------------------------------------------------------------------------
# POWERLEVEL10K CONFIGURATION
#------------------------------------------------------------------------------
# Powerlevel10k configuration examples
# Uncomment and modify these in your personal config file (~/.config/ftazsh/zshrc/my_config.zsh)

# Colors and styles
#typeset -g POWERLEVEL10K_OS_ICON_BACKGROUND="white"
#typeset -g POWERLEVEL10K_OS_ICON_FOREGROUND="blue"
#typeset -g POWERLEVEL10K_DIR_HOME_FOREGROUND="white"
#typeset -g POWERLEVEL10K_DIR_HOME_SUBFOLDER_FOREGROUND="white"
#typeset -g POWERLEVEL10K_DIR_DEFAULT_FOREGROUND="white"

# Right prompt elements
#typeset -g POWERLEVEL10K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time)

# Left prompt elements
#typeset -g POWERLEVEL10K_LEFT_PROMPT_ELEMENTS=(ssh os_icon dir vcs)

# More prompt elements that are suggested
# (public_ip docker_machine pyenv nvm)
# Note: using public_ip is cool but when connection is down prompt waits for 10-20 seconds

# Single line prompt
#typeset -g POWERLEVEL10K_PROMPT_ON_NEWLINE=false

# For more customization options, run 'p10k configure' or see:
# https://github.com/romkatv/powerlevel10k/blob/master/README.md