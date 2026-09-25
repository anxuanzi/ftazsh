# Shared helpers for bats unit tests.
# Creates PATH stubs for system commands so installer functions can be
# exercised on any OS without touching the real system.

# Directory of the repo checkout (tests/unit/ -> repo root)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_DIR

# Create a stub HOME and a stub bin dir on PATH.
# After calling, $STUB_LOG records every stubbed command invocation.
make_stubs() {
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    STUB_LOG="$BATS_TEST_TMPDIR/stub.log"
    STUB_BREW_PREFIX="$BATS_TEST_TMPDIR/brew"
    HOME="$BATS_TEST_TMPDIR/home"
    export STUB_BIN STUB_LOG STUB_BREW_PREFIX HOME
    mkdir -p "$STUB_BIN" "$HOME" "$STUB_BREW_PREFIX/bin"
    : > "$STUB_LOG"
    PATH="$STUB_BIN:$PATH"
    export PATH
    # Never let the real user's git config leak into tests.
    unset XDG_CONFIG_HOME GIT_CONFIG_GLOBAL
    export FTAZSH_HOME="$HOME/.config/ftazsh"

    stub_uname "Darwin"

    # brew stub: logs calls.
    #   brew list --formula  -> $BREW_INSTALLED        brew list --cask -> $BREW_INSTALLED_CASKS
    #   brew outdated --formula --quiet -> $BREW_OUTDATED   (--cask -> $BREW_OUTDATED_CASKS)
    #   brew install X       -> fails when X matches $BREW_FAIL_ON
    #   brew --prefix        -> $STUB_BREW_PREFIX
    cat > "$STUB_BIN/brew" <<'STUB'
#!/usr/bin/env bash
echo "brew $*" >> "$STUB_LOG"
case "$1" in
    --prefix)  echo "$STUB_BREW_PREFIX"; exit 0 ;;
    --version) echo "Homebrew 7.0.0"; exit 0 ;;
    list)
        if [[ "${2:-}" == "--cask" ]]; then printf '%s\n' ${BREW_INSTALLED_CASKS:-}; else printf '%s\n' ${BREW_INSTALLED:-}; fi
        exit 0 ;;
    outdated)
        if [[ "${2:-}" == "--cask" ]]; then printf '%s\n' ${BREW_OUTDATED_CASKS:-}; else printf '%s\n' ${BREW_OUTDATED:-}; fi
        exit 0 ;;
    install|reinstall)
        for arg in "$@"; do
            if [[ -n "${BREW_FAIL_ON:-}" && "$arg" == "$BREW_FAIL_ON" ]]; then
                echo "Error: stub failure installing $arg" >&2
                exit 1
            fi
        done ;;
esac
exit 0
STUB

    # chsh stub: logs and succeeds.
    cat > "$STUB_BIN/chsh" <<'STUB'
#!/usr/bin/env bash
echo "chsh $*" >> "$STUB_LOG"
exit 0
STUB

    # dscl stub: prints "UserShell: $DSCL_SHELL"
    cat > "$STUB_BIN/dscl" <<'STUB'
#!/usr/bin/env bash
echo "dscl $*" >> "$STUB_LOG"
echo "UserShell: ${DSCL_SHELL:-/bin/zsh}"
STUB

    chmod +x "$STUB_BIN/brew" "$STUB_BIN/chsh" "$STUB_BIN/dscl"
}

# Point `uname -s` at a given OS name (`uname -m` reports arm64).
stub_uname() {
    local os="$1"
    cat > "$STUB_BIN/uname" <<EOS
#!/usr/bin/env bash
if [[ "\${1:-}" == "-m" ]]; then echo arm64; else echo "$os"; fi
EOS
    chmod +x "$STUB_BIN/uname"
}

# Source the installer with main() suppressed by the BASH_SOURCE guard.
source_installer() {
    # shellcheck disable=SC1090
    source "$REPO_DIR/install.sh"
    # Unit tests drive individual functions; disable exit-on-error and the
    # installer's ERR trap so bats can assert on non-zero returns.
    set +e +u +o pipefail
    trap - ERR
}

# Build a zip of fake TTFs, for font-fallback tests (served via file:// URL).
# usage: make_fixture_font_zip <absolute/path/to/out.zip> [ttf-name...]
make_fixture_font_zip() {
    local out="$1" dir f
    shift
    dir="$(mktemp -d "$BATS_TEST_TMPDIR/fontsrc.XXXXXX")"
    [[ $# -gt 0 ]] || set -- JetBrainsMonoNerdFont-Regular.ttf JetBrainsMonoNerdFont-ExtraBold.ttf
    for f in "$@"; do
        echo "fake font data" > "$dir/$f"
    done
    (cd "$dir" && zip -q "$out" ./*.ttf)
}

# Create the representative font file of every managed family in $FTAZSH_FONT_DIR
# (what a successful cask install leaves behind).
make_installed_fonts() {
    local c
    mkdir -p "$FTAZSH_FONT_DIR"
    for c in "${CASKS[@]}"; do
        touch "$FTAZSH_FONT_DIR/$(cask_font_file "$c")"
    done
}

# Build a local git repo fixture that can be cloned via file://
# usage: make_fixture_repo <parent_dir> <name>
make_fixture_repo() {
    local parent="$1" name="$2" dir
    dir="$parent/$name"
    mkdir -p "$dir"
    git -C "$dir" init -q -b master
    git -C "$dir" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
    echo "# $name" > "$dir/README.md"
    git -C "$dir" add README.md
    git -C "$dir" -c user.email=t@t -c user.name=t commit -q -m readme
}

# Point every remote source at local fixtures so a full installer run is offline.
make_all_fixtures() {
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" ohmyzsh
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" zsh-autosuggestions
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" zsh-syntax-highlighting
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" zsh-completions
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" powerlevel10k
    export FTAZSH_OMZ_REPO="file://$BATS_TEST_TMPDIR/fixtures/ohmyzsh"
    export FTAZSH_P10K_REPO="file://$BATS_TEST_TMPDIR/fixtures/powerlevel10k"
    export FTAZSH_PLUGIN_BASE_URL="file://$BATS_TEST_TMPDIR/fixtures"
}

# A local "upstream" ftazsh: a clone of this checkout on branch $2 (default: t)
# with the current WORKING TREE committed on top, so tests exercise
# uncommitted changes too.
# usage: make_upstream <dir> [branch]
make_upstream() {
    local dir="$1" branch="${2:-t}"
    git clone -q "$REPO_DIR" "$dir"
    git -C "$dir" checkout -q -B "$branch"
    git -C "$dir" config user.name t
    git -C "$dir" config user.email t@t
    git -C "$REPO_DIR" ls-files -co --exclude-standard -z \
        | tar -C "$REPO_DIR" --null -cf - -T - \
        | tar -C "$dir" -xf -
    git -C "$dir" add -A
    git -C "$dir" commit -q --allow-empty -m "working tree snapshot"
}

# Add an empty commit to a fixture/upstream repo.
commit_upstream() {
    git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "${2:-upstream change}"
}
