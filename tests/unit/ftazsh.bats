#!/usr/bin/env bats
# Unit tests for the `ftazsh` CLI (bin/ftazsh). A managed clone of this
# checkout is installed under a throwaway HOME, tracking a local "upstream".

load helpers

CLI=""

setup() {
    make_stubs
    make_all_fixtures
    make_upstream "$BATS_TEST_TMPDIR/upstream" t
    mkdir -p "$FTAZSH_HOME/bin" "$FTAZSH_HOME/state"
    git clone -q "file://$BATS_TEST_TMPDIR/upstream" "$FTAZSH_HOME/repo"
    git -C "$FTAZSH_HOME/repo" config ftazsh.branch t
    cp "$REPO_DIR/bin/ftazsh" "$FTAZSH_HOME/bin/ftazsh"
    cp "$REPO_DIR/bin/ftazsh-pager" "$FTAZSH_HOME/bin/ftazsh-pager"
    CLI="$FTAZSH_HOME/bin/ftazsh"
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts"
    export FTAZSH_UPDATE_FREQUENCY_DAYS=7
}

@test "ftazsh help / unknown command" {
    run "$CLI" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: ftazsh"* ]]
    run "$CLI" bogus
    [ "$status" -eq 2 ]
}

@test "ftazsh version shows the clone's commit, branch and upstream" {
    run "$CLI" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"$(git -C "$FTAZSH_HOME/repo" rev-parse --short HEAD)"* ]]
    [[ "$output" == *" on t "* ]]
    [[ "$output" == *"upstream"* ]]
}

@test "ftazsh update --check: up to date (exit 0) and schedules the next check" {
    run "$CLI" update --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"up to date"* ]]
    [ ! -e "$FTAZSH_HOME/state/update-available" ]
    grep -q '^next=' "$FTAZSH_HOME/state/update-check"
}

@test "ftazsh update --check: reports a new upstream commit (exit 1) and records it" {
    commit_upstream "$BATS_TEST_TMPDIR/upstream"
    run "$CLI" update --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"Update available: 1 new commit"* ]]
    read -r sha count < "$FTAZSH_HOME/state/update-available"
    [ "$sha" = "$(git -C "$BATS_TEST_TMPDIR/upstream" rev-parse HEAD)" ]
    [ "$count" = "1" ]
}

@test "ftazsh update --background is silent and only touches state" {
    commit_upstream "$BATS_TEST_TMPDIR/upstream"
    run "$CLI" update --background
    [ -z "$output" ]
    [ -e "$FTAZSH_HOME/state/update-available" ]
}

@test "ftazsh update --check fails cleanly when the upstream is unreachable" {
    git -C "$FTAZSH_HOME/repo" remote set-url origin "file://$BATS_TEST_TMPDIR/does-not-exist"
    run "$CLI" update --check
    [ "$status" -eq 2 ]
    [[ "$output" == *"Could not fetch"* ]]
    run "$CLI" update --background
    [ "$status" -eq 0 ]
    grep -q '^next=' "$FTAZSH_HOME/state/update-check"
}

@test "ftazsh update --yes --no-tools pulls the new version and runs the installer" {
    commit_upstream "$BATS_TEST_TMPDIR/upstream"
    "$CLI" update --check >/dev/null || true
    echo "deadbeef" > "$FTAZSH_HOME/state/update-snooze"
    run "$CLI" update --yes --no-tools
    [ "$status" -eq 0 ]
    [[ "$output" == *"Updating ftazsh"* ]]
    [[ "$output" == *"ftazsh is installed"* ]]
    [ "$(git -C "$FTAZSH_HOME/repo" rev-parse HEAD)" = "$(git -C "$BATS_TEST_TMPDIR/upstream" rev-parse HEAD)" ]
    [ "$(git -C "$FTAZSH_HOME/repo" symbolic-ref --short HEAD)" = "t" ]
    [ ! -e "$FTAZSH_HOME/state/update-available" ]
    [ ! -e "$FTAZSH_HOME/state/update-snooze" ]
    [ -f "$FTAZSH_HOME/tools.zsh" ]
    grep -q ftazsh-managed "$HOME/.zshrc"
    ! grep -q "^brew upgrade" "$STUB_LOG"
}

