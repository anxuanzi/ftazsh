#!/usr/bin/env zsh
# render-prompt.zsh DIR [MAX_SECONDS] [EXTRA_COMMAND] [UNTIL_PATTERN]
#
# Boots a real interactive zsh inside a pseudo-terminal (zsh's zpty module,
# so it works the same on macOS and Linux), cds into DIR and keeps rendering
# prompts (one every ~0.3 s) until the output matches UNTIL_PATTERN, an
# extended regular expression, or MAX_SECONDS (default 1) have passed.
# Without a pattern it renders for MAX_SECONDS. EXTRA_COMMAND, if given, runs
# once at the end. Everything the shell wrote is printed with ANSI/OSC escape
# sequences stripped, so tests can grep it for prompt content (branch names).
#
# Async prompt segments (gitstatusd) arrive after the first prompt, and on a
# fresh machine Powerlevel10k first downloads gitstatusd, which can take tens
# of seconds. Callers therefore pass a generous MAX_SECONDS and the text they
# expect as UNTIL_PATTERN: the harness returns as soon as the prompt shows it
# and writes a one-line timing note to stderr. The exit status is always 0;
# callers grep the output.
emulate -L zsh
setopt extended_glob
zmodload zsh/zpty zsh/datetime || { print -u2 "render-prompt: zsh/zpty unavailable"; exit 2 }

local dir=${1:?directory} extra=${3:-} until=${4:-}
float max=${2:-1}
export TERM=${TERM:-xterm-256color} COLUMNS=200 LINES=50

# Strips terminal escape sequences from $1 into REPLY.
strip-escapes() {
  local s=${1//$'\r'/}
  s=${s//$'\e'\[[0-9;?]#[a-zA-Z]/}        # CSI sequences (colors, cursor moves)
  s=${s//$'\e'\][^$'\a']#$'\a'/}          # OSC … BEL (titles, hyperlinks)
  s=${s//$'\e'\][^$'\e']#$'\e'\\/}        # OSC … ST
  s=${s//$'\e'[()][A-Z0-9]/}              # charset selection
  s=${s//$'\e'[=>78]/}                    # keypad / cursor save-restore
  REPLY=$s
}

zpty -b p zsh -i || { print -u2 "render-prompt: cannot start zsh"; exit 2 }
zpty -w p "stty cols 200 rows 50 2>/dev/null; cd ${(q)dir}"

local buf='' chunk
float start=EPOCHREALTIME deadline=$(( EPOCHREALTIME + max )) window matched_at=0
integer i matched=0
while (( ! matched && EPOCHREALTIME < deadline )); do
  zpty -t p || break                     # the shell is gone
  zpty -w p "sleep 0.25"                 # every command ends with a fresh prompt
  window=$(( EPOCHREALTIME + 0.3 ))
  while (( EPOCHREALTIME < window )); do
    if zpty -r p chunk; then buf+=$chunk; else sleep 0.05; fi
  done
  if [[ -n $until ]]; then
    strip-escapes "$buf"
    if [[ $REPLY =~ $until ]]; then
      matched=1
      matched_at=$(( EPOCHREALTIME - start ))
    fi
  fi
done
zpty -w p "${extra:-true}"
zpty -w p "exit"

for (( i = 0; i < 900; i++ )); do        # drain until the shell has exited (up to 90 s)
  if zpty -r p chunk; then
    buf+=$chunk
    continue
  fi
  zpty -t p || break                     # child gone and buffer drained
  sleep 0.1
done
# No redirection on these zpty calls: once the child has exited, zpty -d
# closes the (already closed) master fd number again, which would close the
# descriptor zsh saved for the redirection and leave stderr pointing at
# /dev/null for the rest of the script (zsh 5.9).
zpty -d p

if [[ -n $until ]]; then
  if (( matched )); then
    printf 'render-prompt: output matched %s after %.1f s\n' "$until" $matched_at >&2
  else
    printf 'render-prompt: no match for %s within %.0f s\n' "$until" $max >&2
  fi
fi
strip-escapes "$buf"
print -r -- $REPLY
