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

@test "remove_gitconfig_include removes only ftazsh's block and keeps the user's settings and includes" {
    mkdir -p "$FTAZSH_HOME"
    printf '[user]\n\tname = Someone\n[include]\n\tpath = /tmp/theirs\n' > "$HOME/.gitconfig"
    configure_git
    remove_gitconfig_include
    ! grep -q "ftazsh" "$HOME/.gitconfig"
    [ "$(git config --file "$HOME/.gitconfig" --get user.name)" = "Someone" ]
    [ "$(git config --file "$HOME/.gitconfig" --get-all include.path)" = "/tmp/theirs" ]
    [ "$(grep -c '^\[include\]' "$HOME/.gitconfig")" -eq 1 ]
}

@test "remove_gitconfig_include leaves a plain user config alone and restores a pristine file" {
    mkdir -p "$FTAZSH_HOME"
    printf '[user]\n\tname = Someone\n' > "$HOME/.gitconfig"
    cp "$HOME/.gitconfig" "$BATS_TEST_TMPDIR/pristine"
    configure_git
    remove_gitconfig_include
    cmp -s "$HOME/.gitconfig" "$BATS_TEST_TMPDIR/pristine"
    run remove_gitconfig_include
    [ "$status" -eq 0 ]
    [[ "$output" == *"No ftazsh include"* ]]
}

@test "remove_gitconfig_include handles the XDG config file" {
    mkdir -p "$FTAZSH_HOME" "$HOME/.config/git"
    printf '[user]\n\tname = Xdg\n' > "$HOME/.config/git/config"
    configure_git
    remove_gitconfig_include
    ! grep -q ftazsh "$HOME/.config/git/config"
    [ "$(git config --file "$HOME/.config/git/config" --get user.name)" = "Xdg" ]
}

@test "remove_legacy_leftovers removes the old fzf rc files and the checkout's nerd-fonts clone" {
    echo 'source "$HOME/.config/ftazsh/fzf/shell/completion.zsh"' > "$HOME/.fzf.zsh"
    echo 'unrelated' > "$HOME/.fzf.bash"
    make_fake_clone "$BATS_TEST_TMPDIR/checkout/nerd-fonts" "https://github.com/ryanoasis/nerd-fonts.git"
    SCRIPT_DIR="$BATS_TEST_TMPDIR/checkout"
    remove_legacy_leftovers
    [ ! -e "$HOME/.fzf.zsh" ]
    [ -e "$HOME/.fzf.bash" ]
    [ ! -d "$BATS_TEST_TMPDIR/checkout/nerd-fonts" ]
}

@test "backup_personal_config copies the user's zshrc directory next to the .zshrc backups" {
    mkdir -p "$FTAZSH_HOME/zshrc"
    echo "alias x=y" > "$FTAZSH_HOME/zshrc/mine.zsh"
    backup_personal_config
    run bash -c "cat $HOME/.zshrc-backup-*-ftazsh-personal/mine.zsh"
    [ "$output" = "alias x=y" ]
}

@test "remove_caches removes completion dumps and p10k/gitstatus caches only" {
    mkdir -p "$HOME/.cache/zsh" "$HOME/.cache/gitstatus" "$HOME/.cache/other" "$HOME/.cache/bat"
    touch "$HOME/.cache/zsh/.zcompdump-host-5.9" "$HOME/.cache/p10k-instant-prompt-me.zsh" "$HOME/.cache/p10k-dump-me.zsh" "$HOME/.cache/other/keep"
    remove_caches
    [ ! -e "$HOME/.cache/zsh/.zcompdump-host-5.9" ]
    [ ! -d "$HOME/.cache/zsh" ]
    [ ! -e "$HOME/.cache/p10k-instant-prompt-me.zsh" ]
    [ ! -d "$HOME/.cache/gitstatus" ]
    [ -e "$HOME/.cache/other/keep" ]
    [ -d "$HOME/.cache/bat" ]
    PURGE=1
    remove_caches
    [ ! -d "$HOME/.cache/bat" ]
}

@test "remove_tools does nothing without --tools" {
    export BREW_INSTALLED="eza bat"
    remove_tools
    ! grep -q "uninstall" "$STUB_LOG"
}

@test "remove_tools with --tools uninstalls only installed managed formulae and casks" {
    export BREW_INSTALLED="eza bat unrelated"
    export BREW_INSTALLED_CASKS="font-hack-nerd-font"
    REMOVE_TOOLS=1
    run remove_tools
    [ "$status" -eq 0 ]
    grep -q "^brew uninstall --formula eza$" "$STUB_LOG"
    grep -q "^brew uninstall --formula bat$" "$STUB_LOG"
    ! grep -q "unrelated" "$STUB_LOG"
    ! grep -q "^brew uninstall --formula git$" "$STUB_LOG"
    grep -q "^brew uninstall --cask font-hack-nerd-font$" "$STUB_LOG"
    ! grep -q "^brew uninstall --cask font-jetbrains" "$STUB_LOG"
}

@test "uninstall parse_args handles --help, --yes, --tools, --purge and rejects unknowns" {
    run parse_args --help
    [ "$status" -eq 0 ]
    [[ "$output" == *Usage* ]]
    run parse_args --bogus
    [ "$status" -eq 2 ]
    parse_args --yes --purge
    [ "$ASSUME_YES" -eq 1 ]
    [ "$REMOVE_TOOLS" -eq 1 ]
    [ "$PURGE" -eq 1 ]
}

@test "main --yes uninstalls end to end without prompting" {
    echo "# ftazsh-managed" > "$HOME/.zshrc"
    echo "original" > "$HOME/.zshrc-backup-2025-01-01-000000"
    mkdir -p "$FTAZSH_HOME/oh-my-zsh"
    printf '[user]\n\tname = Someone\n' > "$HOME/.gitconfig"
    configure_git
    run main --yes
    [ "$status" -eq 0 ]
    [ ! -d "$FTAZSH_HOME" ]
    run cat "$HOME/.zshrc"
    [ "$output" = "original" ]
    ! grep -q ftazsh "$HOME/.gitconfig"
    [[ "$(cat "$STUB_LOG")" != *"brew uninstall"* ]]
}
