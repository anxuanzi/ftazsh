#!/bin/bash
# ftazsh macOS smoke test — run this ON YOUR MAC to verify everything end to
# end without touching your own shell setup:
#
#     make mac-test                      # or: bash tests/macos/smoke.sh [OPTIONS]
#
# What it does
#   * Creates a throwaway HOME, so your ~/.zshrc, ~/.gitconfig,
#     ~/.config/ftazsh and shell history are never touched. Only two download
#     caches are shared with your real HOME so nothing is fetched twice:
#     Homebrew's and Powerlevel10k's gitstatusd cache (~/.cache/gitstatus).
#   * Runs the real installer against it. Homebrew is machine-wide, so the
#     tools and fonts ARE installed for real (they are what you'd get anyway).
#   * Verifies: clean shell boot, tools on PATH, Homebrew's git is the default
#     git, fzf/zoxide wiring, git config include + delta pager, the prompt in a
#     reftable repository (with the real gitstatusd), the ftazsh CLI (doctor,
#     version, reftable helpers), the update flow against a local "upstream"
#     copy of this checkout, the auto-update reminder, idempotent re-install,
#     and that the uninstaller leaves the sandbox clean.
#   * Cleans up: deletes the sandbox, and uninstalls only the Homebrew tools
#     and fonts that were NOT installed before the test (see --keep-tools).
#
# Options
#   -y, --yes           Don't ask for confirmation before starting
#       --keep-tools    Leave the Homebrew tools/fonts the test installed
#       --keep-sandbox  Leave the throwaway HOME for inspection
#   -h, --help          Show this help
#
# Requirements: macOS, Homebrew installed, network access. Takes a few minutes
# the first time (Homebrew downloads).

# shellcheck disable=SC2016,SC2317  # single-quoted strings are code for `bash -c`; helpers are also used from the EXIT trap
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ASSUME_YES=0
KEEP_TOOLS=0
KEEP_SANDBOX=0

usage() { sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes) ASSUME_YES=1 ;;
        --keep-tools) KEEP_TOOLS=1 ;;
        --keep-sandbox) KEEP_SANDBOX=1 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

info() { printf '🔵  %s\n' "$*"; }
ok()   { printf '✅  %s\n' "$*"; }
err()  { printf '❌  %s\n' "$*" >&2; }

#######################################
# Preconditions
#######################################

[[ "$(uname -s)" == Darwin ]] || { err "This smoke test runs on macOS only."; exit 2; }
command -v brew >/dev/null 2>&1 || { err "Homebrew is required (https://brew.sh)."; exit 2; }
[[ -f "$REPO_DIR/install.sh" && -f "$REPO_DIR/bin/ftazsh" ]] || { err "Run from an ftazsh checkout."; exit 2; }

REAL_HOME="$HOME"
BREW_PREFIX="$(brew --prefix)"
# shellcheck disable=SC1091
source "$REPO_DIR/install.sh"     # for FORMULAE / CASKS (side-effect free)

if [[ -n "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ]]; then
    info "Note: this checkout has uncommitted changes. The installer uses the working tree,"
    info "      but 'ftazsh update' reinstalls from committed history; commit for full fidelity."
fi

if [[ "$ASSUME_YES" -ne 1 ]]; then
    echo "This will run the ftazsh installer against a throwaway HOME."
    echo "Homebrew tools/fonts not yet on this Mac will be installed and removed again at the end"
    echo "(use --keep-tools to keep them). Nothing under $REAL_HOME is modified."
    printf 'Continue? [y/N] '
    read -r reply
    case "$reply" in y|Y|yes|YES) ;; *) echo "Aborted."; exit 0 ;; esac
fi

#######################################
# Sandbox
#######################################

TMPBASE="${TMPDIR:-/tmp}"
SANDBOX="$(mktemp -d "${TMPBASE%/}/ftazsh-smoke.XXXXXX")"   # no double slash: macOS TMPDIR ends in /
PRE_FORMULAE="$(brew list --formula 2>/dev/null || true)"
PRE_CASKS="$(brew list --cask 2>/dev/null || true)"
PASS=0
FAIL=0

