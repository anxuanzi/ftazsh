# Example personal configuration for ftazsh.
#
# Every file in ~/.config/ftazsh/zshrc/ is sourced automatically, in name
# order, BEFORE oh-my-zsh loads — so plugin changes here take effect.
# This file is seeded once at install time and NEVER overwritten by ftazsh.

# --- plugins ---
# plugins+=(docker-compose golang kubectl)
# Remove a default plugin:  plugins=(${plugins:#docker})

# --- environment ---
export EDITOR="vim"
# export VISUAL="code"

# --- aliases ---
alias gs="git status"
alias ..="cd .."
alias ...="cd ../.."

# --- functions ---
mkcd() { mkdir -p "$1" && cd "$1"; }

# --- prompt tweaks ---
# Run `p10k configure` or edit ~/.config/ftazsh/p10k.zsh. Quick overrides:
# typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=false
