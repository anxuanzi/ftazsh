#!/usr/bin/env bats
# Unit tests for install.sh functions. All system commands (uname, brew,
# chsh, dscl) are PATH stubs; HOME is a throwaway directory.

load helpers

setup() {
    make_stubs
    source_installer
}

# ---------- require_macos ----------

@test "require_macos rejects non-Darwin systems" {
    stub_uname "Linux"
    run require_macos
    [ "$status" -ne 0 ]
    [[ "$output" == *macOS* ]]
}

@test "require_macos accepts Darwin" {
    stub_uname "Darwin"
    run require_macos
    [ "$status" -eq 0 ]
}

# ---------- argument parsing ----------

@test "parse_args --help prints usage and exits 0" {
    run parse_args --help
    [ "$status" -eq 0 ]
    [[ "$output" == *Usage* ]]
}

@test "parse_args rejects unknown flags with exit 2" {
    run parse_args --bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *Usage* ]]
}

@test "parse_args --unattended sets UNATTENDED=1" {
    parse_args --unattended
    [ "$UNATTENDED" -eq 1 ]
}

# ---------- backup_zshrc ----------

@test "backup_zshrc backs up a foreign .zshrc with a timestamp" {
    echo "user stuff" > "$HOME/.zshrc"
    backup_zshrc
    local backups=("$HOME"/.zshrc-backup-*)
    [ -f "${backups[0]}" ]
    grep -q "user stuff" "${backups[0]}"
}

@test "backup_zshrc skips ftazsh-managed .zshrc" {
    echo "# ftazsh-managed — do not edit" > "$HOME/.zshrc"
    backup_zshrc
    run bash -c "ls $HOME/.zshrc-backup-* 2>/dev/null"
    [ "$status" -ne 0 ]
}

@test "backup_zshrc is a no-op without a .zshrc" {
    run backup_zshrc
    [ "$status" -eq 0 ]
}

# ---------- create_directories ----------

@test "create_directories creates layout and migrates zcompdump" {
    touch "$HOME/.zcompdump-host-5.9"
    create_directories
    [ -d "$FTAZSH_HOME" ]
    [ -d "$FTAZSH_HOME/zshrc" ]
    [ -d "$HOME/.cache/zsh" ]
    [ -f "$HOME/.cache/zsh/.zcompdump-host-5.9" ]
}

@test "create_directories works with no zcompdump files" {
    run create_directories
    [ "$status" -eq 0 ]
}

# ---------- oh-my-zsh + plugin repos (local fixtures, no network) ----------

@test "install_omz clones fresh and updates on re-run" {
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" ohmyzsh
    export FTAZSH_OMZ_REPO="file://$BATS_TEST_TMPDIR/fixtures/ohmyzsh"
    create_directories
    install_omz
    [ -d "$FTAZSH_HOME/oh-my-zsh/.git" ]
    run install_omz
    [ "$status" -eq 0 ]
}

@test "install_plugin_repos clones all three plugins and re-runs cleanly" {
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" ohmyzsh
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" zsh-autosuggestions
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" zsh-syntax-highlighting
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" zsh-completions
    export FTAZSH_OMZ_REPO="file://$BATS_TEST_TMPDIR/fixtures/ohmyzsh"
    export FTAZSH_PLUGIN_BASE_URL="file://$BATS_TEST_TMPDIR/fixtures"
    create_directories
    install_omz
    install_plugin_repos
    [ -d "$FTAZSH_HOME/oh-my-zsh/custom/plugins/zsh-autosuggestions/.git" ]
    [ -d "$FTAZSH_HOME/oh-my-zsh/custom/plugins/zsh-syntax-highlighting/.git" ]
    [ -d "$FTAZSH_HOME/oh-my-zsh/custom/plugins/zsh-completions/.git" ]
    run install_plugin_repos
    [ "$status" -eq 0 ]
}

