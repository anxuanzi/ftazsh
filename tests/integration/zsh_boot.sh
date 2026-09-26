#!/usr/bin/env bash
# shellcheck disable=SC2016  # single-quoted strings are zsh code for `zsh -c`
# Integration test: build a REAL ftazsh layout in a scratch HOME (network
# clones of oh-my-zsh, plugins and Powerlevel10k; ftazsh itself from this
# checkout), then boot interactive zsh and verify the environment is healthy:
# tool wiring, the ftazsh CLI, git config, the reftable-safe prompt, and the
# update flow against a local "upstream". Runs on Linux (Docker/CI) and macOS.
#
# The Homebrew/macOS-only steps are not exercised here — they are covered by
# the unit tests (stubbed) and, for real, by the macOS CI job and
# tests/macos/smoke.sh.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

export HOME="$SCRATCH"
export FTAZSH_HOME="$HOME/.config/ftazsh"
export _ZO_DATA_DIR="$SCRATCH/zoxide"   # zoxide's database stays inside the scratch HOME on every OS

# Don't let the invoking shell's environment leak into the boots under test
# (e.g. a developer's own FZF_* exports from a previous ftazsh install).
unset FZF_DEFAULT_OPTS FZF_DEFAULT_OPS FZF_DEFAULT_COMMAND FZF_CTRL_T_COMMAND \
      FZF_CTRL_T_OPTS FZF_ALT_C_COMMAND FZF_ALT_C_OPTS MANPAGER MANROFFOPT \
      XDG_CONFIG_HOME GIT_CONFIG_GLOBAL ZDOTDIR

# Keep the prompt hermetic: no config wizard, no instant prompt console
# output, no gitstatusd download (the reftable prompt check re-enables it).
export POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
export POWERLEVEL9K_INSTANT_PROMPT=off
export POWERLEVEL9K_DISABLE_GITSTATUS=true
# No startup update checks in the shells we boot (except where tested).
export FTAZSH_UPDATING=1

# A local "upstream" ftazsh for the update flow: a clone of this checkout
# with the current working tree committed on top (so uncommitted changes are
# tested too). The layout below is installed from that snapshot.
UPSTREAM="$SCRATCH/upstream"
git clone -q "$REPO_DIR" "$UPSTREAM"
git -C "$UPSTREAM" checkout -q -B it
git -C "$UPSTREAM" config user.name it
git -C "$UPSTREAM" config user.email it@example.com
git -C "$REPO_DIR" ls-files -co --exclude-standard -z \
    | tar -C "$REPO_DIR" --null -cf - -T - \
    | tar -C "$UPSTREAM" -xf -
git -C "$UPSTREAM" add -A
git -C "$UPSTREAM" commit -q --allow-empty -m "working tree snapshot"
export FTAZSH_REPO_URL="file://$UPSTREAM"
export FTAZSH_REPO_BRANCH=it

