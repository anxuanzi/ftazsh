# Example personal ZSH configuration for ftazsh
# Place this file (or create your own) in ~/.config/ftazsh/zshrc/ directory
# All files in this directory will be automatically sourced when your shell starts

# ===== PLUGINS =====
# Add additional Oh My Zsh plugins
plugins+=(docker docker-compose git-flow)

# Remove plugins from the default list if needed
# plugins=(${plugins:#zsh-autosuggestions})

# ===== POWERLEVEL10K CUSTOMIZATION =====
# Customize your prompt elements
# POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time background_jobs)
# POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs)

# ===== PATH ADDITIONS =====
# Add your custom paths
# export PATH=$PATH:$HOME/bin
# export PATH=$PATH:$HOME/.local/bin

# ===== ENVIRONMENT VARIABLES =====
export EDITOR="vim"
export VISUAL="code"

# ===== ALIASES =====
# Development
alias gs="git status"
alias gc="git commit -m"
alias gp="git push"
alias gl="git pull"

# Docker
alias dc="docker-compose"
alias dps="docker ps"

# Navigation
alias ..="cd .."
alias ...="cd ../.."
alias ll="ls -la"

# macOS specific
if [[ "$OSTYPE" == "darwin"* ]]; then
  # Install eza with: brew install eza
  alias ls="eza --icons"
  alias ll="eza -la --git --icons"

  # Open applications
  alias chrome="open -a 'Google Chrome'"
  alias vscode="open -a 'Visual Studio Code'"
fi

# ===== FUNCTIONS =====
# Create a directory and cd into it
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Extract various archive types
extract() {
  if [ -f $1 ]; then
    case $1 in
      *.tar.bz2)   tar xjf $1     ;;
      *.tar.gz)    tar xzf $1     ;;
      *.bz2)       bunzip2 $1     ;;
      *.rar)       unrar e $1     ;;
      *.gz)        gunzip $1      ;;
      *.tar)       tar xf $1      ;;
      *.tbz2)      tar xjf $1     ;;
      *.tgz)       tar xzf $1     ;;
      *.zip)       unzip $1       ;;
      *.Z)         uncompress $1  ;;
      *.7z)        7z x $1        ;;
      *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}
