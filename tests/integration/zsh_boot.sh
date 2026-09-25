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

# Pre-existing user state the installer must respect.
printf '[user]\n\tname = Integration\n[core]\n\tpager = less\n' > "$HOME/.gitconfig"

echo "== Building layout in $SCRATCH using installer functions =="
# shellcheck disable=SC1090
source "$REPO_DIR/install.sh"   # source guard keeps main() from running
trap - ERR
trap 'rm -rf "$SCRATCH"' EXIT   # re-arm cleanup (sourcing replaced nothing, but be explicit)
SCRIPT_DIR="$UPSTREAM"          # install from the working-tree snapshot

create_directories
install_omz
install_plugin_repos
install_p10k
sync_repo
copy_config_files
configure_git
record_install_state

echo "== Re-running installer steps (idempotency, real update paths) =="
create_directories
install_omz
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
check "FZF_DEFAULT_OPTS set, old typo FZF_DEFAULT_OPS gone" \
    '[[ -n "$FZF_DEFAULT_OPTS" && -z "${FZF_DEFAULT_OPS:-}" ]]'
check "zoxide active when present (z resolves, __zoxide_z is a function)" \
    '! command -v zoxide >/dev/null || { whence z >/dev/null && [[ "$(whence -w __zoxide_z)" == *function* ]]; }'
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
    RENDER="$(env -u POWERLEVEL9K_DISABLE_GITSTATUS zsh "$REPO_DIR/tests/lib/render-prompt.zsh" "$RT" 2 \
        'print GITSTATUS_ACTIVE=$+GITSTATUS_DAEMON_PID_POWERLEVEL9K' 2>/dev/null || true)"
    printf '%s\n' "$RENDER" | grep -v GITSTATUS_ACTIVE | tail -3 | sed 's/^/    prompt: /'
    if printf '%s\n' "$RENDER" | grep -q 'GITSTATUS_ACTIVE=1'; then
        echo "    (gitstatusd was running: the real p10k path went through the shim)"
    else
        echo "    (gitstatusd unavailable here: p10k used its vcs_info fallback)"
    fi
    check_bash "prompt shows the reftable repo's branch" 'printf "%s\n" "$1" | grep -q rt-branch-9f2c' "$RENDER"
    check_bash "prompt never shows '.invalid'" '! printf "%s\n" "$1" | grep -q "\.invalid"' "$RENDER"
    FR="$SCRATCH/files-repo"
    git init -q --ref-format=files -b files-branch-4b1d "$FR"
    git -C "$FR" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
    RENDER2="$(env -u POWERLEVEL9K_DISABLE_GITSTATUS zsh "$REPO_DIR/tests/lib/render-prompt.zsh" "$FR" 2 2>/dev/null || true)"
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
