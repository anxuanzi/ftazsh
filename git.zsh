# ftazsh git integration — loaded AFTER oh-my-zsh (so Powerlevel10k is loaded).
#
# Powerlevel10k's `vcs` segment gets its data from gitstatusd, which is built
# on libgit2 and cannot read git's reftable ref backend (Git ≥ 2.45; the
# default for new repositories from Git 3.0):
#   https://github.com/romkatv/powerlevel10k/issues/2941
# In a reftable repository it reports a bogus branch called ".invalid".
#
# ftazsh fixes this without touching p10k's async machinery. The two p10k
# functions that turn gitstatusd's answer into cache/prompt text get a
# one-line prefix which, in reftable repositories only, recomputes the
# VCS_STATUS_* variables with the git CLI. Styling, caching, your
# my_git_formatter in p10k.zsh, and every non-reftable repository behave
# exactly as before. `ftazsh doctor` reports whether the shim is active.

zmodload zsh/datetime 2>/dev/null
zmodload -F zsh/stat b:zstat 2>/dev/null

# Repositories whose index is larger than this (bytes) only get branch and
# ahead/behind information — no dirty-state scan — to keep the prompt snappy.
: ${FTAZSH_VCS_MAX_INDEX_BYTES:=16777216}

typeset -g  _ftazsh_vcs_memo_sig=''
typeset -gF _ftazsh_vcs_memo_time=0