cleanup() {
    local status=$?
    trap - EXIT
    export HOME="$REAL_HOME"
    echo
    info "Cleaning up..."
    if [[ "$KEEP_TOOLS" -eq 0 ]]; then
        local f c
        for f in "${FORMULAE[@]}"; do
            printf '%s\n' "$PRE_FORMULAE" | grep -qx "$f" && continue
            brew list --formula 2>/dev/null | grep -qx "$f" || continue
            info "Removing $f (was not installed before the test)"
            brew uninstall --formula "$f" >/dev/null 2>&1 || echo "    could not uninstall $f (brew uninstall $f)"
        done
        for c in "${CASKS[@]}"; do
            printf '%s\n' "$PRE_CASKS" | grep -qx "$c" && continue
            brew list --cask 2>/dev/null | grep -qx "$c" || continue
            info "Removing $c (was not installed before the test)"
            brew uninstall --cask "$c" >/dev/null 2>&1 || echo "    could not uninstall $c (brew uninstall --cask $c)"
        done
    else
        info "Keeping installed tools (--keep-tools)."
    fi
    if [[ "$KEEP_SANDBOX" -eq 1 ]]; then
        info "Sandbox kept at $SANDBOX"
    else
        rm -rf "$SANDBOX"
        info "Sandbox removed."
    fi
    echo
    if [[ "$FAIL" -eq 0 && "$status" -eq 0 ]]; then
        ok "macOS smoke test: $PASS checks passed."
    else
        err "macOS smoke test: $PASS passed, $FAIL failed (exit $status)."
        exit 1
    fi
}
trap cleanup EXIT
trap 'exit 130' INT

export HOME="$SANDBOX"
# Homebrew state is machine-wide; keep using the real download cache and
# install fonts where they belong (the real font dir), not into the sandbox.
export HOMEBREW_CACHE="$REAL_HOME/Library/Caches/Homebrew"
export HOMEBREW_CASK_OPTS="--fontdir=$REAL_HOME/Library/Fonts"
export FTAZSH_FONT_DIR="$REAL_HOME/Library/Fonts"
# Powerlevel10k downloads gitstatusd on the first prompt; share the standard
# cache so re-runs (and a Mac that already runs p10k) don't fetch it again.
export GITSTATUS_CACHE_DIR="${GITSTATUS_CACHE_DIR:-${XDG_CACHE_HOME:-$REAL_HOME/.cache}/gitstatus}"
# The test's directory jumps must not land in your real zoxide database.
export _ZO_DATA_DIR="$SANDBOX/zoxide"
# Hermetic prompt boots for the checks (the reftable render check enables gitstatus).
export POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
export POWERLEVEL9K_INSTANT_PROMPT=off
export FTAZSH_UPDATING=1        # no startup update checks in the shells we boot
unset FZF_DEFAULT_OPTS FZF_DEFAULT_COMMAND FZF_CTRL_T_COMMAND FZF_CTRL_T_OPTS \
      FZF_ALT_C_COMMAND FZF_ALT_C_OPTS MANPAGER MANROFFOPT ZDOTDIR

# A local "upstream" so the update flow can be exercised offline.
UPSTREAM="$SANDBOX/upstream"
git clone -q "$REPO_DIR" "$UPSTREAM"
git -C "$UPSTREAM" checkout -q -B smoke
git -C "$UPSTREAM" config user.name smoke
git -C "$UPSTREAM" config user.email smoke@example.com
export FTAZSH_REPO_URL="file://$UPSTREAM"
export FTAZSH_REPO_BRANCH=smoke

# Pre-existing user state the installer must preserve, plus the directory
# history of the original ftazsh's z plugin (~/.z), which zoxide should inherit.
echo 'export SMOKE_PRE_EXISTING_ZSHRC=1' > "$HOME/.zshrc"
git config --global user.name "Smoke Tester"
mkdir -p "$HOME/legacy-jump-3c9e"
printf '%s|42|%s\n' "$HOME/legacy-jump-3c9e" "$(date +%s)" > "$HOME/.z"

FTAZSH_HOME="$HOME/.config/ftazsh"

# check DESCRIPTION COMMAND... — runs the command, records pass/fail.
check() {
    local desc="$1"; shift
    if "$@" >"$SANDBOX/check.log" 2>&1; then
        ok "$desc"; PASS=$((PASS + 1))
    else
        err "$desc"; sed 's/^/    /' "$SANDBOX/check.log" | tail -30 >&2; FAIL=$((FAIL + 1))
    fi
}
# zshi CODE — run CODE in an interactive ftazsh shell (booted from the sandbox HOME).
zshi() { zsh -i -c "$1"; }
# zshli CODE — same, as a login shell (~/.zprofile with `brew shellenv` runs first, like a terminal window).
zshli() { zsh -l -i -c "$1"; }

