# ftazsh settings — this file is yours: seeded once, never overwritten.
# It is sourced first (before the prompt and before the update check), so
# keep it to plain variable assignments.

# --- automatic updates -------------------------------------------------------
# What happens when a background check finds a new ftazsh version:
#   prompt    ask "Update now? [Y/n]" when the next shell starts (default)
#   auto      update without asking
#   reminder  only print a one-line notice
#   disabled  never check
FTAZSH_UPDATE_MODE=prompt

# Days between background update checks.
FTAZSH_UPDATE_FREQUENCY_DAYS=7

# 1 = updates (automatic or `ftazsh update`) also upgrade the Homebrew tools
# ftazsh manages; 0 = leave the tools alone (`ftazsh update --tools` still can).
FTAZSH_UPDATE_TOOLS=1

# --- prompt ------------------------------------------------------------------
# In reftable git repositories the prompt's git status comes from the git CLI
# (see git.zsh). Repositories whose index is larger than this many bytes only
# show branch / ahead / behind, skipping the dirty-state scan.
# FTAZSH_VCS_MAX_INDEX_BYTES=16777216