@test "install_plugin_repos removes legacy in-tree autosuggestions clone" {
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" ohmyzsh
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" zsh-autosuggestions
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" zsh-syntax-highlighting
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" zsh-completions
    export FTAZSH_OMZ_REPO="file://$BATS_TEST_TMPDIR/fixtures/ohmyzsh"
    export FTAZSH_PLUGIN_BASE_URL="file://$BATS_TEST_TMPDIR/fixtures"
    create_directories
    install_omz
    mkdir -p "$FTAZSH_HOME/oh-my-zsh/plugins/zsh-autosuggestions"
    install_plugin_repos
    [ ! -d "$FTAZSH_HOME/oh-my-zsh/plugins/zsh-autosuggestions" ]
}

@test "install_p10k clones the theme into custom/themes and re-runs cleanly" {
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" ohmyzsh
    make_fixture_repo "$BATS_TEST_TMPDIR/fixtures" powerlevel10k
    export FTAZSH_OMZ_REPO="file://$BATS_TEST_TMPDIR/fixtures/ohmyzsh"
    export FTAZSH_P10K_REPO="file://$BATS_TEST_TMPDIR/fixtures/powerlevel10k"
    create_directories
    install_omz
    install_p10k
    [ -d "$FTAZSH_HOME/oh-my-zsh/custom/themes/powerlevel10k/.git" ]
    run install_p10k
    [ "$status" -eq 0 ]
}

# ---------- config file installation ----------

@test "copy_config_files installs managed .zshrc and config set" {
    create_directories
    copy_config_files
    grep -q "ftazsh-managed" "$HOME/.zshrc"
    [ -f "$FTAZSH_HOME/ftazshrc.zsh" ]
    [ -f "$FTAZSH_HOME/tools.zsh" ]
    [ -f "$FTAZSH_HOME/p10k.zsh" ]
    [ -f "$FTAZSH_HOME/zshrc/personal_rc.zsh" ]
}

@test "copy_config_files never overwrites user files in zshrc dir" {
    create_directories
    echo "my precious edits" > "$FTAZSH_HOME/zshrc/personal_rc.zsh"
    copy_config_files
    run cat "$FTAZSH_HOME/zshrc/personal_rc.zsh"
    [ "$output" = "my precious edits" ]
}

# ---------- Homebrew ----------

@test "ensure_homebrew is a no-op when brew exists" {
    run ensure_homebrew
    [ "$status" -eq 0 ]
    [ ! -f "$HOME/.zprofile" ]
}

@test "install_brew_formulae installs only missing formulae" {
    export BREW_INSTALLED="git jq"
    run install_brew_formulae
    [ "$status" -eq 0 ]
    run grep -c "^brew install" "$STUB_LOG"
    [ "$output" -eq 6 ]
    ! grep -q "^brew install git$" "$STUB_LOG"
    ! grep -q "^brew install jq$" "$STUB_LOG"
}

@test "install_brew_formulae reports failed formulae and returns non-zero" {
    export BREW_FAIL_ON="eza"
    run install_brew_formulae
    [ "$status" -ne 0 ]
    [[ "$output" == *eza* ]]
}

@test "install_brew_casks installs both font casks" {
    run install_brew_casks
    [ "$status" -eq 0 ]
    grep -q "font-jetbrains-mono-nerd-font" "$STUB_LOG"
    grep -q "font-hack-nerd-font" "$STUB_LOG"
}

# ---------- default shell ----------

@test "ensure_default_shell skips when login shell is already zsh" {
    export DSCL_SHELL="/bin/zsh"
    run ensure_default_shell
    [ "$status" -eq 0 ]
    ! grep -q "^chsh" "$STUB_LOG"
}

@test "ensure_default_shell respects --unattended (no chsh)" {
    export DSCL_SHELL="/bin/bash"
    UNATTENDED=1
    run ensure_default_shell
    [ "$status" -eq 0 ]
    ! grep -q "^chsh" "$STUB_LOG"
    [[ "$output" == *chsh* ]]
}

@test "ensure_default_shell runs chsh when needed (attended)" {
    export DSCL_SHELL="/bin/bash"
    echo "/bin/zsh" > "$BATS_TEST_TMPDIR/shells"
    export FTAZSH_SHELLS_FILE="$BATS_TEST_TMPDIR/shells"
    UNATTENDED=0
    run ensure_default_shell
    [ "$status" -eq 0 ]
    grep -q "^chsh -s /bin/zsh" "$STUB_LOG"
}
