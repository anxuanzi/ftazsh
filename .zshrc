# ftazsh-managed — do not edit; personal config goes in ~/.config/ftazsh/zshrc/
#
# Load order:
#   1. Powerlevel10k instant prompt (cached)
#   2. ftazshrc.zsh  — core setup, runs BEFORE oh-my-zsh
#   3. p10k.zsh      — prompt configuration
#   4. zshrc/*       — YOUR files (may append to $plugins, override anything)
#   5. oh-my-zsh
#   6. tools.zsh     — tool integrations + aliases, AFTER oh-my-zsh so they win

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

FTAZSH_HOME="$HOME/.config/ftazsh"

# Core ftazsh configuration (oh-my-zsh settings, plugins, history, PATH).
source "$FTAZSH_HOME/ftazshrc.zsh"

# Prompt configuration — edit ~/.config/ftazsh/p10k.zsh or run `p10k configure`.
[[ ! -f "$FTAZSH_HOME/p10k.zsh" ]] || source "$FTAZSH_HOME/p10k.zsh"

# Your personal configuration: every file in ~/.config/ftazsh/zshrc/ is
# sourced in name order. ftazsh never modifies files in that directory.
for _ftazsh_file in "$FTAZSH_HOME/zshrc"/*(N-.); do
  source "$_ftazsh_file"
done
unset _ftazsh_file

source "$ZSH/oh-my-zsh.sh"

# Modern tool integrations and aliases (kept after oh-my-zsh on purpose:
# oh-my-zsh defines its own `l` and Ctrl-R bindings, and these must win).
source "$FTAZSH_HOME/tools.zsh"