# Stubs for the macOS-only commands, used ONLY when the full installer runs
# through `ftazsh update` below (the zsh boots never see them).
STUBS="$SCRATCH/stubs"
mkdir -p "$STUBS"
printf '#!/usr/bin/env bash\nif [[ "${1:-}" == -m ]]; then echo arm64; else echo Darwin; fi\n' > "$STUBS/uname"
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUBS/brew"
printf '#!/usr/bin/env bash\necho "UserShell: /bin/zsh"\n' > "$STUBS/dscl"
chmod +x "$STUBS"/*
export FTAZSH_FONT_DIR="$SCRATCH/fonts"

# Pre-existing user state the installer must respect, including the directory
# history of the original ftazsh's z plugin (~/.z), which zoxide should inherit.
printf '[user]\n\tname = Integration\n[core]\n\tpager = less\n' > "$HOME/.gitconfig"
mkdir -p "$HOME/legacy-jump-3c9e"
printf '%s|42|%s\n' "$HOME/legacy-jump-3c9e" "$(date +%s)" > "$HOME/.z"

echo "== Building layout in $SCRATCH using installer functions =="
# shellcheck disable=SC1090
source "$REPO_DIR/install.sh"   # source guard keeps main() from running
trap - ERR
trap 'rm -rf "$SCRATCH"' EXIT   # re-arm cleanup (sourcing replaced nothing, but be explicit)
SCRIPT_DIR="$UPSTREAM"          # install from the working-tree snapshot

backup_zshrc
create_directories
install_omz
migrate_legacy_install
install_plugin_repos
install_p10k
sync_repo
copy_config_files
configure_git
record_install_state

# Between installs: a tool appends to the managed ~/.zshrc (as nvm, conda or
# bun do), and the original ftazsh's nested zsh-autosuggestions clone is
# simulated inside oh-my-zsh's own (now bundled) plugin directory.
echo 'export FROM_A_TOOL_APPEND=1' >> "$HOME/.zshrc"
if [[ -d "$FTAZSH_HOME/oh-my-zsh/plugins/zsh-autosuggestions" ]]; then
    git -C "$FTAZSH_HOME/oh-my-zsh/plugins/zsh-autosuggestions" init -q
fi

# zoxide's score for the imported entry; the re-run below must not import again.
LEGACY_SCORE="$( (command -v zoxide >/dev/null && zoxide query -s legacy-jump-3c9e) 2>/dev/null || true)"

echo "== Re-running installer steps (idempotency, real update paths) =="
backup_zshrc
create_directories
install_omz
migrate_legacy_install
install_plugin_repos
install_p10k
sync_repo
copy_config_files
configure_git

PASS=0
FAIL=0

# check <description> <zsh-code>: boots interactive zsh, code must exit 0.
check() {
    local desc="$1" code="$2"
    if zsh -i -c "$code" >/dev/null 2>"$SCRATCH/check-stderr.log"; then
        echo "ok: $desc"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc" >&2
        sed 's/^/    stderr: /' "$SCRATCH/check-stderr.log" >&2
        FAIL=$((FAIL + 1))
    fi
}

# check_bash <description> <bash-code> [args...]: same, for plain bash checks
# (extra args are available to the code as $1, $2, ...).
check_bash() {
    local desc="$1" code="$2"
    shift 2
    if bash -c "$code" _ "$@" >"$SCRATCH/check-out.log" 2>&1; then
        echo "ok: $desc"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc" >&2
        sed 's/^/    output: /' "$SCRATCH/check-out.log" >&2
        FAIL=$((FAIL + 1))
    fi
}

echo "== Booting zsh and checking the environment =="

# 1. A clean interactive boot must write nothing to stderr.
# One known-benign line is filtered: fzf's --zsh script snapshots shell
# options and eval-restores them; restoring `zle on` in an interactive but
# tty-less zsh (CI runners, this harness) prints "can't change option: zle".
# Real terminals have a tty and never emit it; fzf's widgets still bind.
zsh -i -c exit 2>"$SCRATCH/boot-stderr.log" || true
grep -v "can't change option: zle" "$SCRATCH/boot-stderr.log" \
    > "$SCRATCH/boot-stderr-filtered.log" || true
if [[ -s "$SCRATCH/boot-stderr-filtered.log" ]]; then
    echo "FAIL: interactive boot wrote to stderr:" >&2
    sed 's/^/    /' "$SCRATCH/boot-stderr-filtered.log" >&2
    FAIL=$((FAIL + 1))
else
    echo "ok: interactive boot is silent on stderr (headless-zle noise excluded)"
    PASS=$((PASS + 1))
fi

check "core aliases defined (l, e)" 'alias l >/dev/null && alias e >/dev/null'
check "eza aliases defined when eza is present" \
    '! command -v eza >/dev/null || { alias a >/dev/null && alias aa >/dev/null; }'
check "eza alias actually runs" \
    '! command -v eza >/dev/null || { cd "$HOME" && a >/dev/null; }'
check "eza is the default ls (ls, ll, la, l, lt) and they all run" \
    '! command -v eza >/dev/null || { alias ls | grep -q eza && alias ll | grep -q eza && alias la | grep -q eza && alias l | grep -q eza && alias lt | grep -q eza && cd "$HOME" && ls >/dev/null && ll >/dev/null && la >/dev/null && l >/dev/null && lt >/dev/null; }'
check "plain ls fallback for l when eza is absent" \
    'command -v eza >/dev/null || alias l | grep -q "ls -lAhrtF"'
check "zsh-autosuggestions defaults: history then completion strategy" \
    '[[ "${ZSH_AUTOSUGGEST_STRATEGY[*]}" == "history completion" && -n "$ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE" ]]'
check "zsh-syntax-highlighting defaults: brackets + pattern highlighters, visible comments" \
    '(( ${ZSH_HIGHLIGHT_HIGHLIGHTERS[(Ie)main]} && ${ZSH_HIGHLIGHT_HIGHLIGHTERS[(Ie)brackets]} && ${ZSH_HIGHLIGHT_HIGHLIGHTERS[(Ie)pattern]} )) && [[ -n "$ZSH_HIGHLIGHT_STYLES[comment]" && -n "$ZSH_HIGHLIGHT_PATTERNS[rm -rf *]" ]]'
check "history-substring-search: unique results, arrows and Ctrl-P/N bound" \
    '[[ "$HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE" == 1 ]] && bindkey -M emacs "^P" | grep -q history-substring-search-up && bindkey -M emacs "^N" | grep -q history-substring-search-down && bindkey "^[[A" | grep -q history-substring-search-up && { [[ -z "${terminfo[kcuu1]:-}" ]] || bindkey "$terminfo[kcuu1]" | grep -q history-substring-search-up; }'
check "completion menu: grouped with descriptions, case-insensitive matching" \
    'zstyle -L ":completion:*" group-name | grep -q group-name && zstyle -L ":completion:*:descriptions" format | grep -q "%d" && zstyle -L ":completion:*" matcher-list | grep -q "m:{"'
check "completions available for tools (zsh-completions and fzf widgets registered)" \
    'print -l $fpath | grep -q zsh-completions/src && (( $+functions[_git] || $+functions[_docker] )) || true'
check "helper functions defined" \
    'for f in myip cheat speedtest dadjoke ipgeo; do [[ "$(whence -w $f)" == *function* ]] || exit 1; done'
check "ZSH points into ftazsh home" '[[ "$ZSH" == "$HOME/.config/ftazsh/oh-my-zsh" ]]'
check "plugin list contains the fish-style trio in the right order" \
    '[[ "${plugins[-1]}" == history-substring-search && "${plugins[-2]}" == zsh-syntax-highlighting ]] && (( ${plugins[(Ie)zsh-autosuggestions]} ))'
check "zsh-autosuggestions is active" '[[ "$(whence -w _zsh_autosuggest_start)" == *function* ]]'
check "zsh-syntax-highlighting is active" '[[ "$(whence -w _zsh_highlight)" == *function* ]]'
check "history-substring-search widgets exist" \
    '[[ "$(whence -w history-substring-search-up)" == *function* ]]'
check "zsh-completions on fpath" 'print -l $fpath | grep -q "custom/plugins/zsh-completions/src"'
check "completion dump lands in ~/.cache/zsh" 'ls "$HOME/.cache/zsh"/.zcompdump* >/dev/null'
check "PATH stays free of duplicates even when a tool re-exports it (typeset -U covers PATH itself)" \
    'export PATH="/usr/bin:$PATH"; export PATH="/usr/bin:$PATH"; (( ${#path} == ${#${(@u)path}} ))'
check "_git completion resolves to zsh's own function, never to Homebrew's site-functions" \
    'typeset d first=; for d in $fpath; do [[ -e "$d/_git" ]] && { first="$d"; break; }; done; [[ -n "$first" && "$first" != *share/zsh/site-functions* ]]'
check_bash "oh-my-zsh worktree is clean: bundled plugins untouched, nested legacy clone gone" \
    '[ -z "$(git -C "$1" status --porcelain)" ] && [ ! -d "$1/plugins/zsh-autosuggestions/.git" ]' "$FTAZSH_HOME/oh-my-zsh"
check "lines a tool appended to the managed ~/.zshrc still take effect (carried into zshrc/zshrc-additions.zsh)" \
    '[[ "$FROM_A_TOOL_APPEND" == 1 ]]'
check_bash "…and ~/.zshrc is ftazsh's file again, with a backup of the changed one" \
    '! grep -q FROM_A_TOOL_APPEND "$HOME/.zshrc" && grep -q FROM_A_TOOL_APPEND "$1/zshrc/zshrc-additions.zsh" && grep -lq FROM_A_TOOL_APPEND "$HOME"/.zshrc-backup-*' "$FTAZSH_HOME"
check "FZF_DEFAULT_OPTS set, old typo FZF_DEFAULT_OPS gone" \
    '[[ -n "$FZF_DEFAULT_OPTS" && -z "${FZF_DEFAULT_OPS:-}" ]]'
if command -v zoxide >/dev/null; then
    check "zoxide: z and zi defined, chpwd hook installed" \
        'whence z >/dev/null && whence zi >/dev/null && [[ "$(whence -w __zoxide_z)" == *function* ]] && (( ${chpwd_functions[(Ie)__zoxide_hook]} ))'
    # zoxide registers its completion only when zle is active, i.e. in a real
    # terminal, so this runs inside a pseudo-terminal (not a tty-less zsh -i -c).
    # zoxide 0.10 registers it on `z`, 0.9 on `__zoxide_z`.
    check_bash "zoxide: completion registered in a real terminal (init ran after compinit)" \
        'out="$(zsh "$1" "$HOME" 1 "print ZOXIDE_COMPDEF=\${_comps[z]:-\${_comps[__zoxide_z]:-none}}")"; printf "%s\n" "$out" | grep -q "ZOXIDE_COMPDEF=__zoxide_z_complete"' \
        "$REPO_DIR/tests/lib/render-prompt.zsh"
    check "zoxide: zi picker preview uses eza when eza is present" \
        '! command -v eza >/dev/null || [[ "$_ZO_FZF_OPTS" == *"--preview="*eza* ]]'
    check_bash "zoxide: re-running the migration did not import ~/.z a second time" \
        '[ -n "$1" ] && [ "$(zoxide query -s legacy-jump-3c9e)" = "$1" ]' "$LEGACY_SCORE"
    check "zoxide: the old z plugin's history (~/.z) was imported and z jumps to it" \
        'z legacy-jump-3c9e && [[ "${PWD:A}" == "${HOME:A}/legacy-jump-3c9e" ]]'
    cp "$FTAZSH_HOME/settings.zsh" "$SCRATCH/settings.zoxide.bak"
    echo "FTAZSH_ZOXIDE_CMD=cd" >> "$FTAZSH_HOME/settings.zsh"
    check "zoxide: FTAZSH_ZOXIDE_CMD=cd makes zoxide the cd (cd jumps, cdi picks, plain paths still work)" \
        '[[ "${aliases[cd]:-}${functions[cd]:-}" == *__zoxide_z* ]] && whence cdi >/dev/null && cd legacy-jump-3c9e && [[ "${PWD:A}" == "${HOME:A}/legacy-jump-3c9e" ]] && cd / && [[ "$PWD" == / ]]'
    cp "$SCRATCH/settings.zoxide.bak" "$FTAZSH_HOME/settings.zsh"
else
    echo "skip: zoxide not installed here; its checks run in the macOS jobs"
fi
check "graceful degradation: no MANPAGER when bat is absent" \
    'command -v bat >/dev/null || [[ -z "${MANPAGER:-}" ]]'
check "graceful degradation: no yazi wrapper / lazygit alias when absent" \
    '{ command -v yazi >/dev/null || ! whence y >/dev/null; } && { command -v lazygit >/dev/null || ! alias lg >/dev/null 2>&1; }'
check "p10k prompt engine loaded" '[[ "$(whence -w p10k)" == *function* ]]'
check "exported POWERLEVEL9K_* overrides survive p10k.zsh (CI/test hermeticity)" \
    '[[ "$POWERLEVEL9K_DISABLE_GITSTATUS" == true && "$POWERLEVEL9K_INSTANT_PROMPT" == off ]]'
check "history sized up" '[[ "$HISTSIZE" -ge 50000 && "$SAVEHIST" -ge 50000 ]]'
check "settings.zsh is sourced (update mode/frequency visible)" \
    '[[ "$FTAZSH_UPDATE_MODE" == prompt && "$FTAZSH_UPDATE_FREQUENCY_DAYS" == 7 ]]'
check "ftazsh CLI is on PATH from the managed bin dir" \
    '[[ "$(whence -p ftazsh)" == "$HOME/.config/ftazsh/bin/ftazsh" ]]'
check "ftazsh version reports the tracked branch" 'ftazsh version | grep -q " on it "'
check "git.zsh loaded: reftable-safe p10k shim installed" \
    '(( FTAZSH_P10K_SHIM )) && [[ "$functions[_p9k_vcs_render]" == *_ftazsh_vcs_fixup* && "$functions[_p9k_vcs_status_save]" == *_ftazsh_vcs_fixup* ]]'
check "git config includes ftazsh defaults" \
    'git config --global --get-all include.path | grep -qx "$HOME/.config/ftazsh/gitconfig"'
check "user git settings win over ftazsh defaults, defaults still apply" \
    '[[ "$(git config --get core.pager)" == less && "$(git config --get merge.conflictStyle)" == zdiff3 && "$(git config --get user.name)" == Integration ]]'
check "ftazsh-pager works with or without delta" \
    'printf "x\n" | "$HOME/.config/ftazsh/bin/ftazsh-pager" --color-only >/dev/null'
check "ftazsh doctor runs (problems expected off-macOS)" \
    'out="$(ftazsh doctor 2>&1)"; rc=$?; [[ "$out" == *"ftazsh doctor"* && "$out" == *"supports reftable"* ]] && (( rc == 0 || rc == 1 ))'

# The old config exported TERM=xterm-256color unconditionally, breaking
# terminals that set their own. TERM must survive the boot untouched.
if TERM=dumb zsh -i -c '[[ "$TERM" == "dumb" ]]' 2>/dev/null; then
    echo "ok: TERM is not hardcoded by ftazsh"
    PASS=$((PASS + 1))
else
    echo "FAIL: TERM was overridden during boot" >&2
    FAIL=$((FAIL + 1))
fi

# User-override contract: files in ~/.config/ftazsh/zshrc/ are sourced and
# may append oh-my-zsh plugins.
cat > "$FTAZSH_HOME/zshrc/99-user-test.zsh" <<'EOT'
alias usertest='echo user-override-works'
plugins+=(encode64)
EOT
check "user file is sourced (alias visible)" 'alias usertest >/dev/null'
check "user-added plugin loads (encode64 function)" '[[ "$(whence -w encode64)" == *function* ]]'
rm -f "$FTAZSH_HOME/zshrc/99-user-test.zsh"

# The seeded example must survive a re-install byte-for-byte after edits.
echo "# user edit" >> "$FTAZSH_HOME/zshrc/personal_rc.zsh"
cp "$FTAZSH_HOME/zshrc/personal_rc.zsh" "$SCRATCH/personal.before"
copy_config_files >/dev/null
if cmp -s "$SCRATCH/personal.before" "$FTAZSH_HOME/zshrc/personal_rc.zsh"; then
    echo "ok: re-install leaves edited personal config untouched"
    PASS=$((PASS + 1))
else
    echo "FAIL: re-install modified the personal config" >&2
    FAIL=$((FAIL + 1))
fi

echo "== Git: reftable repositories and the prompt =="
if git init -q --ref-format=reftable "$SCRATCH/probe" 2>/dev/null; then
    RT="$SCRATCH/rt-repo"
    git init -q --ref-format=reftable -b rt-branch-9f2c "$RT"
    git -C "$RT" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
    echo "dirty" > "$RT/untracked.txt"
    check "git CLI status collector fills VCS_STATUS_* from a reftable repo" \
        "_ftazsh_git_locate '$RT' && _ftazsh_git_is_reftable \$reply[1] && _ftazsh_git_cli_status \$reply[2] \$reply[1] && [[ \$VCS_STATUS_LOCAL_BRANCH == rt-branch-9f2c && \$VCS_STATUS_NUM_UNTRACKED == 1 && \$VCS_STATUS_HAS_UNTRACKED == 1 && \$VCS_STATUS_COMMIT == \$(git -C '$RT' rev-parse HEAD) && \$VCS_STATUS_ACTION == '' ]]"
    check "collector: classic (files) repos are left to gitstatusd" \
        "git init -q --ref-format=files '$SCRATCH/files-probe' && _ftazsh_git_locate '$SCRATCH/files-probe' && ! _ftazsh_git_is_reftable \$reply[1]"
    check "collector: detached HEAD, staged and stash counts" \
        "cd '$RT' && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m second && git checkout -q --detach HEAD~1 && echo s > stashme && git add stashme && git stash -q && git add untracked.txt && _ftazsh_git_locate '$RT' && _ftazsh_git_cli_status \$reply[2] \$reply[1] && [[ -z \$VCS_STATUS_LOCAL_BRANCH && \$VCS_STATUS_NUM_STAGED == 1 && \$VCS_STATUS_HAS_STAGED == 1 && \$VCS_STATUS_STASHES == 1 ]] && git reset -q && git stash drop -q"
    check "collector: merge conflict is reported as an action with conflicted files" \
        "cd '$RT' && git checkout -q rt-branch-9f2c && git checkout -q -b feature && echo a > a.txt && git add a.txt && git -c user.name=t -c user.email=t@t commit -q -m a && git checkout -q rt-branch-9f2c && echo b > a.txt && git add a.txt && git -c user.name=t -c user.email=t@t commit -q -m b && { git -c user.name=t -c user.email=t@t merge -q feature >/dev/null 2>&1 || true; } && _ftazsh_git_locate '$RT' && _ftazsh_git_cli_status \$reply[2] \$reply[1] && [[ \$VCS_STATUS_ACTION == merge && \$VCS_STATUS_NUM_CONFLICTED == 1 && \$VCS_STATUS_HAS_CONFLICTED == 1 ]] && git merge --abort"
    check "collector: cherry-pick in progress (pseudoref inside the reftable) is detected" \
        "cd '$RT' && git checkout -q feature && echo c > c.txt && git add c.txt && git -c user.name=t -c user.email=t@t commit -q -m c && git checkout -q rt-branch-9f2c && echo d > c.txt && git add c.txt && git -c user.name=t -c user.email=t@t commit -q -m d && { git -c user.name=t -c user.email=t@t cherry-pick feature >/dev/null 2>&1 || true; } && _ftazsh_git_locate '$RT' && _ftazsh_git_cli_status \$reply[2] \$reply[1] && [[ \$VCS_STATUS_ACTION == cherry ]] && git cherry-pick --abort"
    # Full prompt rendering in a pseudo-terminal. gitstatusd is enabled so the
    # real p10k path (gitstatusd answer → shim → render) is exercised whenever
    # p10k can fetch its binary; without it p10k falls back to vcs_info.
    RENDER="$(env -u POWERLEVEL9K_DISABLE_GITSTATUS zsh "$REPO_DIR/tests/lib/render-prompt.zsh" "$RT" 60 \
        'print GITSTATUS_ACTIVE=$+GITSTATUS_DAEMON_PID_POWERLEVEL9K' rt-branch-9f2c 2>/dev/null || true)"
    printf '%s\n' "$RENDER" | grep -v GITSTATUS_ACTIVE | tail -3 | sed 's/^/    prompt: /'
    if printf '%s\n' "$RENDER" | grep -q 'GITSTATUS_ACTIVE=1'; then
        echo "    (gitstatusd was running: the real p10k path went through the shim)"
    else
        echo "    (gitstatusd unavailable here: p10k used its vcs_info fallback)"
    fi
    check_bash "prompt shows the reftable repo's branch" 'printf "%s\n" "$1" | grep -q rt-branch-9f2c' "$RENDER"
    check_bash "prompt never shows '.invalid'" '! printf "%s\n" "$1" | grep -q "\.invalid"' "$RENDER"
    # While gitstatusd's query is in flight (slow start, hang), p10k would show
    # "loading"; the shim seeds p10k's cache from the git CLI instead. Emulated
    # inside the pseudo-terminal, where p10k is fully initialized.
    INFLIGHT="$(env -u POWERLEVEL9K_DISABLE_GITSTATUS zsh "$REPO_DIR/tests/lib/render-prompt.zsh" "$RT" 1 \
        'cd "'"$RT"'"; _p9k_fetch_cwd; _p9k__gitstatus_last=(); typeset -g _p9k__gitstatus_next_dir=""; typeset -g _p9k__prompt="" _p9k__prompt_side=$_p9k_vcs_side _p9k__segment_name=vcs; typeset -gi _p9k__has_upglob=0 _p9k__segment_index=_p9k_vcs_index _p9k__line_index=_p9k_vcs_line_index; _p9k_vcs_render; print -rP -- "INFLIGHT_RENDER=[$_p9k__prompt]"; unset _p9k__gitstatus_next_dir' 2>/dev/null || true)"
    printf '%s\n' "$INFLIGHT" | grep '^INFLIGHT_RENDER=' | sed 's/^/    inflight: /'
    check_bash "reftable prompt renders the branch from the git CLI while gitstatusd's query is still in flight (no 'loading')" \
        'printf "%s\n" "$1" | grep "^INFLIGHT_RENDER=\[" | grep -q rt-branch-9f2c && ! printf "%s\n" "$1" | grep "^INFLIGHT_RENDER=\[" | grep -q loading' "$INFLIGHT"
    # Control: with the seeding disabled, the same emulation must show p10k's "loading".
    CONTROL="$(env -u POWERLEVEL9K_DISABLE_GITSTATUS zsh "$REPO_DIR/tests/lib/render-prompt.zsh" "$RT" 1 \
        'cd "'"$RT"'"; _p9k_fetch_cwd; _p9k__gitstatus_last=(); functions[_ftazsh_vcs_seed_cache]="return 0"; typeset -g _p9k__gitstatus_next_dir=""; typeset -g _p9k__prompt="" _p9k__prompt_side=$_p9k_vcs_side _p9k__segment_name=vcs; typeset -gi _p9k__has_upglob=0 _p9k__segment_index=_p9k_vcs_index _p9k__line_index=_p9k_vcs_line_index; _p9k_vcs_render; print -rP -- "CONTROL_RENDER=[$_p9k__prompt]"; unset _p9k__gitstatus_next_dir' 2>/dev/null || true)"
    check_bash "…control: without the seeding the emulation shows p10k's 'loading', so the check above is meaningful" \
        'printf "%s\n" "$1" | grep "^CONTROL_RENDER=\[" | grep -q loading' "$CONTROL"
    FR="$SCRATCH/files-repo"
    git init -q --ref-format=files -b files-branch-4b1d "$FR"
    git -C "$FR" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
    RENDER2="$(env -u POWERLEVEL9K_DISABLE_GITSTATUS zsh "$REPO_DIR/tests/lib/render-prompt.zsh" "$FR" 60 '' files-branch-4b1d 2>/dev/null || true)"
    check_bash "prompt still shows the branch of a classic (files) repo" 'printf "%s\n" "$1" | grep -q files-branch-4b1d' "$RENDER2"
    check "ftazsh reftable status / migrate work" \
        "ftazsh reftable status '$FR' | grep -q 'This repository:  files' && ftazsh reftable migrate '$FR' --yes && git -C '$FR' rev-parse --show-ref-format | grep -qx reftable"
else
    echo "skip: git $(git --version | awk '{print $3}') has no reftable support (need >= 2.45); reftable checks skipped"
fi

echo "== Update flow against the local upstream =="
check "ftazsh update --check: up to date" 'ftazsh update --check'
git -C "$UPSTREAM" commit -q --allow-empty -m "upstream change"
check "ftazsh update --check: reports the new commit" '! ftazsh update --check && [[ -f "$HOME/.config/ftazsh/state/update-available" ]]'
cp "$FTAZSH_HOME/settings.zsh" "$SCRATCH/settings.bak"
echo "FTAZSH_UPDATE_MODE=reminder" >> "$FTAZSH_HOME/settings.zsh"
check_bash "startup hook prints the reminder (reminder mode, pending update)" \
    'env -u FTAZSH_UPDATING zsh -i -c exit 2>&1 | grep -q "\[ftazsh\] Update available (1 new commit)"'
echo "FTAZSH_UPDATE_MODE=disabled" >> "$FTAZSH_HOME/settings.zsh"
check_bash "startup hook is silent when disabled" \
    '! env -u FTAZSH_UPDATING zsh -i -c exit 2>&1 | grep -q "\[ftazsh\]"'
cp "$SCRATCH/settings.bak" "$FTAZSH_HOME/settings.zsh"
check_bash "ftazsh update --yes --no-tools pulls and re-runs the installer (stubbed macOS commands)" \
    "PATH='$STUBS':\$PATH '$FTAZSH_HOME/bin/ftazsh' update --yes --no-tools && [ \"\$(git -C '$FTAZSH_HOME/repo' rev-parse HEAD)\" = \"\$(git -C '$UPSTREAM' rev-parse HEAD)\" ] && [ ! -e '$FTAZSH_HOME/state/update-available' ]"
check "ftazsh update --check: up to date again" 'ftazsh update --check'
check "shell still boots after the update" 'alias l >/dev/null && (( FTAZSH_P10K_SHIM ))'

echo "== Uninstall =="
check_bash "uninstall.sh --yes removes everything and keeps the user's git settings" \
    "'$REPO_DIR/uninstall.sh' --yes >/dev/null && [ ! -d '$FTAZSH_HOME' ] && [ \"\$(git config --global --get user.name)\" = Integration ] && ! git config --global --get-all include.path | grep -q ftazsh && [ ! -e '$HOME/.zshrc' ]"

echo
echo "== Integration results: $PASS passed, $FAIL failed =="
[[ "$FAIL" -eq 0 ]]
