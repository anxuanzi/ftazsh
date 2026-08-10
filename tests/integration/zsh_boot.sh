#!/usr/bin/env bash
# shellcheck disable=SC2016  # single-quoted strings are zsh code for `zsh -c`
# Integration test: build a REAL ftazsh layout in a scratch HOME (network
# clones of oh-my-zsh and plugins), then boot interactive zsh and verify the
# environment is healthy. Runs on Linux (Docker/CI) and macOS.
#
# The Homebrew/macOS-only steps are not exercised here — they are covered by
# the unit tests (stubbed) and the macOS CI job (real).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

export HOME="$SCRATCH"
export FTAZSH_HOME="$HOME/.config/ftazsh"

# Don't let the invoking shell's environment leak into the boots under test
# (e.g. a developer's own FZF_* exports from a previous ftazsh install).
unset FZF_DEFAULT_OPTS FZF_DEFAULT_OPS FZF_DEFAULT_COMMAND \
      FZF_CTRL_T_COMMAND FZF_CTRL_T_OPTS MANPAGER MANROFFOPT

# Keep the prompt hermetic: no config wizard, no instant prompt console
# output, no gitstatusd download.
export POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
export POWERLEVEL9K_INSTANT_PROMPT=off
export POWERLEVEL9K_DISABLE_GITSTATUS=true

echo "== Building layout in $SCRATCH using installer functions =="
# shellcheck disable=SC1090
source "$REPO_DIR/install.sh"   # source guard keeps main() from running
trap - ERR
trap 'rm -rf "$SCRATCH"' EXIT   # re-arm cleanup (sourcing replaced nothing, but be explicit)

create_directories
install_omz
install_plugin_repos
install_p10k
copy_config_files

echo "== Re-running installer steps (idempotency, real update paths) =="
create_directories
install_omz
install_plugin_repos
install_p10k
copy_config_files

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
check "p10k prompt engine loaded" '[[ "$(whence -w p10k)" == *function* ]]'
check "history sized up" '[[ "$HISTSIZE" -ge 50000 && "$SAVEHIST" -ge 50000 ]]'

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
cat > "$FTAZSH_HOME/zshrc/99-user-test.zsh" <<'EOF'
alias usertest='echo user-override-works'
plugins+=(encode64)
EOF
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

echo
echo "== Integration results: $PASS passed, $FAIL failed =="
[[ "$FAIL" -eq 0 ]]