@test "ftazsh update (already current) still refreshes and upgrades tools by default" {
    export BREW_OUTDATED="eza"
    run "$CLI" update --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"ftazsh itself is up to date"* ]]
    grep -q "^brew upgrade --formula eza$" "$STUB_LOG"
}

@test "ftazsh update honours FTAZSH_UPDATE_TOOLS=0" {
    export BREW_OUTDATED="eza"
    FTAZSH_UPDATE_TOOLS=0 run "$CLI" update --yes
    [ "$status" -eq 0 ]
    ! grep -q "^brew upgrade" "$STUB_LOG"
}

@test "ftazsh reftable on/status/off manage init.defaultRefFormat in the global git config" {
    run "$CLI" reftable on
    [ "$status" -eq 0 ]
    [ "$(git config --global --get init.defaultRefFormat)" = "reftable" ]
    run "$CLI" reftable status
    [ "$status" -eq 0 ]
    [[ "$output" == *"New repositories: reftable"* ]]
    run "$CLI" reftable off
    [ "$status" -eq 0 ]
    ! git config --global --get init.defaultRefFormat
    run "$CLI" reftable status
    [[ "$output" == *"files (git default"* ]]
    run "$CLI" reftable bogus
    [ "$status" -eq 2 ]
}

@test "ftazsh reftable migrate --yes converts a files repository (git >= 2.46)" {
    v="$(git --version | awk '{print $3}')"
    if [ "$(printf '2.46\n%s\n' "$v" | sort -V | head -1)" != "2.46" ]; then skip "git refs migrate needs git >= 2.46 (have $v)"; fi
    local r="$BATS_TEST_TMPDIR/files-repo"
    git init -q --ref-format=files -b main "$r"
    git -C "$r" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
    run "$CLI" reftable migrate "$r" --yes
    [ "$status" -eq 0 ]
    [ "$(git -C "$r" rev-parse --show-ref-format)" = "reftable" ]
    run "$CLI" reftable status "$r"
    [[ "$output" == *"This repository:  reftable"* ]]
    run "$CLI" reftable migrate "$r" --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"already uses reftable"* ]]
}

@test "ftazsh doctor reports problems and exits 1; git checks pass with Homebrew's git first on PATH" {
    ln -s "$(command -v git)" "$STUB_BREW_PREFIX/bin/git"
    PATH="$STUB_BREW_PREFIX/bin:$PATH" run "$CLI" doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *"ftazsh doctor"* ]]
    [[ "$output" == *"is Homebrew's"* ]]
    [[ "$output" == *"supports reftable"* ]]
    [[ "$output" == *"Missing tools"* ]]
    [[ "$output" == *"problem(s) found"* ]]
}

@test "ftazsh uninstall --yes runs the uninstaller from a staged copy" {
    echo "# ftazsh-managed" > "$HOME/.zshrc"
    run "$CLI" uninstall --yes
    [ "$status" -eq 0 ]
    [ ! -d "$FTAZSH_HOME" ]
    [ ! -e "$HOME/.zshrc" ]
}

@test "ftazsh reinstall --yes reinstalls from the latest upstream" {
    commit_upstream "$BATS_TEST_TMPDIR/upstream" "newer"
    echo "# ftazsh-managed" > "$HOME/.zshrc"
    run "$CLI" reinstall --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"ftazsh uninstalled"* ]]
    [[ "$output" == *"ftazsh is installed"* ]]
    [ "$(git -C "$FTAZSH_HOME/repo" rev-parse HEAD)" = "$(git -C "$BATS_TEST_TMPDIR/upstream" rev-parse HEAD)" ]
    [ "$(git -C "$FTAZSH_HOME/repo" remote get-url origin)" = "file://$BATS_TEST_TMPDIR/upstream" ]
}