# Every managed font family must have its representative file in the font dir.
fonts_ok() {
    local c f missing=()
    for c in "${CASKS[@]}"; do
        f="$(cask_font_file "$c")"
        [[ -f "$FTAZSH_FONT_DIR/$f" ]] || missing+=("$c")
    done
    if [[ "${#missing[@]}" -gt 0 ]]; then
        echo "missing font families: ${missing[*]}"
        return 1
    fi
    echo "${#CASKS[@]} font families present in $FTAZSH_FONT_DIR"
}

# zoxide registers its completion only when zle is active, i.e. in a real
# terminal, so this runs inside a pseudo-terminal (not a tty-less zsh -i -c).
# zoxide 0.10 registers it on `z`, 0.9 on `__zoxide_z`.
zoxide_completion_ok() {
    local out
    out="$(zsh "$REPO_DIR/tests/lib/render-prompt.zsh" "$HOME" 1 'print ZOXIDE_COMPDEF=${_comps[z]:-${_comps[__zoxide_z]:-none}}')"
    printf '%s\n' "$out" | tail -3
    printf '%s\n' "$out" | grep -q 'ZOXIDE_COMPDEF=__zoxide_z_complete'
}

# `ftazsh doctor` must pass. The one finding tolerated is a login shell that
# is not zsh: that is a property of the machine (CI runners use bash), not of
# ftazsh, and the summary line is the second ❌ in that case.
doctor_ok() {
    local out rc
    out="$(zsh -i -c 'ftazsh doctor' 2>&1)" && rc=0 || rc=$?
    printf '%s\n' "$out"
    [[ "$rc" -eq 0 ]] && return 0
    [[ "$(printf '%s\n' "$out" | grep -c '❌')" -eq 2 ]] && printf '%s\n' "$out" | grep -q 'Login shell'
}

#######################################
# Install
#######################################

echo
info "== Installing into sandbox HOME $SANDBOX =="
POWERLEVEL9K_DISABLE_GITSTATUS=true "$REPO_DIR/install.sh" --unattended

echo
info "== Checking the installation =="
check "tools on PATH" bash -c '
    for t in git eza bat fd rg fzf zoxide jq delta difft lazygit gh dust duf procs btop sd hyperfine tldr yazi; do
        command -v "$t" >/dev/null || { echo "missing: $t"; exit 1; }
    done'
check "Homebrew git is the default git in ftazsh shells" bash -c "
    got=\$(zsh -i -c 'command -v git'); echo \"git -> \$got\"; [ \"\$got\" = '$BREW_PREFIX/bin/git' ]"
check "git >= 2.45 (reftable-capable)" bash -c '
    v=$(zsh -i -c "git --version" | awk "{print \$3}"); echo "git $v"
    case "$v" in 2.4[5-9]*|2.[5-9]*|[3-9].*) ;; *) exit 1;; esac'
check "all ${#CASKS[@]} font families installed (Nerd Fonts + plain)" fonts_ok
check "old .zshrc backed up, managed .zshrc installed" bash -c '
    grep -q ftazsh-managed "$HOME/.zshrc" && grep -lq SMOKE_PRE_EXISTING_ZSHRC "$HOME"/.zshrc-backup-*'