# _ftazsh_git_locate DIR → reply=(<git dir> <work dir>); 1 if not in a repo. No forks.
_ftazsh_git_locate() {
  emulate -L zsh -o extended_glob
  local dir=$1 line gitdir
  if [[ -n $GIT_DIR ]]; then
    gitdir=$GIT_DIR
    [[ $gitdir == /* ]] || gitdir=$PWD/$gitdir
    reply=($gitdir ${GIT_WORK_TREE:-$PWD})
    return 0
  fi
  while true; do
    if [[ -d $dir/.git ]]; then
      reply=($dir/.git $dir)
      return 0
    elif [[ -f $dir/.git ]]; then                      # linked worktree or submodule
      read -r line < $dir/.git || return 1
      [[ $line == gitdir:\ * ]] || return 1
      gitdir=${line#gitdir: }
      [[ $gitdir == /* ]] || gitdir=$dir/$gitdir
      reply=($gitdir $dir)
      return 0
    elif [[ -f $dir/HEAD && -d $dir/objects && -d $dir/refs ]]; then   # bare repo, or inside .git
      reply=($dir $dir)
      return 0
    fi
    [[ $dir == (/|.|) ]] && return 1
    dir=${dir:h}
  done
}

# _ftazsh_git_is_reftable GITDIR — true when the (common) git dir uses reftable.
_ftazsh_git_is_reftable() {
  emulate -L zsh -o extended_glob
  local common=$1 line
  if [[ -f $1/commondir ]]; then                       # linked worktrees share one ref store
    read -r line < $1/commondir
    [[ $line == /* ]] && common=$line || common=$1/$line
  fi
  [[ -f $common/reftable/tables.list ]]
}

# _ftazsh_git_remote_url GITDIR REMOTE → REPLY (parsed from the config file, no fork).
_ftazsh_git_remote_url() {
  emulate -L zsh -o extended_glob
  local common=$1 remote=$2 line in_section=0
  REPLY=''
  if [[ -f $1/commondir ]]; then
    read -r line < $1/commondir
    [[ $line == /* ]] && common=$line || common=$1/$line
  fi
  [[ -n $remote && -r $common/config ]] || return 0
  for line in "${(@f)$(<$common/config)}"; do
    line=${line##[[:space:]]#}
    if [[ $line == \[* ]]; then
      [[ $line == "[remote \"$remote\"]" ]] && in_section=1 || in_section=0
    elif (( in_section )) && [[ $line == url[[:space:]]#=* ]]; then
      REPLY=${${line#*=}##[[:space:]]#}
      return 0
    fi
  done
}

# _ftazsh_git_action WORKDIR GITDIR → REPLY: rebase-i, merge, cherry, … (gitstatusd's names) or ''.
_ftazsh_git_action() {
  emulate -L zsh -o extended_glob
  local dir=$1 g=$2 out
  local -a lines
  REPLY=''
  if [[ -d $g/rebase-merge ]]; then
    [[ -f $g/rebase-merge/interactive ]] && REPLY=rebase-i || REPLY=rebase-m
  elif [[ -d $g/rebase-apply ]]; then
    if [[ -f $g/rebase-apply/rebasing ]]; then REPLY=rebase
    elif [[ -f $g/rebase-apply/applying ]]; then REPLY=am
    else REPLY=am/rebase
    fi
  elif [[ -f $g/MERGE_HEAD ]]; then
    REPLY=merge
  elif [[ -f $g/BISECT_LOG ]]; then
    REPLY=bisect
  else
    # CHERRY_PICK_HEAD / REVERT_HEAD are pseudorefs: with reftable they live
    # in the ref database, not as files, so ask git.
    out=$(command git -C $dir cat-file --batch-check 2>/dev/null <<< $'CHERRY_PICK_HEAD\nREVERT_HEAD') || return 0
    lines=(${(f)out})
    if [[ -n $lines[1] && $lines[1] != *' missing' ]]; then
      [[ -f $g/sequencer/todo ]] && REPLY=cherry-seq || REPLY=cherry
    elif [[ -n $lines[2] && $lines[2] != *' missing' ]]; then
      [[ -f $g/sequencer/todo ]] && REPLY=revert-seq || REPLY=revert
    fi
  fi
  return 0
}

# _ftazsh_git_cli_status WORKDIR GITDIR — fill VCS_STATUS_* (the variables
# gitstatusd would set) from the git CLI. Returns 1 if git fails.
_ftazsh_git_cli_status() {
  emulate -L zsh -o extended_glob
  local dir=$1 g=$2 out line xy
  local oid='' head='' upstream='' ab=''
  local -i ahead=0 behind=0 stashes=0 staged=0 unstaged=0 untracked=0 conflicted=0
  local -i staged_new=0 staged_deleted=0 unstaged_deleted=0 big=0
  local -a st lines

  if zstat -A st +size -- $g/index 2>/dev/null && (( st[1] > FTAZSH_VCS_MAX_INDEX_BYTES )); then
    big=1
  fi

  if (( big )); then
    # Large repository: branch / upstream / ahead-behind only, no worktree scan.
    out=$(command git -C $dir for-each-ref --format='%(HEAD)%(refname:short)%00%(objectname)%00%(upstream:short)%00%(upstream:track,nobracket)' --points-at HEAD refs/heads 2>/dev/null) || return 1
    for line in ${(f)out}; do
      [[ $line == \** ]] || continue
      lines=("${(@0)line#\*}")
      head=$lines[1] oid=$lines[2] upstream=$lines[3] ab=$lines[4]
      [[ $ab == *ahead\ <->* ]] && ahead=${${ab#*ahead }%%[^0-9]*}
      [[ $ab == *behind\ <->* ]] && behind=${${ab#*behind }%%[^0-9]*}
      break
    done
    if [[ -z $oid ]]; then
      oid=$(command git -C $dir rev-parse -q --verify HEAD 2>/dev/null) || oid=''
    fi
  else
    out=$(command git -C $dir --no-optional-locks status --porcelain=v2 --branch --show-stash 2>/dev/null) || return 1
    for line in ${(f)out}; do
      case $line in
        '# branch.oid '*)      oid=${line#\# branch.oid };;
        '# branch.head '*)     head=${line#\# branch.head };;
        '# branch.upstream '*) upstream=${line#\# branch.upstream };;
        '# branch.ab '*)       ab=${line#\# branch.ab }
                               ahead=${${ab%% *}#+}
                               behind=${${ab##* }#-};;
        '# stash '*)           stashes=${line#\# stash };;
        [12]\ *)               xy=${line[3,4]}
                               [[ $xy[1] != . ]] && (( ++staged ))
                               [[ $xy[2] != . ]] && (( ++unstaged ))
                               [[ $xy[1] == A ]] && (( ++staged_new ))
                               [[ $xy[1] == D ]] && (( ++staged_deleted ))
                               [[ $xy[2] == D ]] && (( ++unstaged_deleted ));;
        u\ *)                  (( ++conflicted ));;
        \?\ *)                 (( ++untracked ));;
      esac
    done
    [[ $oid == '(initial)' ]] && oid=''
    [[ $head == '(detached)' ]] && head=''
  fi

  local remote_name='' remote_branch='' tag='' summary=''
  if [[ -n $upstream ]]; then
    remote_name=${upstream%%/*}
    remote_branch=${upstream#*/}
  fi
  _ftazsh_git_remote_url $g $remote_name
  local remote_url=$REPLY
  if [[ -z $head && -n $oid ]]; then
    tag=$(command git -C $dir describe --tags --exact-match HEAD 2>/dev/null) || tag=''
  fi
  if [[ -n $oid ]]; then
    summary=$(command git -C $dir log -1 --format=%s $oid 2>/dev/null) || summary=''
  fi
  _ftazsh_git_action $dir $g
  local action=$REPLY

  typeset -g VCS_STATUS_WORKDIR=$dir
  typeset -g VCS_STATUS_COMMIT=$oid
  typeset -g VCS_STATUS_COMMIT_ENCODING=''
  typeset -g VCS_STATUS_COMMIT_SUMMARY=$summary
  typeset -g VCS_STATUS_LOCAL_BRANCH=$head
  typeset -g VCS_STATUS_REMOTE_NAME=$remote_name
  typeset -g VCS_STATUS_REMOTE_BRANCH=$remote_branch
  typeset -g VCS_STATUS_REMOTE_URL=$remote_url
  typeset -g VCS_STATUS_ACTION=$action
  typeset -g VCS_STATUS_INDEX_SIZE=0
  typeset -g VCS_STATUS_NUM_STAGED=$staged
  typeset -g VCS_STATUS_NUM_CONFLICTED=$conflicted
  typeset -g VCS_STATUS_NUM_UNSTAGED=$unstaged
  typeset -g VCS_STATUS_NUM_UNTRACKED=$untracked
  typeset -g VCS_STATUS_NUM_STAGED_NEW=$staged_new
  typeset -g VCS_STATUS_NUM_STAGED_DELETED=$staged_deleted
  typeset -g VCS_STATUS_NUM_UNSTAGED_DELETED=$unstaged_deleted
  typeset -g VCS_STATUS_HAS_STAGED=$(( staged > 0 ))
  typeset -g VCS_STATUS_HAS_CONFLICTED=$(( conflicted > 0 ))
  if (( big )); then
    typeset -g VCS_STATUS_HAS_UNSTAGED=-1        # unknown: p10k shows "─"
    typeset -g VCS_STATUS_HAS_UNTRACKED=-1
  else
    typeset -g VCS_STATUS_HAS_UNSTAGED=$(( unstaged > 0 ))
    typeset -g VCS_STATUS_HAS_UNTRACKED=$(( untracked > 0 ))
  fi
  typeset -g VCS_STATUS_COMMITS_AHEAD=$ahead
  typeset -g VCS_STATUS_COMMITS_BEHIND=$behind
  typeset -g VCS_STATUS_STASHES=$stashes
  typeset -g VCS_STATUS_TAG=$tag
  typeset -g VCS_STATUS_PUSH_REMOTE_NAME=''
  typeset -g VCS_STATUS_PUSH_REMOTE_URL=''
  typeset -g VCS_STATUS_PUSH_COMMITS_AHEAD=0
  typeset -g VCS_STATUS_PUSH_COMMITS_BEHIND=0
  typeset -g VCS_STATUS_NUM_SKIP_WORKTREE=0
  typeset -g VCS_STATUS_NUM_ASSUME_UNCHANGED=0
  return 0
}

# The hook p10k's functions call first. Cheap outside reftable repositories.
_ftazsh_vcs_fixup() {
  emulate -L zsh -o extended_glob
  [[ $VCS_STATUS_RESULT == (ok|norepo)-* ]] || return 0
  local dir=$VCS_STATUS_WORKDIR
  [[ $VCS_STATUS_RESULT == norepo-* || -z $dir ]] && dir=${_p9k__cwd_a:-$PWD}
  local -a reply
  _ftazsh_git_locate $dir || return 0
  local gitdir=$reply[1] workdir=$reply[2]
  _ftazsh_git_is_reftable $gitdir || return 0

  # p10k calls the cache-save and render functions back to back with the
  # same data; recompute only when the data changed or time passed.
  local sig="$gitdir|$VCS_STATUS_COMMIT|$VCS_STATUS_LOCAL_BRANCH|$VCS_STATUS_NUM_STAGED|$VCS_STATUS_NUM_UNSTAGED|$VCS_STATUS_NUM_UNTRACKED|$VCS_STATUS_STASHES"
  if [[ $sig == $_ftazsh_vcs_memo_sig ]] && (( EPOCHREALTIME - _ftazsh_vcs_memo_time < 0.5 )); then
    return 0
  fi
  _ftazsh_git_cli_status $workdir $gitdir || return 0
  [[ $VCS_STATUS_RESULT == norepo-* ]] && VCS_STATUS_RESULT=ok-${VCS_STATUS_RESULT#norepo-}
  typeset -g _ftazsh_vcs_memo_sig="$gitdir|$VCS_STATUS_COMMIT|$VCS_STATUS_LOCAL_BRANCH|$VCS_STATUS_NUM_STAGED|$VCS_STATUS_NUM_UNSTAGED|$VCS_STATUS_NUM_UNTRACKED|$VCS_STATUS_STASHES"
  typeset -gF _ftazsh_vcs_memo_time=EPOCHREALTIME
  return 0
}

# While gitstatusd's query is still in flight, p10k renders "loading" (or the
# directory's cached status). gitstatusd can never answer for a reftable
# repository, so seed p10k's cache from the git CLI: the branch shows at once,
# also when the daemon is slow to start, hangs or is unavailable.
_ftazsh_vcs_seed_cache() {
  emulate -L zsh -o extended_glob
  [[ -n $GIT_DIR ]] && return 0                 # p10k keys that case by GIT_DIR; the fixup covers it
  _p9k_vcs_status_for_dir && return 0           # already cached for this directory
  local dir=${_p9k__cwd_a:-$PWD}
  local -a reply
  _ftazsh_git_locate $dir || return 0
  local gitdir=$reply[1] workdir=$reply[2]
  _ftazsh_git_is_reftable $gitdir || return 0
  _ftazsh_git_cli_status $workdir $gitdir || return 0
  typeset -g VCS_STATUS_RESULT=ok-async
  typeset -g _ftazsh_vcs_memo_sig="$gitdir|$VCS_STATUS_COMMIT|$VCS_STATUS_LOCAL_BRANCH|$VCS_STATUS_NUM_STAGED|$VCS_STATUS_NUM_UNSTAGED|$VCS_STATUS_NUM_UNTRACKED|$VCS_STATUS_STASHES"
  typeset -gF _ftazsh_vcs_memo_time=EPOCHREALTIME
  _p9k_vcs_status_save                          # p10k's cache (its fixup prelude is a memo hit)
  return 0
}

# Prefix the two p10k functions. Idempotent; sets FTAZSH_P10K_SHIM=1 on success.
_ftazsh_p10k_shim_install() {
  emulate -L zsh -o extended_glob
  local f prelude
  (( $+functions[_p9k_vcs_status_save] && $+functions[_p9k_vcs_render] )) || return 1
  for f in _p9k_vcs_status_save _p9k_vcs_render; do
    [[ $functions[$f] == *_ftazsh_vcs_fixup* ]] && continue
    if [[ $f == _p9k_vcs_render ]]; then
      # Query in flight: p10k renders from its cache, seeded here for reftable
      # repos. Otherwise fix up the fresh (or restored) status in place.
      prelude='if (( $+_p9k__gitstatus_next_dir )); then _ftazsh_vcs_seed_cache; else _ftazsh_vcs_fixup; fi'
    else
      prelude='_ftazsh_vcs_fixup'
    fi
    functions[$f]="$prelude"$'\n'"$functions[$f]"
  done
  typeset -g FTAZSH_P10K_SHIM=1
}

_ftazsh_p10k_shim_install 2>/dev/null || typeset -g FTAZSH_P10K_SHIM=0
