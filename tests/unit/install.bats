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

@test "parse_args --unattended and --upgrade set their flags" {
    parse_args --unattended --upgrade
    [ "$UNATTENDED" -eq 1 ]
    [ "$UPGRADE" -eq 1 ]
}

@test "bootstrap_if_needed is a no-op inside a checkout" {
    run bootstrap_if_needed --unattended
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ---------- install_file ----------

@test "install_file replaces the target atomically and sets the mode" {
    echo old > "$HOME/target"
    echo new > "$HOME/src"
    install_file "$HOME/src" "$HOME/target" 755
    [ "$(cat "$HOME/target")" = "new" ]
    [ -x "$HOME/target" ]
    run bash -c "ls $HOME/target.* 2>/dev/null"
    [ "$status" -ne 0 ]
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

@test "backup_zshrc does not duplicate an identical existing backup" {
    echo "user stuff" > "$HOME/.zshrc"
    echo "user stuff" > "$HOME/.zshrc-backup-2025-01-01-000000"
    backup_zshrc
    run bash -c "ls $HOME/.zshrc-backup-* | wc -l"
    [ "${output// /}" -eq 1 ]
}

# ---------- create_directories ----------

@test "create_directories creates layout and migrates zcompdump" {
    touch "$HOME/.zcompdump-host-5.9"
    create_directories
    [ -d "$FTAZSH_HOME" ]
    [ -d "$FTAZSH_HOME/zshrc" ]
    [ -d "$FTAZSH_HOME/bin" ]
    [ -d "$FTAZSH_HOME/state" ]
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
    make_all_fixtures
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
    make_all_fixtures
    create_directories
    install_omz
    mkdir -p "$FTAZSH_HOME/oh-my-zsh/plugins/zsh-autosuggestions"
    install_plugin_repos
    [ ! -d "$FTAZSH_HOME/oh-my-zsh/plugins/zsh-autosuggestions" ]
}

@test "install_p10k clones the theme into custom/themes and re-runs cleanly" {
    make_all_fixtures
    create_directories
    install_omz
    install_p10k
    [ -d "$FTAZSH_HOME/oh-my-zsh/custom/themes/powerlevel10k/.git" ]
    run install_p10k
    [ "$status" -eq 0 ]
}

# ---------- ftazsh's own clone ----------

@test "sync_repo clones this checkout, points origin at the upstream and records the branch" {
    export FTAZSH_REPO_URL="file://$BATS_TEST_TMPDIR/upstream"
    export FTAZSH_REPO_BRANCH="testbranch"
    create_directories
    sync_repo
    [ -d "$FTAZSH_HOME/repo/.git" ]
    [ "$(git -C "$FTAZSH_HOME/repo" remote get-url origin)" = "file://$BATS_TEST_TMPDIR/upstream" ]
    [ "$(git -C "$FTAZSH_HOME/repo" config --get ftazsh.branch)" = "testbranch" ]
    [ "$(git -C "$FTAZSH_HOME/repo" symbolic-ref --short HEAD)" = "testbranch" ]
    [ "$(git -C "$FTAZSH_HOME/repo" rev-parse HEAD)" = "$(git -C "$REPO_DIR" rev-parse HEAD)" ]
    [ -f "$FTAZSH_HOME/repo/install.sh" ]
}

@test "sync_repo re-syncs an existing clone to this checkout" {
    export FTAZSH_REPO_URL="file://$BATS_TEST_TMPDIR/upstream"
    export FTAZSH_REPO_BRANCH="testbranch"
    create_directories
    sync_repo
    # Drift the managed clone, then sync again: it must follow the checkout.
    git -C "$FTAZSH_HOME/repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m drift
    echo garbage > "$FTAZSH_HOME/repo/install.sh"
    run sync_repo
    [ "$status" -eq 0 ]
    [ "$(git -C "$FTAZSH_HOME/repo" rev-parse HEAD)" = "$(git -C "$REPO_DIR" rev-parse HEAD)" ]
    cmp -s "$FTAZSH_HOME/repo/install.sh" "$REPO_DIR/install.sh"
}

@test "sync_repo running from the managed clone leaves it in place" {
    export FTAZSH_REPO_URL="file://$BATS_TEST_TMPDIR/upstream"
    export FTAZSH_REPO_BRANCH="testbranch"
    create_directories
    sync_repo
    SCRIPT_DIR="$FTAZSH_HOME/repo"
    export FTAZSH_REPO_URL="file://$BATS_TEST_TMPDIR/other-upstream"
    run sync_repo
    [ "$status" -eq 0 ]
    [[ "$output" == *"managed ftazsh clone"* ]]
    [ "$(git -C "$FTAZSH_HOME/repo" remote get-url origin)" = "file://$BATS_TEST_TMPDIR/other-upstream" ]
}

@test "sync_repo without a git checkout clones the upstream URL" {
    make_upstream "$BATS_TEST_TMPDIR/upstream" t
    export FTAZSH_REPO_URL="file://$BATS_TEST_TMPDIR/upstream"
    export FTAZSH_REPO_BRANCH="t"
    mkdir -p "$BATS_TEST_TMPDIR/plain"
    cp -R "$REPO_DIR"/. "$BATS_TEST_TMPDIR/plain/"
    rm -rf "$BATS_TEST_TMPDIR/plain/.git"
    SCRIPT_DIR="$BATS_TEST_TMPDIR/plain"
    create_directories
    run sync_repo
    [ "$status" -eq 0 ]
    [ "$(git -C "$FTAZSH_HOME/repo" symbolic-ref --short HEAD)" = "t" ]
    [ "$(git -C "$FTAZSH_HOME/repo" rev-parse HEAD)" = "$(git -C "$BATS_TEST_TMPDIR/upstream" rev-parse HEAD)" ]
}

# ---------- config file installation ----------

@test "copy_config_files installs managed .zshrc, config set, CLI and seeds user files once" {
    create_directories
    copy_config_files
    grep -q "ftazsh-managed" "$HOME/.zshrc"
    for f in ftazshrc.zsh tools.zsh git.zsh update.zsh p10k.zsh gitconfig settings.zsh; do
        [ -f "$FTAZSH_HOME/$f" ]
    done
    [ -x "$FTAZSH_HOME/bin/ftazsh" ]
    [ -x "$FTAZSH_HOME/bin/ftazsh-pager" ]
    [ -f "$FTAZSH_HOME/zshrc/personal_rc.zsh" ]
    echo "FTAZSH_UPDATE_MODE=auto" > "$FTAZSH_HOME/settings.zsh"
    copy_config_files
    [ "$(cat "$FTAZSH_HOME/settings.zsh")" = "FTAZSH_UPDATE_MODE=auto" ]
}

@test "copy_config_files never overwrites user files in zshrc dir" {
    create_directories
    echo "my precious edits" > "$FTAZSH_HOME/zshrc/personal_rc.zsh"
    copy_config_files
    run cat "$FTAZSH_HOME/zshrc/personal_rc.zsh"
    [ "$output" = "my precious edits" ]
}

@test "record_install_state schedules the next check and clears a pending update" {
    create_directories
    echo "deadbeef 3" > "$FTAZSH_HOME/state/update-available"
    record_install_state
    [ ! -e "$FTAZSH_HOME/state/update-available" ]
    grep -q '^last=' "$FTAZSH_HOME/state/update-check"
    grep -q '^next=' "$FTAZSH_HOME/state/update-check"
}

# ---------- git config include ----------

@test "configure_git prepends the include to an existing ~/.gitconfig and keeps user settings" {
    create_directories
    printf '[user]\n\tname = Someone\n' > "$HOME/.gitconfig"
    configure_git
    head -1 "$HOME/.gitconfig" | grep -q "ftazsh-managed"
    [ "$(git config --file "$HOME/.gitconfig" --get include.path)" = "$FTAZSH_HOME/gitconfig" ]
    [ "$(git config --file "$HOME/.gitconfig" --get user.name)" = "Someone" ]
    run configure_git
    [ "$status" -eq 0 ]
    [ "$(git config --file "$HOME/.gitconfig" --get-all include.path | wc -l | tr -d ' ')" -eq 1 ]
}

@test "configure_git creates ~/.gitconfig when there is none" {
    create_directories
    configure_git
    [ "$(git config --file "$HOME/.gitconfig" --get include.path)" = "$FTAZSH_HOME/gitconfig" ]
}

@test "configure_git uses the XDG git config when only that exists" {
    create_directories
    mkdir -p "$HOME/.config/git"
    printf '[user]\n\tname = Xdg\n' > "$HOME/.config/git/config"
    configure_git
    [ ! -e "$HOME/.gitconfig" ]
    [ "$(git config --file "$HOME/.config/git/config" --get include.path)" = "$FTAZSH_HOME/gitconfig" ]
}

@test "user settings override ftazsh git defaults through the include order" {
    create_directories
    copy_config_files
    printf '[core]\n\tpager = less\n' > "$HOME/.gitconfig"
    configure_git
    [ "$(git config --global --get core.pager)" = "less" ]
    [ "$(git config --global --get merge.conflictStyle)" = "zdiff3" ]
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
    [ "$output" -eq $(( ${#FORMULAE[@]} - 2 )) ]
    ! grep -q "^brew install git$" "$STUB_LOG"
    ! grep -q "^brew install jq$" "$STUB_LOG"
    grep -q "^brew install git-delta$" "$STUB_LOG"
}

@test "install_brew_formulae reports failed formulae and returns non-zero" {
    export BREW_FAIL_ON="eza"
    run install_brew_formulae
    [ "$status" -ne 0 ]
    [[ "$output" == *eza* ]]
}

@test "install_brew_casks installs both font casks" {
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts"
    run install_brew_casks
    [ "$status" -eq 0 ]
    grep -q "^brew install --cask font-jetbrains-mono-nerd-font" "$STUB_LOG"
    grep -q "^brew install --cask font-hack-nerd-font" "$STUB_LOG"
}

@test "install_brew_casks reinstalls a listed cask whose font files are missing" {
    export BREW_INSTALLED_CASKS="font-jetbrains-mono-nerd-font font-hack-nerd-font"
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts"
    mkdir -p "$FTAZSH_FONT_DIR"
    touch "$FTAZSH_FONT_DIR/HackNerdFont-Regular.ttf"
    run install_brew_casks
    [ "$status" -eq 0 ]
    grep -q "^brew reinstall --cask font-jetbrains-mono-nerd-font" "$STUB_LOG"
    ! grep -q "^brew reinstall --cask font-hack-nerd-font" "$STUB_LOG"
}

@test "install_brew_casks skips casks that are installed with their files present" {
    export BREW_INSTALLED_CASKS="font-jetbrains-mono-nerd-font font-hack-nerd-font"
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts"
    mkdir -p "$FTAZSH_FONT_DIR"
    touch "$FTAZSH_FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf" "$FTAZSH_FONT_DIR/HackNerdFont-Regular.ttf"
    run install_brew_casks
    [ "$status" -eq 0 ]
    ! grep -q "install --cask" "$STUB_LOG"
}

@test "JBM cask failure falls back to direct download and installs TTFs" {
    export BREW_FAIL_ON="font-jetbrains-mono-nerd-font"
    make_fixture_font_zip "$BATS_TEST_TMPDIR/jbm.zip"
    export FTAZSH_JBM_FONT_URL="file://$BATS_TEST_TMPDIR/jbm.zip"
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts-dest"
    run install_brew_casks
    [ "$status" -eq 0 ]
    [ -f "$FTAZSH_FONT_DIR/JetBrainsMonoNerdFont-ExtraBold.ttf" ]
    [ -f "$FTAZSH_FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf" ]
}

@test "JBM cask failure with a broken download URL fails and names the font" {
    export BREW_FAIL_ON="font-jetbrains-mono-nerd-font"
    export FTAZSH_JBM_FONT_URL="file://$BATS_TEST_TMPDIR/nonexistent.zip"
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts-dest"
    run install_brew_casks
    [ "$status" -ne 0 ]
    [[ "$output" == *font-jetbrains-mono-nerd-font* ]]
}

@test "hack cask failure does not trigger the JBM fallback" {
    export BREW_FAIL_ON="font-hack-nerd-font"
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts-dest"
    run install_brew_casks
    [ "$status" -ne 0 ]
    [ ! -d "$FTAZSH_FONT_DIR" ]
}

@test "upgrade_brew_tools upgrades only outdated managed tools, and only with --upgrade" {
    export BREW_OUTDATED="eza somethingelse bat"
    export BREW_OUTDATED_CASKS="font-hack-nerd-font"
    UPGRADE=0
    run upgrade_brew_tools
    [ "$status" -eq 0 ]
    ! grep -q "^brew upgrade" "$STUB_LOG"
    UPGRADE=1
    run upgrade_brew_tools
    [ "$status" -eq 0 ]
    grep -q "^brew upgrade --formula eza bat$" "$STUB_LOG"
    grep -q "^brew upgrade --cask font-hack-nerd-font$" "$STUB_LOG"
    ! grep -q "somethingelse" "$STUB_LOG"
}

@test "upgrade_brew_tools reports when everything is current" {
    UPGRADE=1
    run upgrade_brew_tools
    [ "$status" -eq 0 ]
    [[ "$output" == *"up to date"* ]]
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

# ---------- whole installer, offline, against stubs ----------

@test "main --unattended installs everything end to end with stubs and fixtures" {
    make_all_fixtures
    export FTAZSH_REPO_URL="file://$BATS_TEST_TMPDIR/upstream"
    export FTAZSH_REPO_BRANCH="t"
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts"
    echo "old config" > "$HOME/.zshrc"
    run main --unattended
    [ "$status" -eq 0 ]
    grep -q "ftazsh-managed" "$HOME/.zshrc"
    grep -q "old config" "$HOME"/.zshrc-backup-*
    [ -d "$FTAZSH_HOME/oh-my-zsh/custom/themes/powerlevel10k" ]
    [ -d "$FTAZSH_HOME/repo/.git" ]
    [ -x "$FTAZSH_HOME/bin/ftazsh" ]
    [ "$(git config --global --get include.path)" = "$FTAZSH_HOME/gitconfig" ]
    [ -f "$FTAZSH_HOME/state/update-check" ]
    grep -q "^brew update" "$STUB_LOG"
    ! grep -q "^brew upgrade" "$STUB_LOG"
    [[ "$output" == *"ftazsh is installed"* ]]
}