export POWERLEVEL9K_DISABLE_GITSTATUS=true
check "interactive zsh boots with no stderr output" bash -c '
    err=$(zsh -i -c exit 2>&1 >/dev/null | grep -v "can'"'"'t change option: zle" || true)
    [ -z "$err" ] || { printf "%s\n" "$err"; exit 1; }'
check "fzf + zoxide integrations active (widgets, z/zi, chpwd hook, eza preview for zi)" zshi \
    'whence fzf-history-widget >/dev/null && [[ -n "$FZF_DEFAULT_OPTS" ]] && whence z >/dev/null && whence zi >/dev/null && (( ${chpwd_functions[(Ie)__zoxide_hook]} )) && [[ "$_ZO_FZF_OPTS" == *eza* ]]'
check "zoxide completion registered in a real terminal (z <dir> Space Tab)" zoxide_completion_ok
# Paths are compared resolved (:A): on macOS the sandbox is under /var, a symlink to /private/var.
check "old z plugin history (~/.z) imported into zoxide; z jumps to it" zshi \
    'z legacy-jump-3c9e && [[ "${PWD:A}" == "${HOME:A}/legacy-jump-3c9e" ]]'
cp "$FTAZSH_HOME/settings.zsh" "$SANDBOX/settings.zoxide.bak"
echo "FTAZSH_ZOXIDE_CMD=cd" >> "$FTAZSH_HOME/settings.zsh"
check "FTAZSH_ZOXIDE_CMD=cd makes zoxide the cd (cd jumps, cdi picks, plain paths still work)" zshi \
    '[[ "${aliases[cd]:-}${functions[cd]:-}" == *__zoxide_z* ]] && whence cdi >/dev/null && cd legacy-jump-3c9e && [[ "${PWD:A}" == "${HOME:A}/legacy-jump-3c9e" ]] && cd / && [[ "$PWD" == / ]]'
cp "$SANDBOX/settings.zoxide.bak" "$FTAZSH_HOME/settings.zsh"
check "eza alias runs" zshi 'cd "$HOME" && a >/dev/null'
check "eza is the default ls with icons/colors/git (ls, ll, la, l, lt run)" zshi 'alias ls | grep -q eza && cd "$HOME" && ls >/dev/null && ll >/dev/null && la >/dev/null && l >/dev/null && lt >/dev/null'
check "fish-style plugin defaults active" zshi '[[ "${ZSH_AUTOSUGGEST_STRATEGY[*]}" == "history completion" ]] && (( ${ZSH_HIGHLIGHT_HIGHLIGHTERS[(Ie)brackets]} )) && [[ "$HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE" == 1 ]] && bindkey -M emacs "^P" | grep -q history-substring-search-up'
check "yazi wrapper, lazygit alias, tldr present" zshi 'whence y >/dev/null && alias lg >/dev/null && command -v tldr >/dev/null'
check "login shell: PATH has no duplicate entries after brew shellenv + ftazshrc" zshli \
    'print "PATH=$PATH"; (( ${#path} == ${#${(@u)path}} ))'
check "login shell: git completion is zsh's own _git, ahead of Homebrew's site-functions" zshli \
    'typeset d first=; for d in $fpath; do [[ -e "$d/_git" ]] && { first="$d"; break; }; done; print "first _git in: $first"; [[ -n "$first" && "$first" != *share/zsh/site-functions* ]]'
check "oh-my-zsh worktree is clean (its bundled plugins are left alone)" bash -c \
    '[ -z "$(git -C "$HOME/.config/ftazsh/oh-my-zsh" status --porcelain)" ]'
check "git config include present, user settings kept" bash -c '
    git config --global --get-all include.path | grep -qx "$HOME/.config/ftazsh/gitconfig"
    [ "$(git config --global user.name)" = "Smoke Tester" ]
    head -1 "$HOME/.gitconfig" | grep -q ftazsh-managed'
check "delta is the git pager (via ftazsh-pager)" bash -c '
    git config --get core.pager | grep -q ftazsh-pager
    printf "diff --git a/x b/x\n" | "$HOME/.config/ftazsh/bin/ftazsh-pager" --color-only >/dev/null'
check "ftazsh version" zshi 'ftazsh version'
check "ftazsh doctor passes (a non-zsh login shell is the one tolerated finding)" doctor_ok
check "ftazsh reftable status" zshi 'ftazsh reftable status'
check "p10k reftable shim active" zshi '(( FTAZSH_P10K_SHIM ))'

echo
info "== Prompt in a reftable repository (real gitstatusd) =="
RT="$SANDBOX/rt-repo"
git init -q --ref-format=reftable -b rt-branch-9f2c "$RT"
git -C "$RT" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
check "reftable repo created" bash -c "git -C '$RT' rev-parse --show-ref-format | grep -qx reftable"
unset POWERLEVEL9K_DISABLE_GITSTATUS
info "(Powerlevel10k fetches gitstatusd on the first prompt unless cached; waiting up to 2 minutes)"
RENDER="$(zsh "$REPO_DIR/tests/lib/render-prompt.zsh" "$RT" 120 '' rt-branch-9f2c || true)"
printf '%s\n' "$RENDER" | tail -6 | sed 's/^/    /'
check "prompt shows the reftable branch" bash -c "printf '%s\n' \"\$1\" | grep -q rt-branch-9f2c" _ "$RENDER"
check "prompt does not show '.invalid'" bash -c "! printf '%s\n' \"\$1\" | grep -q '\\.invalid'" _ "$RENDER"
FR="$SANDBOX/files-repo"
git init -q --ref-format=files -b files-branch-4b1d "$FR"
git -C "$FR" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
RENDER2="$(zsh "$REPO_DIR/tests/lib/render-prompt.zsh" "$FR" 60 '' files-branch-4b1d || true)"
check "prompt still shows the branch of a classic (files) repo" bash -c "printf '%s\n' \"\$1\" | grep -q files-branch-4b1d" _ "$RENDER2"
check "ftazsh reftable migrate converts a files repo" bash -c "
    cd '$FR' && zsh -i -c 'ftazsh reftable migrate --yes' && git rev-parse --show-ref-format | grep -qx reftable"
export POWERLEVEL9K_DISABLE_GITSTATUS=true

echo
info "== Update flow against the local upstream =="
check "ftazsh update --check: up to date" zshi 'ftazsh update --check'
git -C "$UPSTREAM" commit -q --allow-empty -m "upstream change 1"
check "ftazsh update --check: reports the new commit" bash -c '! zsh -i -c "ftazsh update --check"'
check "auto-update reminder printed at shell start" bash -c '
    cp "$HOME/.config/ftazsh/settings.zsh" "$HOME/settings.bak"
    echo "FTAZSH_UPDATE_MODE=reminder" >> "$HOME/.config/ftazsh/settings.zsh"
    out=$(env -u FTAZSH_UPDATING zsh -i -c exit 2>&1); cp "$HOME/settings.bak" "$HOME/.config/ftazsh/settings.zsh"
    printf "%s\n" "$out" | grep -q "\[ftazsh\] Update available"'
check "ftazsh update --yes --no-tools applies it" zshi 'ftazsh update --yes --no-tools'
check "managed clone matches upstream after update" bash -c "
    [ \"\$(git -C '$FTAZSH_HOME/repo' rev-parse HEAD)\" = \"\$(git -C '$UPSTREAM' rev-parse HEAD)\" ]"
check "ftazsh update --check: up to date again, reminder gone" bash -c '
    zsh -i -c "ftazsh update --check" && ! env -u FTAZSH_UPDATING zsh -i -c exit 2>&1 | grep -q "Update available"'

echo
info "== Re-install (idempotency) and uninstall =="
echo 'export SMOKE_TOOL_APPENDED=1' >> "$HOME/.zshrc"      # what nvm, conda, bun … do
check "re-running the installer succeeds" "$REPO_DIR/install.sh" --unattended
check "lines a tool appended to ~/.zshrc survive the re-install (moved to zshrc/zshrc-additions.zsh, backed up)" zshi \
    '[[ "$SMOKE_TOOL_APPENDED" == 1 ]] && ! grep -q SMOKE_TOOL_APPENDED "$HOME/.zshrc" && grep -q SMOKE_TOOL_APPENDED "$HOME/.config/ftazsh/zshrc/zshrc-additions.zsh" && grep -lq SMOKE_TOOL_APPENDED "$HOME"/.zshrc-backup-*'
check "personal config untouched by re-install" bash -c '
    echo "# smoke edit" >> "$HOME/.config/ftazsh/zshrc/personal_rc.zsh"
    "'"$REPO_DIR"'/install.sh" --unattended >/dev/null && grep -q "smoke edit" "$HOME/.config/ftazsh/zshrc/personal_rc.zsh"'
check "uninstall.sh --yes runs" "$REPO_DIR/uninstall.sh" --yes
check "sandbox HOME is clean after uninstall" bash -c '
    [ ! -d "$HOME/.config/ftazsh" ]
    grep -q SMOKE_PRE_EXISTING_ZSHRC "$HOME/.zshrc"
    ! git config --global --get-all include.path 2>/dev/null | grep -q ftazsh
    [ "$(git config --global user.name)" = "Smoke Tester" ]
    ls "$HOME"/.zshrc-backup-*-ftazsh-personal >/dev/null'

echo
[[ "$FAIL" -eq 0 ]]
