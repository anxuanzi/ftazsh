# ftazsh update check — sourced at the very top of ~/.zshrc, BEFORE the
# Powerlevel10k instant prompt, because it may print or ask a question.
#
#   * Every $FTAZSH_UPDATE_FREQUENCY_DAYS days a background job runs
#     `ftazsh update --check --background`. It never blocks the shell.
#   * When that check found a newer version, the next shell start acts on it
#     according to $FTAZSH_UPDATE_MODE (prompt / auto / reminder / disabled;
#     see ~/.config/ftazsh/settings.zsh).
#   * `ftazsh update` clears the pending state.
#
# State lives in ~/.config/ftazsh/state/:
#   update-check      last=<epoch> next=<epoch>   when to check again
#   update-available  <remote sha> <new commits>  a check found an update
#   update-snooze     <epoch>                     "not now" until then

_ftazsh_update_check() {
  emulate -L zsh
  setopt localoptions nomonitor nonotify

  local mode=${FTAZSH_UPDATE_MODE:-prompt}
  local days=${FTAZSH_UPDATE_FREQUENCY_DAYS:-7}
  [[ $mode == disabled ]] && return 0
  [[ -n ${FTAZSH_UPDATING:-} ]] && return 0          # inside ftazsh's own scripts
  local home=${FTAZSH_HOME:-$HOME/.config/ftazsh}
  local cli=$home/bin/ftazsh state=$home/state
  [[ -x $cli && -d $home/repo/.git ]] || return 0
  [[ $days == <-> ]] || days=7
  zmodload zsh/datetime 2>/dev/null || return 0
  command mkdir -p -- $state 2>/dev/null || return 0

  # 1. A previous background check found an update: act on it.
  if [[ -r $state/update-available ]]; then
    local snooze=0
    [[ -r $state/update-snooze ]] && snooze=$(<$state/update-snooze)
    [[ $snooze == <-> ]] || snooze=0
    (( EPOCHSECONDS < snooze )) && return 0        # "not now" is still in effect

    local count=$(<$state/update-available)
    count=${count##* }
    [[ $count == <-> ]] || count=''
    local plural=s
    [[ $count == 1 ]] && plural=''
    local msg="[ftazsh] Update available${count:+ ($count new commit$plural)}."

    case $mode in
      auto)
        print -r -- "$msg Updating..."
        "$cli" update --yes
        ;;
      reminder)
        print -r -- "$msg Run \`ftazsh update\` to install it."
        ;;
      *)
        if [[ -t 0 && -t 1 ]]; then
          local reply=''
          print -n -- "$msg Update now? [Y/n] "
          if read -t 15 -k 1 reply; then
            [[ $reply == $'\n' ]] || print
            case $reply in
              [nN])
                print -r -- "[ftazsh] OK, not now. Run \`ftazsh update\` whenever you like."
                print -r -- $(( EPOCHSECONDS + days * 86400 )) > $state/update-snooze
                ;;
              *)
                "$cli" update --yes
                ;;
            esac
          else
            print
            print -r -- "[ftazsh] No answer; I'll ask again tomorrow. Run \`ftazsh update\` any time."
            print -r -- $(( EPOCHSECONDS + 86400 )) > $state/update-snooze
          fi
        else
          print -r -- "$msg Run \`ftazsh update\` to install it."
        fi
        ;;
    esac
    return 0
  fi

  # 2. Time for a new check? Run it in the background, silently.
  local next=0 line
  if [[ -r $state/update-check ]]; then
    while read -r line; do
      [[ $line == next=* ]] && next=${line#next=}
    done < $state/update-check
    [[ $next == <-> ]] || next=0
  fi
  (( EPOCHSECONDS >= next )) || return 0
  # Claim the slot first so shells opened at the same time don't all fetch;
  # the check rewrites this with the real schedule when it finishes.
  print -r -- "last=$EPOCHSECONDS"$'\n'"next=$(( EPOCHSECONDS + 3600 ))" > $state/update-check
  ( FTAZSH_UPDATE_FREQUENCY_DAYS=$days "$cli" update --check --background </dev/null >/dev/null 2>&1 & )
  return 0
}

_ftazsh_update_check
unfunction _ftazsh_update_check
