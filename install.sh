#!/bin/bash
# ftazsh installer — a modern zsh environment for macOS.
#
# Installs Homebrew (if missing), a curated set of modern CLI tools,
# Nerd Fonts, oh-my-zsh + Powerlevel10k + plugins, and the ftazsh
# configuration under ~/.config/ftazsh.
#
# Safe to re-run: every step is idempotent, and nothing in your personal
# config directory (~/.config/ftazsh/zshrc/) is ever overwritten.
#
# Usage: ./install.sh [OPTIONS]
#   -h, --help        Show this help
#       --unattended  Non-interactive mode: never prompts, skips changing
#                     the login shell (prints the command instead). For CI.
#
# Compatible with the stock macOS bash 3.2.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FTAZSH_HOME="${FTAZSH_HOME:-$HOME/.config/ftazsh}"
ZSH_TARGET="/bin/zsh"
SHELLS_FILE="${FTAZSH_SHELLS_FILE:-/etc/shells}"
UNATTENDED=0

# Modern unix tools installed with Homebrew and wired up in tools.zsh.
FORMULAE=(git eza bat fd ripgrep fzf zoxide jq)
# Nerd Fonts (v3 naming). JetBrains Mono is used by the bundled iTerm2 profile.
CASKS=(font-jetbrains-mono-nerd-font font-hack-nerd-font)

# Repo sources — overridable so tests can point at local fixtures.
OMZ_REPO="${FTAZSH_OMZ_REPO:-https://github.com/ohmyzsh/ohmyzsh.git}"
P10K_REPO="${FTAZSH_P10K_REPO:-https://github.com/romkatv/powerlevel10k.git}"
PLUGIN_BASE_URL="${FTAZSH_PLUGIN_BASE_URL:-https://github.com/zsh-users}"
PLUGINS=(zsh-autosuggestions zsh-syntax-highlighting zsh-completions)

#######################################
# Output helpers
#######################################

info() { printf '🔵  %s\n' "$*"; }
ok()   { printf '✅  %s\n' "$*"; }
warn() { printf '⚠️   %s\n' "$*" >&2; }
err()  { printf '❌  %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Installs the ftazsh zsh environment on macOS.

Options:
  -h, --help        Show this help and exit
      --unattended  Non-interactive mode: never prompts, skips changing
                    the login shell (prints the command instead). For CI.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --unattended)
                UNATTENDED=1
                ;;
            *)
                usage >&2
                err "Unknown option: $1"
                exit 2
                ;;
        esac
        shift
    done
}

#######################################
# Preconditions
#######################################

require_macos() {
    local os
    os="$(uname -s)"
    if [[ "$os" != "Darwin" ]]; then
        err "ftazsh supports macOS only (detected: $os)."
        return 1
    fi
}

#######################################
# Homebrew: package manager, tools, fonts
#######################################

ensure_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        ok "Homebrew already installed"
        return 0
    fi

    info "Installing Homebrew (may ask for your password)..."
    if [[ "$UNATTENDED" -eq 1 ]]; then
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    local brew_bin
    if [[ -x /opt/homebrew/bin/brew ]]; then
        brew_bin=/opt/homebrew/bin/brew            # Apple Silicon
    elif [[ -x /usr/local/bin/brew ]]; then
        brew_bin=/usr/local/bin/brew               # Intel
    else
        err "Homebrew reported success but brew was not found."
        return 1
    fi

    eval "$("$brew_bin" shellenv)"

    # Make brew available in future login shells, exactly once.
    local shellenv_line
    shellenv_line="eval \"\$(${brew_bin} shellenv)\""
    touch "$HOME/.zprofile"
    if ! grep -qF "$shellenv_line" "$HOME/.zprofile"; then
        printf '\n%s\n' "$shellenv_line" >> "$HOME/.zprofile"
        ok "Added Homebrew to ~/.zprofile"
    fi
}

install_brew_formulae() {
    info "Installing command-line tools: ${FORMULAE[*]}"
    local installed f
    local failed=()
    installed="$(brew list --formula 2>/dev/null || true)"
    for f in "${FORMULAE[@]}"; do
        if printf '%s\n' "$installed" | grep -qx "$f"; then
            ok "$f already installed"
        elif brew install "$f"; then
            ok "$f installed"
        else
            failed+=("$f")
        fi
    done
    if [[ "${#failed[@]}" -gt 0 ]]; then
        err "Failed to install: ${failed[*]}"
        return 1
    fi
}

install_brew_casks() {
    info "Installing Nerd Fonts: ${CASKS[*]}"
    local installed c
    local failed=()
    installed="$(brew list --cask 2>/dev/null || true)"
    for c in "${CASKS[@]}"; do
        if printf '%s\n' "$installed" | grep -qx "$c"; then
            ok "$c already installed"
        elif brew install --cask "$c"; then
            ok "$c installed"
        else
            failed+=("$c")
        fi
    done
    if [[ "${#failed[@]}" -gt 0 ]]; then
        err "Failed to install fonts: ${failed[*]}"
        return 1
    fi
}

#######################################
# Filesystem layout and configuration
#######################################

backup_zshrc() {
    local zshrc="$HOME/.zshrc"
    [[ -f "$zshrc" ]] || return 0

    if grep -q "ftazsh-managed" "$zshrc"; then
        info "Existing ~/.zshrc is ftazsh-managed; no backup needed."
        return 0
    fi

    local backup
    backup="$HOME/.zshrc-backup-$(date +%Y-%m-%d-%H%M%S)"
    while [[ -e "$backup" ]]; do
        backup="${backup}.1"
    done
    cp -p "$zshrc" "$backup"
    ok "Backed up existing ~/.zshrc to ${backup##*/}"
}

