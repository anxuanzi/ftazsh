#!/usr/bin/env bats
# Unit tests for uninstall.sh functions.

load helpers

setup() {
    make_stubs
    # shellcheck disable=SC1090
    source "$REPO_DIR/uninstall.sh"
    set +e +u +o pipefail
    trap - ERR
}

@test "restore_zshrc restores the newest backup over a managed zshrc" {
    echo "# ftazsh-managed" > "$HOME/.zshrc"
    echo "old backup" > "$HOME/.zshrc-backup-2024-01-01-000000"
    echo "new backup" > "$HOME/.zshrc-backup-2025-06-15-120000"
    touch -t 202401010000 "$HOME/.zshrc-backup-2024-01-01-000000"
    touch -t 202506151200 "$HOME/.zshrc-backup-2025-06-15-120000"
    restore_zshrc
    run cat "$HOME/.zshrc"
    [ "$output" = "new backup" ]
}

@test "restore_zshrc removes a managed zshrc when no backup exists" {
    echo "# ftazsh-managed" > "$HOME/.zshrc"
    restore_zshrc
    [ ! -e "$HOME/.zshrc" ]
}

@test "restore_zshrc never touches a foreign zshrc" {
    echo "my own config" > "$HOME/.zshrc"
    echo "backup" > "$HOME/.zshrc-backup-2025-01-01-000000"
    restore_zshrc
    run cat "$HOME/.zshrc"
    [ "$output" = "my own config" ]
}

@test "remove_ftazsh_home deletes the config tree and tolerates absence" {
    mkdir -p "$FTAZSH_HOME/oh-my-zsh"
    remove_ftazsh_home
    [ ! -d "$FTAZSH_HOME" ]
    run remove_ftazsh_home
    [ "$status" -eq 0 ]
}

@test "uninstall parse_args handles --help, --yes and rejects unknowns" {
    run parse_args --help
    [ "$status" -eq 0 ]
    [[ "$output" == *Usage* ]]
    run parse_args --bogus
    [ "$status" -eq 2 ]
    parse_args --yes
    [ "$ASSUME_YES" -eq 1 ]
}

@test "main --yes uninstalls end to end without prompting" {
    echo "# ftazsh-managed" > "$HOME/.zshrc"
    echo "original" > "$HOME/.zshrc-backup-2025-01-01-000000"
    mkdir -p "$FTAZSH_HOME/oh-my-zsh"
    run main --yes
    [ "$status" -eq 0 ]
    [ ! -d "$FTAZSH_HOME" ]
    run cat "$HOME/.zshrc"
    [ "$output" = "original" ]
    [[ "$(cat "$STUB_LOG")" != *brew* ]]
}
