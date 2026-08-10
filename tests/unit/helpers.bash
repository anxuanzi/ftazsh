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
    HOME="$BATS_TEST_TMPDIR/home"
    export STUB_BIN STUB_LOG HOME
    mkdir -p "$STUB_BIN" "$HOME"
    : > "$STUB_LOG"
    PATH="$STUB_BIN:$PATH"
    export PATH

    stub_uname "Darwin"

    # brew stub: logs calls; `brew list --formula` prints $BREW_INSTALLED;
    # `brew install X` fails when X matches $BREW_FAIL_ON.
    cat > "$STUB_BIN/brew" <<'EOF'
#!/usr/bin/env bash
echo "brew $*" >> "$STUB_LOG"
if [[ "$1" == "list" ]]; then
    printf '%s\n' ${BREW_INSTALLED:-}
    exit 0
fi
if [[ "$1" == "install" ]]; then
    for arg in "$@"; do
        if [[ -n "${BREW_FAIL_ON:-}" && "$arg" == "$BREW_FAIL_ON" ]]; then
            echo "Error: stub failure installing $arg" >&2
            exit 1
        fi
    done
fi
exit 0
EOF

    # chsh stub: logs and succeeds.
    cat > "$STUB_BIN/chsh" <<'EOF'
#!/usr/bin/env bash
echo "chsh $*" >> "$STUB_LOG"
exit 0
EOF

    # dscl stub: prints "UserShell: $DSCL_SHELL"
    cat > "$STUB_BIN/dscl" <<'EOF'
#!/usr/bin/env bash
echo "dscl $*" >> "$STUB_LOG"
echo "UserShell: ${DSCL_SHELL:-/bin/zsh}"
EOF

    chmod +x "$STUB_BIN/brew" "$STUB_BIN/chsh" "$STUB_BIN/dscl"
}

# Point `uname -s` at a given OS name.
stub_uname() {
    local os="$1"
    cat > "$STUB_BIN/uname" <<EOF
#!/usr/bin/env bash
echo "$os"
EOF
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
