#!/usr/bin/env zsh
# render-prompt.zsh DIR [SETTLE_SECONDS] [EXTRA_COMMAND]
#
# Boots a real interactive zsh inside a pseudo-terminal (zsh's zpty module,
# so it works the same on macOS and Linux), cds into DIR, waits for the
# prompt to settle (async segments such as gitstatus), and prints everything
# the shell wrote with ANSI/OSC escape sequences stripped. Tests grep this
# output for prompt content (branch names etc.).
emulate -L zsh
setopt extended_glob
zmodload zsh/zpty || { print -u2 "render-prompt: zsh/zpty unavailable"; exit 2 }

local dir=${1:?directory} settle=${2:-1} extra=${3:-}
export TERM=${TERM:-xterm-256color} COLUMNS=200 LINES=50

zpty -b p zsh -i || { print -u2 "render-prompt: cannot start zsh"; exit 2 }
zpty -w p "stty cols 200 rows 50 2>/dev/null; cd ${(q)dir}"
# Async segments (gitstatusd) arrive later; render a prompt every quarter
# second for SETTLE_SECONDS so the output contains one that has them.
integer i n=$(( settle * 4 ))
(( n < 1 )) && n=1
for (( i = 0; i < n; i++ )); do
  zpty -w p "sleep 0.25"
done
zpty -w p "${extra:-true}"
zpty -w p "exit"

local buf='' chunk
for (( i = 0; i < 900; i++ )); do        # up to 90 s
  if zpty -r p chunk; then
    buf+=$chunk
    continue
  fi
  zpty -t p 2>/dev/null || break         # child gone and buffer drained
  sleep 0.1
done
zpty -d p 2>/dev/null

buf=${buf//$'\r'/}
buf=${buf//$'\e'\[[0-9;?]#[a-zA-Z]/}        # CSI sequences (colors, cursor moves)
buf=${buf//$'\e'\][^$'\a']#$'\a'/}          # OSC … BEL (titles, hyperlinks)
buf=${buf//$'\e'\][^$'\e']#$'\e'\\/}        # OSC … ST
buf=${buf//$'\e'[()][A-Z0-9]/}              # charset selection
buf=${buf//$'\e'[=>78]/}                    # keypad / cursor save-restore
print -r -- $buf
