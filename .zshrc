# ftazsh-managed — do not edit; personal config goes in ~/.config/ftazsh/zshrc/
#
# Load order:
#   1. settings.zsh  — YOUR settings (update mode, …), seeded once
#   2. update.zsh    — update check; may print or ask, so it runs before the instant prompt
#   3. Powerlevel10k instant prompt (cached)
#   4. ftazshrc.zsh  — core setup, runs BEFORE oh-my-zsh
#   5. p10k.zsh      — prompt configuration
#   6. zshrc/*       — YOUR files (may append to $plugins, override anything)
#   7. oh-my-zsh
#   8. tools.zsh     — tool integrations + aliases, AFTER oh-my-zsh so they win
#   9. git.zsh       — git integration (reftable-safe prompt)

FTAZSH_HOME="$HOME/.config/ftazsh"

[[ ! -r "$FTAZSH_HOME/settings.zsh" ]] || source "$FTAZSH_HOME/settings.zsh"
[[ ! -r "$FTAZSH_HOME/update.zsh" ]]   || source "$FTAZSH_HOME/update.zsh"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Core ftazsh configuration (Homebrew PATH, oh-my-zsh settings, plugins, history).
source "$FTAZSH_HOME/ftazshrc.zsh"

# Prompt configuration — edit ~/.config/ftazsh/p10k.zsh or run `p10k configure`.
# POWERLEVEL9K_* variables exported in the environment (CI, tests, ssh) must
# win over the config file, which starts by unsetting every POWERLEVEL9K_*
# parameter — so they are saved first and restored afterwards.
typeset -A _ftazsh_p9k_env
for _ftazsh_v in ${(k)parameters[(I)POWERLEVEL9K_*]}; do
  [[ ${parameters[$_ftazsh_v]} == *export* ]] && _ftazsh_p9k_env[$_ftazsh_v]=${(P)_ftazsh_v}
done
[[ ! -f "$FTAZSH_HOME/p10k.zsh" ]] || source "$FTAZSH_HOME/p10k.zsh"
for _ftazsh_v in ${(k)_ftazsh_p9k_env}; do
  typeset -gx "$_ftazsh_v"="$_ftazsh_p9k_env[$_ftazsh_v]"
done
unset _ftazsh_v _ftazsh_p9k_env

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

# Git integration: keeps the Powerlevel10k prompt correct in reftable repos.
[[ ! -r "$FTAZSH_HOME/git.zsh" ]] || source "$FTAZSH_HOME/git.zsh"