create_directories() {
    mkdir -p "$FTAZSH_HOME" "$FTAZSH_HOME/zshrc" "$HOME/.cache/zsh"

    # Move stray completion dumps out of $HOME.
    local f
    for f in "$HOME"/.zcompdump*; do
        [[ -e "$f" ]] || continue
        mv -f "$f" "$HOME/.cache/zsh/"
    done
    ok "ftazsh directories ready ($FTAZSH_HOME)"
}

install_omz() {
    local dest="$FTAZSH_HOME/oh-my-zsh"
    if [[ -d "$dest/.git" ]]; then
        info "Updating oh-my-zsh..."
        git -C "$dest" pull --ff-only --quiet \
            || warn "oh-my-zsh update skipped (offline or local changes)."
    else
        info "Installing oh-my-zsh..."
        git clone --depth=1 --quiet "$OMZ_REPO" "$dest"
        ok "oh-my-zsh installed"
    fi
}

install_plugin_repos() {
    local custom="$FTAZSH_HOME/oh-my-zsh/custom/plugins"
    mkdir -p "$custom"

    # Older ftazsh versions cloned zsh-autosuggestions inside the oh-my-zsh
    # worktree, which dirties its git status and breaks `omz update`.
    local legacy="$FTAZSH_HOME/oh-my-zsh/plugins/zsh-autosuggestions"
    if [[ -d "$legacy" ]]; then
        warn "Removing legacy plugin clone inside the oh-my-zsh tree."
        rm -rf "$legacy"
    fi

    local name dest
    for name in "${PLUGINS[@]}"; do
        dest="$custom/$name"
        if [[ -d "$dest/.git" ]]; then
            info "Updating $name..."
            git -C "$dest" pull --ff-only --quiet \
                || warn "$name update skipped (offline or local changes)."
        else
            info "Installing $name..."
            git clone --depth=1 --quiet "$PLUGIN_BASE_URL/$name" "$dest"
        fi
    done
    ok "zsh plugins ready"
}

install_p10k() {
    local dest="$FTAZSH_HOME/oh-my-zsh/custom/themes/powerlevel10k"
    if [[ -d "$dest/.git" ]]; then
        info "Updating Powerlevel10k..."
        git -C "$dest" pull --ff-only --quiet \
            || warn "Powerlevel10k update skipped (offline or local changes)."
    else
        info "Installing Powerlevel10k theme..."
        git clone --depth=1 --quiet "$P10K_REPO" "$dest"
        ok "Powerlevel10k installed"
    fi
}

copy_config_files() {
    info "Installing configuration files..."
    cp -f "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
    cp -f "$SCRIPT_DIR/ftazshrc.zsh" "$FTAZSH_HOME/"
    cp -f "$SCRIPT_DIR/tools.zsh" "$FTAZSH_HOME/"
    cp -f "$SCRIPT_DIR/p10k.zsh" "$FTAZSH_HOME/"

    # The personal config dir belongs to the user — only seed the example
    # on first install, never overwrite anything in it.
    if [[ ! -e "$FTAZSH_HOME/zshrc/personal_rc.zsh" ]]; then
        cp "$SCRIPT_DIR/personal_rc.zsh" "$FTAZSH_HOME/zshrc/personal_rc.zsh"
        ok "Example personal config seeded in ~/.config/ftazsh/zshrc/"
    else
        info "Personal config directory left untouched."
    fi
    ok "Configuration installed"
}

#######################################
# Login shell
#######################################

current_login_shell() {
    local shell=""
    if command -v dscl >/dev/null 2>&1; then
        shell="$(dscl . -read "/Users/${USER:-$(id -un)}" UserShell 2>/dev/null | awk '{print $2}' || true)"
    fi
    [[ -n "$shell" ]] || shell="${SHELL:-}"
    printf '%s' "$shell"
}

ensure_default_shell() {
    local current
    current="$(current_login_shell)"

    if [[ "${current##*/}" == "zsh" ]]; then
        ok "Login shell is already zsh ($current); nothing to change."
        return 0
    fi

    if [[ "$UNATTENDED" -eq 1 ]]; then
        info "Unattended mode: login shell unchanged. To switch later, run: chsh -s $ZSH_TARGET"
        return 0
    fi

    if ! grep -qx "$ZSH_TARGET" "$SHELLS_FILE"; then
        info "Adding $ZSH_TARGET to $SHELLS_FILE (requires sudo)..."
        echo "$ZSH_TARGET" | sudo tee -a "$SHELLS_FILE" >/dev/null
    fi

    info "Changing login shell to $ZSH_TARGET (you may be asked for your password)..."
    chsh -s "$ZSH_TARGET"
    ok "Login shell changed. Takes effect in new terminal windows."
}

#######################################
# Main
#######################################

print_summary() {
    echo
    ok "ftazsh is installed! 🎉"
    info "Next steps:"
    echo "    1. Open a new terminal window (or run: exec zsh)"
    echo "    2. Set your terminal font to 'JetBrainsMono Nerd Font' or 'Hack Nerd Font'"
    echo "    3. iTerm2: import iterm2-profile.json (Settings → Profiles → Other Actions → Import JSON)"
    echo "    4. Tune the prompt anytime with: p10k configure"
    echo "    5. Put personal config in ~/.config/ftazsh/zshrc/ — ftazsh never touches that folder"
}

main() {
    parse_args "$@"
    info "Starting ftazsh installation..."
    require_macos
    ensure_homebrew
    install_brew_formulae
    install_brew_casks
    backup_zshrc
    create_directories
    install_omz
    install_plugin_repos
    install_p10k
    copy_config_files
    ensure_default_shell
    print_summary
}

# Run only when executed directly — sourcing (e.g. from tests) is side-effect free.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    trap 'err "Installation failed while running: ${BASH_COMMAND}"' ERR
    main "$@"
fi
