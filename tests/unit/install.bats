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

# ---------- upgrades from older ftazsh versions ----------

@test "migrate_legacy_install removes what the old installer left and nothing else" {
    create_directories
    local custom="$FTAZSH_HOME/oh-my-zsh/custom/plugins"
    make_fake_clone "$custom/k" "https://github.com/supercrabtree/k"
    make_fake_clone "$custom/zsh-history-substring-search" "https://github.com/zsh-users/zsh-history-substring-search"
    make_fake_clone "$custom/my-own-plugin" "https://github.com/someone/my-own-plugin"
    mkdir -p "$custom/hand-copied-k"
    make_fake_clone "$FTAZSH_HOME/fzf" "https://github.com/junegunn/fzf.git"
    make_fake_clone "$FTAZSH_HOME/marker" "https://github.com/jotyGill/marker"
    echo '[[ -f "$HOME/.config/ftazsh/fzf/shell/key-bindings.zsh" ]] && source ...' > "$HOME/.fzf.zsh"
    echo 'my own fzf setup' > "$HOME/.fzf.bash"
    mkdir -p "$BATS_TEST_TMPDIR/checkout"
    make_fake_clone "$BATS_TEST_TMPDIR/checkout/nerd-fonts" "https://github.com/ryanoasis/nerd-fonts.git"
    SCRIPT_DIR="$BATS_TEST_TMPDIR/checkout"
    run migrate_legacy_install
    [ "$status" -eq 0 ]
    [[ "$output" == *"older ftazsh"* ]]
    [ ! -d "$custom/k" ]
    [ ! -d "$custom/zsh-history-substring-search" ]
    [ -d "$custom/my-own-plugin" ]
    [ -d "$custom/hand-copied-k" ]
    [ ! -d "$FTAZSH_HOME/fzf" ]
    [ ! -d "$FTAZSH_HOME/marker" ]
    [ ! -e "$HOME/.fzf.zsh" ]
    [ -e "$HOME/.fzf.bash" ]
    [ ! -d "$BATS_TEST_TMPDIR/checkout/nerd-fonts" ]
}

@test "migrate_legacy_install is silent on a current layout" {
    create_directories
    run migrate_legacy_install
    [ "$status" -eq 0 ]
    [ -z "$output" ]
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

@test "install_brew_casks installs every font family" {
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts"
    run install_brew_casks
    [ "$status" -eq 0 ]
    run grep -c "^brew install --cask" "$STUB_LOG"
    [ "$output" -eq "${#CASKS[@]}" ]
    grep -q "^brew install --cask font-jetbrains-mono-nerd-font" "$STUB_LOG"
    grep -q "^brew install --cask font-meslo-lg-nerd-font" "$STUB_LOG"
    grep -q "^brew install --cask font-symbols-only-nerd-font" "$STUB_LOG"
    grep -q "^brew install --cask font-fira-code$" "$STUB_LOG"
}

@test "install_brew_casks reinstalls a listed cask whose font files are missing" {
    export BREW_INSTALLED_CASKS="${CASKS[*]}"
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts"
    make_installed_fonts
    rm "$FTAZSH_FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf"
    run install_brew_casks
    [ "$status" -eq 0 ]
    grep -q "^brew reinstall --cask font-jetbrains-mono-nerd-font" "$STUB_LOG"
    [ "$(grep -c "^brew reinstall" "$STUB_LOG")" -eq 1 ]
    ! grep -q "^brew install --cask" "$STUB_LOG"
}

@test "install_brew_casks skips families that are installed with their files present" {
    export BREW_INSTALLED_CASKS="${CASKS[*]}"
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts"
    make_installed_fonts
    run install_brew_casks
    [ "$status" -eq 0 ]
    ! grep -q "install --cask" "$STUB_LOG"
    [[ "$output" == *"${#CASKS[@]} of ${#CASKS[@]} families"* ]]
}

@test "a Nerd Font cask failure falls back to the nerd-fonts release download" {
    export BREW_FAIL_ON="font-jetbrains-mono-nerd-font"
    mkdir -p "$BATS_TEST_TMPDIR/nerd"
    make_fixture_font_zip "$BATS_TEST_TMPDIR/nerd/JetBrainsMono.zip"
    export FTAZSH_NERD_FONT_BASE_URL="file://$BATS_TEST_TMPDIR/nerd"
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts-dest"
    run install_brew_casks
    [ "$status" -eq 0 ]
    [ -f "$FTAZSH_FONT_DIR/JetBrainsMonoNerdFont-ExtraBold.ttf" ]
    [ -f "$FTAZSH_FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf" ]
    [[ "$output" == *"installed from the nerd-fonts release"* ]]
}

@test "every Nerd Font family has a working release fallback (Hack, Meslo, Symbols)" {
    export BREW_FAIL_ON="font-hack-nerd-font"
    mkdir -p "$BATS_TEST_TMPDIR/nerd"
    make_fixture_font_zip "$BATS_TEST_TMPDIR/nerd/Hack.zip" HackNerdFont-Regular.ttf HackNerdFont-Bold.ttf
    export FTAZSH_NERD_FONT_BASE_URL="file://$BATS_TEST_TMPDIR/nerd"
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts-dest"
    run install_brew_casks
    [ "$status" -eq 0 ]
    [ -f "$FTAZSH_FONT_DIR/HackNerdFont-Regular.ttf" ]
    [ "$(cask_nerd_zip font-meslo-lg-nerd-font)" = "Meslo.zip" ]
    [ "$(cask_nerd_zip font-symbols-only-nerd-font)" = "NerdFontsSymbolsOnly.zip" ]
    [ -z "$(cask_nerd_zip font-fira-code)" ]
}

@test "a Nerd Font whose cask and download both fail makes the installer fail and names it" {
    export BREW_FAIL_ON="font-jetbrains-mono-nerd-font"
    export FTAZSH_NERD_FONT_BASE_URL="file://$BATS_TEST_TMPDIR/nonexistent"
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts-dest"
    run install_brew_casks
    [ "$status" -ne 0 ]
    [[ "$output" == *"Failed to install Nerd Fonts"*font-jetbrains-mono-nerd-font* ]]
}

@test "a plain (non-Nerd) font cask failure is a warning, not an error" {
    export BREW_FAIL_ON="font-fira-code"
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts-dest"
    run install_brew_casks
    [ "$status" -eq 0 ]
    [[ "$output" == *"Optional (non-Nerd) fonts not installed: font-fira-code"* ]]
    ! grep -q "nerd-fonts release" <<< "$output"
}

@test "install_brew_casks warns about families whose file is missing after a successful install" {
    export FTAZSH_FONT_DIR="$BATS_TEST_TMPDIR/fonts-dest"
    run install_brew_casks
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected file was not found"* ]]
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
