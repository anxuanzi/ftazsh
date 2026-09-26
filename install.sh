#!/bin/bash
# ftazsh installer — a modern zsh environment for macOS.
#
# Installs Homebrew (if missing), a curated set of modern CLI tools, the
# latest git, Nerd Fonts, oh-my-zsh + Powerlevel10k + plugins, and the ftazsh
# configuration under ~/.config/ftazsh. Keeps a clone of ftazsh itself there
# so `ftazsh update` (and the automatic update check) can keep everything
# current.
#
# Safe to re-run: every step is idempotent, and nothing you own
# (~/.config/ftazsh/zshrc/, ~/.config/ftazsh/settings.zsh) is ever overwritten.
#
# Usage: ./install.sh [OPTIONS]
#   -h, --help        Show this help
#       --unattended  Non-interactive mode: never prompts, skips changing
#                     the login shell (prints the command instead). For CI.
#       --upgrade     Also upgrade the Homebrew tools ftazsh manages
#                     (what `ftazsh update` does).
#
# Can also be piped: curl -fsSL https://raw.githubusercontent.com/anxuanzi/ftazsh/main/install.sh | bash
#
# Compatible with the stock macOS bash 3.2.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
FTAZSH_HOME="${FTAZSH_HOME:-$HOME/.config/ftazsh}"
ZSH_TARGET="/bin/zsh"
UNATTENDED=0
UPGRADE=0

# Modern unix tools installed with Homebrew and wired up in tools.zsh / gitconfig.
# `git` first: Homebrew's git is the one ftazsh makes the default (see ftazshrc.zsh).
FORMULAE=(
    git             # latest git (reftable-capable), made the default `git`
    eza             # ls
    bat             # cat / pager
    fd              # find
    ripgrep         # grep
    fzf             # fuzzy finder
    zoxide          # cd
    jq              # JSON
    git-delta       # git diff pager
    difftastic      # structural diff (git dft / git dlog)
    lazygit         # git TUI (lg)
    gh              # GitHub CLI
    dust            # du
    duf             # df
    procs           # ps
    btop            # top
    sd              # sed
    hyperfine       # benchmarking
    tealdeer        # tldr pages
    yazi            # terminal file manager (y)
)
# Fonts, installed per user into ~/Library/Fonts by Homebrew casks (Nerd Fonts
# v3 naming). Each entry is  cask|representative file|nerd-fonts release zip.
# The Nerd Font families (patched with the icons the prompt uses) have a
# fallback: if the cask fails, the family is downloaded straight from the
# official nerd-fonts release. The plain (unpatched) families are best effort.
# The representative file is what the installer and `ftazsh doctor` look for
# to tell whether a family is really present.
FONT_SPECS=(
    "font-jetbrains-mono-nerd-font|JetBrainsMonoNerdFont-Regular.ttf|JetBrainsMono.zip"  # used by the iTerm2 profile
    "font-hack-nerd-font|HackNerdFont-Regular.ttf|Hack.zip"
    "font-meslo-lg-nerd-font|MesloLGSNerdFont-Regular.ttf|Meslo.zip"                     # Powerlevel10k's recommended family
    "font-fira-code-nerd-font|FiraCodeNerdFont-Regular.ttf|FiraCode.zip"
    "font-caskaydia-cove-nerd-font|CaskaydiaCoveNerdFont-Regular.ttf|CascadiaCode.zip"   # Cascadia Code
    "font-sauce-code-pro-nerd-font|SauceCodeProNerdFont-Regular.ttf|SourceCodePro.zip"   # Source Code Pro
    "font-symbols-only-nerd-font|SymbolsNerdFont-Regular.ttf|NerdFontsSymbolsOnly.zip"   # icon fallback for any other font
    "font-jetbrains-mono|JetBrainsMono-Regular.ttf|"
    "font-fira-code|FiraCode-Regular.ttf|"
    "font-cascadia-code|CascadiaCode.ttf|"
    "font-source-code-pro|SourceCodePro[wght].ttf|"
    "font-hack|Hack-Regular.ttf|"
)
CASKS=()
for _spec in "${FONT_SPECS[@]}"; do
    CASKS+=("${_spec%%|*}")
done
unset _spec
NERD_FONT_BASE_URL_DEFAULT="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"

# Default sources. Each is overridable at call time via FTAZSH_* environment
# variables (tests point them at local fixtures; see the *_url/file helpers).
FTAZSH_REPO_URL_DEFAULT="https://github.com/anxuanzi/ftazsh.git"
FTAZSH_REPO_BRANCH_DEFAULT="main"
OMZ_REPO_DEFAULT="https://github.com/ohmyzsh/ohmyzsh.git"
P10K_REPO_DEFAULT="https://github.com/romkatv/powerlevel10k.git"
PLUGIN_BASE_URL_DEFAULT="https://github.com/zsh-users"
PLUGINS=(zsh-autosuggestions zsh-syntax-highlighting zsh-completions)

# Managed config files copied verbatim into $FTAZSH_HOME.
MANAGED_FILES=(ftazshrc.zsh tools.zsh git.zsh update.zsh p10k.zsh gitconfig)
# Small helpers installed into $FTAZSH_HOME/bin.
BIN_FILES=(ftazsh ftazsh-pager)

# Homebrew: never prompt (Homebrew ≥ 6 "ask mode" would otherwise stop an
# unattended run), no env hints, and no auto-update on every single install —
# the installer runs `brew update` once instead.
export HOMEBREW_NO_ASK=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_AUTO_UPDATE=1

#######################################
# Output helpers
#######################################

info() { printf '🔵  %s\n' "$*"; }
ok()   { printf '✅  %s\n' "$*"; }
warn() { printf '⚠️   %s\n' "$*" >&2; }
err()  { printf '❌  %s\n' "$*" >&2; }

# Overridable sources, resolved when used (not when this file is sourced),
# so tests can export FTAZSH_* after sourcing.
omz_repo()        { printf '%s' "${FTAZSH_OMZ_REPO:-$OMZ_REPO_DEFAULT}"; }
p10k_repo()       { printf '%s' "${FTAZSH_P10K_REPO:-$P10K_REPO_DEFAULT}"; }
plugin_base_url() { printf '%s' "${FTAZSH_PLUGIN_BASE_URL:-$PLUGIN_BASE_URL_DEFAULT}"; }
nerd_font_url()   { printf '%s/%s' "${FTAZSH_NERD_FONT_BASE_URL:-$NERD_FONT_BASE_URL_DEFAULT}" "$1"; }
font_dir()        { printf '%s' "${FTAZSH_FONT_DIR:-$HOME/Library/Fonts}"; }
shells_file()     { printf '%s' "${FTAZSH_SHELLS_FILE:-/etc/shells}"; }

usage() {
    cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Installs (or updates) the ftazsh zsh environment on macOS.

Options:
  -h, --help        Show this help and exit
      --unattended  Non-interactive mode: never prompts, skips changing
                    the login shell (prints the command instead). For CI.
      --upgrade     Also upgrade the Homebrew tools ftazsh manages
                    (this is what `ftazsh update` does).
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
            --upgrade)
                UPGRADE=1
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

# Copy a file into place atomically (write a temp file next to the target,
# then rename). A running script that is being replaced keeps reading its
# old inode, so `ftazsh update` can safely replace ftazsh's own files.
install_file() {
    local src="$1" dst="$2" mode="${3:-644}" tmp
    tmp="$(mktemp "${dst}.XXXXXX")"
    cp "$src" "$tmp"
    chmod "$mode" "$tmp"
    mv -f "$tmp" "$dst"
}

#######################################
# Bootstrap (piped install) and preconditions
#######################################

# When run as `curl ... | bash` there is no checkout next to the script:
# clone ftazsh and hand over to the real installer.
bootstrap_if_needed() {
    [[ -f "$SCRIPT_DIR/ftazshrc.zsh" && -f "$SCRIPT_DIR/bin/ftazsh" ]] && return 0
    local url="${FTAZSH_REPO_URL:-$FTAZSH_REPO_URL_DEFAULT}"
    local branch="${FTAZSH_REPO_BRANCH:-$FTAZSH_REPO_BRANCH_DEFAULT}"
    local tmp
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/ftazsh-bootstrap.XXXXXX")"
    info "Fetching ftazsh ($branch) from $url..."
    git clone --quiet --branch "$branch" "$url" "$tmp/ftazsh"
    exec /bin/bash "$tmp/ftazsh/install.sh" "$@"
}

require_macos() {
    local os
    os="$(uname -s)"
    if [[ "$os" != "Darwin" ]]; then
        err "ftazsh supports macOS only (detected: $os)."
        return 1
    fi
    if [[ "$(uname -m)" == "x86_64" ]]; then
        warn "Intel Mac detected. Homebrew moved Intel macOS to Tier 3 in September 2026:"
        warn "no new bottles are built, so some tools may compile from source (slow) or fail."
    fi
}

#######################################
# Homebrew: package manager, tools, fonts
#######################################

ensure_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        ok "Homebrew already installed ($(brew --version 2>/dev/null | head -1))"
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

# One explicit `brew update` so newly added formulae are known, instead of
# Homebrew auto-updating (or not) on each individual install.
update_homebrew() {
    info "Updating Homebrew..."
    if ! brew update --quiet >/dev/null 2>&1; then
        warn "brew update failed (offline?); continuing with the local package index."
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

# cask_font_file CASK → the file that proves the family is installed ("" if unknown).
cask_font_file() {
    local spec rest
    for spec in "${FONT_SPECS[@]}"; do
        if [[ "${spec%%|*}" == "$1" ]]; then
            rest="${spec#*|}"
            printf '%s' "${rest%%|*}"
            return 0
        fi
    done
    printf ''
}

# cask_nerd_zip CASK → the nerd-fonts release zip of the family ("" for plain fonts).
cask_nerd_zip() {
    local spec
    for spec in "${FONT_SPECS[@]}"; do
        if [[ "${spec%%|*}" == "$1" ]]; then
            printf '%s' "${spec##*|}"
            return 0
        fi
    done
    printf ''
}

# in_list NEEDLE ITEM... → true when NEEDLE is one of the ITEMs.
in_list() {
    local needle="$1" item
    shift
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

install_brew_casks() {
    info "Installing fonts (${#CASKS[@]} families): ${CASKS[*]}"
    local installed c file zip dest
    local failed_nerd=() failed_plain=() unverified=()
    installed="$(brew list --cask 2>/dev/null || true)"
    dest="$(font_dir)"
    for c in "${CASKS[@]}"; do
        file="$(cask_font_file "$c")"
        zip="$(cask_nerd_zip "$c")"
        if printf '%s\n' "$installed" | grep -qx "$c"; then
            if [[ -n "$file" && ! -f "$dest/$file" ]]; then
                warn "$c is listed by Homebrew but its font files are missing; reinstalling."
                if brew reinstall --cask "$c"; then
                    ok "$c reinstalled"
                elif [[ -n "$zip" ]] && install_nerd_font_direct "$zip" "$c"; then
                    :
                elif [[ -n "$zip" ]]; then
                    failed_nerd+=("$c")
                else
                    failed_plain+=("$c")
                fi
            else
                ok "$c already installed"
            fi
        elif brew install --cask "$c"; then
            ok "$c installed"
        elif [[ -n "$zip" ]] && install_nerd_font_direct "$zip" "$c"; then
            :  # cask failed but the direct download covered it
        elif [[ -n "$zip" ]]; then
            failed_nerd+=("$c")
        else
            failed_plain+=("$c")
        fi
    done

    # Self-check: every family's representative file should now be present.
    for c in "${CASKS[@]}"; do
        file="$(cask_font_file "$c")"
        [[ -n "$file" && ! -f "$dest/$file" ]] || continue
        in_list "$c" ${failed_nerd[@]+"${failed_nerd[@]}"} ${failed_plain[@]+"${failed_plain[@]}"} && continue
        unverified+=("$c")
    done
    if [[ "${#unverified[@]}" -gt 0 ]]; then
        warn "Installed, but the expected file was not found in ${dest/#$HOME/~}: ${unverified[*]} (a font file may have been renamed upstream; 'ftazsh doctor' shows the details)."
    fi
    if [[ "${#failed_plain[@]}" -gt 0 ]]; then
        warn "Optional (non-Nerd) fonts not installed: ${failed_plain[*]} — the Nerd Font versions cover the terminal; retry with: brew install --cask ${failed_plain[*]}"
    fi
    if [[ "${#failed_nerd[@]}" -gt 0 ]]; then
        err "Failed to install Nerd Fonts (cask and direct download both failed): ${failed_nerd[*]}"
        return 1
    fi
    ok "Fonts ready in ${dest/#$HOME/~}: $(( ${#CASKS[@]} - ${#failed_plain[@]} )) of ${#CASKS[@]} families"
}

# Fallback when a Nerd Font cask is unavailable: fetch the family's archive
# from the official nerd-fonts release and install the TTFs into
# ~/Library/Fonts (per-user font install; no sudo required).
install_nerd_font_direct() {
    local zip="$1" cask="$2" tmp dest
    info "Cask $cask unavailable — downloading $zip from the official nerd-fonts release..."
    tmp="$(mktemp -d)"
    dest="$(font_dir)"
    if curl -fsSL -o "$tmp/$zip" "$(nerd_font_url "$zip")" \
        && unzip -oq "$tmp/$zip" '*.ttf' -d "$tmp/fonts" \
        && mkdir -p "$dest" \
        && cp "$tmp/fonts/"*.ttf "$dest/"; then
        rm -rf "$tmp"
        ok "$cask installed from the nerd-fonts release into $dest"
        return 0
    fi
    rm -rf "$tmp"
    err "Direct download of $zip failed."
    return 1
}

# `--upgrade` / `ftazsh update`: bring the managed tools to their latest
# versions. Only ftazsh's own formulae and casks are touched.
upgrade_brew_tools() {
    [[ "$UPGRADE" -eq 1 ]] || return 0
    info "Upgrading Homebrew tools managed by ftazsh..."
    local outdated f c
    local formulae=() casks=()
    outdated="$(brew outdated --formula --quiet 2>/dev/null || true)"
    for f in "${FORMULAE[@]}"; do
        printf '%s\n' "$outdated" | grep -qx "$f" && formulae+=("$f")
    done
    outdated="$(brew outdated --cask --quiet 2>/dev/null || true)"
    for c in "${CASKS[@]}"; do
        printf '%s\n' "$outdated" | grep -qx "$c" && casks+=("$c")
    done
    if [[ "${#formulae[@]}" -eq 0 && "${#casks[@]}" -eq 0 ]]; then
        ok "All managed tools are up to date"
        return 0
    fi
    if [[ "${#formulae[@]}" -gt 0 ]]; then
        info "Upgrading: ${formulae[*]}"
        brew upgrade --formula "${formulae[@]}" || warn "Some formulae failed to upgrade (see above)."
    fi
    if [[ "${#casks[@]}" -gt 0 ]]; then
        info "Upgrading fonts: ${casks[*]}"
        brew upgrade --cask "${casks[@]}" || warn "Some fonts failed to upgrade (see above)."
    fi
    ok "Tool upgrade finished"
}

# Prime caches so tools work on first use (all optional, never fatal).
prime_tools() {
    if command -v tldr >/dev/null 2>&1; then
        if tldr --update --quiet >/dev/null 2>&1; then
            ok "tldr page cache updated"
        else
            warn "tldr cache update skipped (offline?); run 'tldr --update' later."
        fi
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

    # Don't pile up identical backups (e.g. uninstall → reinstall cycles).
    local newest="" f
    for f in "$HOME"/.zshrc-backup-*; do
        [[ -e "$f" ]] || continue
        if [[ -z "$newest" || "$f" -nt "$newest" ]]; then
            newest="$f"
        fi
    done
    if [[ -n "$newest" ]] && cmp -s "$newest" "$zshrc"; then
        info "Existing ~/.zshrc already backed up as ${newest##*/}."
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
    mkdir -p "$FTAZSH_HOME" "$FTAZSH_HOME/zshrc" "$FTAZSH_HOME/bin" \
             "$FTAZSH_HOME/state" "$HOME/.cache/zsh"

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
        git clone --depth=1 --quiet "$(omz_repo)" "$dest"
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
            git clone --depth=1 --quiet "$(plugin_base_url)/$name" "$dest"
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
        git clone --depth=1 --quiet "$(p10k_repo)" "$dest"
        ok "Powerlevel10k installed"
    fi
}

#######################################
# Upgrades from older ftazsh versions
#######################################

# is_clone_of DIR PATTERN — true when DIR is a git clone whose origin URL
# contains PATTERN (so only clones the old installer made are ever touched).
is_clone_of() {
    local dir="$1" pattern="$2"
    [[ -d "$dir/.git" ]] || return 1
    git -C "$dir" remote get-url origin 2>/dev/null | grep -q -- "$pattern"
}

# Remove what older ftazsh versions installed and this one no longer uses:
#   * plugin clones under oh-my-zsh/custom: k, zsh-history-substring-search
#     (oh-my-zsh's built-in history-substring-search is used now)
#   * ftazsh's own fzf clone and the ~/.fzf.zsh / ~/.fzf.bash it generated
#     (fzf comes from Homebrew now)
#   * the marker clone (dropped; upstream is abandoned)
#   * the multi-gigabyte nerd-fonts clone inside the checkout (fonts come
#     from Homebrew casks now)
# The in-tree zsh-autosuggestions clone is handled by install_plugin_repos.
# zoxide_import_z — imports the z plugin's ~/.z into zoxide. zoxide 0.10 made
# the source a subcommand that finds ~/.z by itself (`zoxide import z`); 0.9
# took `--from z PATH`. Prints zoxide's error message on failure.
# shellcheck disable=SC2069  # stderr is what we want to capture
zoxide_import_z() {
    local err
    err="$(zoxide import z 2>&1 >/dev/null)" && return 0
    [[ "$err" == *"not empty"* ]] && { printf '%s\n' "$err"; return 1; }
    err="$(zoxide import --from z "$HOME/.z" 2>&1 >/dev/null)" && return 0
    printf '%s\n' "$err"
    return 1
}

migrate_legacy_install() {
    local custom="$FTAZSH_HOME/oh-my-zsh/custom/plugins" f size
    local removed=()
    if is_clone_of "$custom/k" "supercrabtree/k"; then
        rm -rf "$custom/k"
        removed+=("plugin clone k")
    fi
    if is_clone_of "$custom/zsh-history-substring-search" "zsh-users/zsh-history-substring-search"; then
        rm -rf "$custom/zsh-history-substring-search"
        removed+=("plugin clone zsh-history-substring-search (oh-my-zsh's built-in one is used)")
    fi
    if is_clone_of "$FTAZSH_HOME/fzf" "junegunn/fzf"; then
        rm -rf "$FTAZSH_HOME/fzf"
        removed+=("old fzf clone (Homebrew's fzf is used)")
        for f in "$HOME/.fzf.zsh" "$HOME/.fzf.bash"; do
            if [[ -f "$f" ]] && grep -q "config/ftazsh/fzf" "$f"; then
                rm -f "$f"
                removed+=("${f/#$HOME/~} (pointed at that clone)")
            fi
        done
    fi
    if is_clone_of "$FTAZSH_HOME/marker" "/marker"; then
        rm -rf "$FTAZSH_HOME/marker"
        removed+=("marker clone")
        if [[ -d "$HOME/.local/share/marker" ]]; then
            info "marker's own data in ~/.local/share/marker was left alone; delete it if you no longer use marker."
        fi
    fi
    if is_clone_of "$SCRIPT_DIR/nerd-fonts" "ryanoasis/nerd-fonts"; then
        size="$(du -sh "$SCRIPT_DIR/nerd-fonts" 2>/dev/null | awk '{print $1}')"
        rm -rf "$SCRIPT_DIR/nerd-fonts"
        removed+=("nerd-fonts clone in the checkout (${size:-?}; fonts come from Homebrew now)")
    fi
    # The original ftazsh used oh-my-zsh's z plugin, which kept your directory
    # history in ~/.z. Seed zoxide with it while zoxide's own database is still
    # empty (zoxide refuses to import into a non-empty one without --merge, so
    # this runs at most once and never touches history zoxide already has).
    if [[ -s "$HOME/.z" ]] && command -v zoxide >/dev/null 2>&1; then
        local import_err
        if import_err="$(zoxide_import_z)"; then
            ok "Imported the old z plugin's directory history (~/.z) into zoxide; ~/.z itself was left in place"
        elif [[ "$import_err" != *"not empty"* ]]; then
            warn "Could not import ~/.z into zoxide: ${import_err:-unknown error}"
        fi
    fi
    if [[ "${#removed[@]}" -gt 0 ]]; then
        ok "Cleaned up leftovers of an older ftazsh version:"
        for f in "${removed[@]}"; do
            echo "    - $f"
        done
    fi
}

#######################################
# ftazsh's own clone (self-update source)
#######################################

# $FTAZSH_HOME/repo is a git clone of ftazsh that `ftazsh update` fetches
# from. It always mirrors the checkout this installer ran from, with its
# origin pointed at the upstream URL and the tracked branch recorded in
# git config (ftazsh.branch). Overrides: FTAZSH_REPO_URL, FTAZSH_REPO_BRANCH.
sync_repo() {
    local repo="$FTAZSH_HOME/repo"
    local src_is_git=0 url="" branch=""

    if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        src_is_git=1
    fi

    # Upstream URL: explicit override > checkout's origin > existing clone's origin > default.
    url="${FTAZSH_REPO_URL:-}"
    if [[ -z "$url" && "$src_is_git" -eq 1 ]]; then
        url="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)"
    fi
    if [[ -z "$url" && -d "$repo/.git" ]]; then
        url="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"
    fi
    [[ -n "$url" ]] || url="$FTAZSH_REPO_URL_DEFAULT"

    # Branch to track: override > checkout's branch > existing clone's record > default.
    branch="${FTAZSH_REPO_BRANCH:-}"
    if [[ -z "$branch" && "$src_is_git" -eq 1 ]]; then
        branch="$(git -C "$SCRIPT_DIR" symbolic-ref --short -q HEAD 2>/dev/null || true)"
    fi
    if [[ -z "$branch" && -d "$repo/.git" ]]; then
        branch="$(git -C "$repo" config --get ftazsh.branch 2>/dev/null || true)"
    fi
    [[ -n "$branch" ]] || branch="$FTAZSH_REPO_BRANCH_DEFAULT"

    if [[ "$src_is_git" -eq 1 && "$(cd "$SCRIPT_DIR" && pwd -P)" == "$(cd "$repo" 2>/dev/null && pwd -P || true)" ]]; then
        info "Running from the managed ftazsh clone."
    elif [[ "$src_is_git" -eq 1 ]]; then
        if [[ -d "$repo/.git" ]]; then
            info "Syncing the managed ftazsh clone with this checkout..."
            git -C "$repo" fetch --quiet "$SCRIPT_DIR" HEAD
            git -C "$repo" reset --quiet --hard
            git -C "$repo" checkout --quiet -B "$branch" FETCH_HEAD
        else
            info "Creating the managed ftazsh clone from this checkout..."
            rm -rf "$repo"
            git -c advice.detachedHead=false clone --quiet "$SCRIPT_DIR" "$repo"
            git -C "$repo" checkout --quiet -B "$branch"
        fi
    elif [[ ! -d "$repo/.git" ]]; then
        info "Cloning ftazsh ($branch) from $url for future updates..."
        rm -rf "$repo"
        if ! git clone --quiet --branch "$branch" "$url" "$repo"; then
            warn "Could not clone $url; 'ftazsh update' will not work until it can."
            return 0
        fi
    fi

    if git -C "$repo" remote get-url origin >/dev/null 2>&1; then
        git -C "$repo" remote set-url origin "$url"
    else
        git -C "$repo" remote add origin "$url"
    fi
    git -C "$repo" config ftazsh.branch "$branch"
    ok "ftazsh clone ready: $(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo '?') on $branch (updates from $url)"
}

copy_config_files() {
    info "Installing configuration files..."
    local f
    install_file "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
    for f in "${MANAGED_FILES[@]}"; do
        install_file "$SCRIPT_DIR/$f" "$FTAZSH_HOME/$f"
    done
    for f in "${BIN_FILES[@]}"; do
        install_file "$SCRIPT_DIR/bin/$f" "$FTAZSH_HOME/bin/$f" 755
    done

    # Files the user owns are seeded once and never overwritten.
    if [[ ! -e "$FTAZSH_HOME/settings.zsh" ]]; then
        cp "$SCRIPT_DIR/settings.zsh" "$FTAZSH_HOME/settings.zsh"
        ok "Settings file seeded at ~/.config/ftazsh/settings.zsh"
    fi
    if [[ ! -e "$FTAZSH_HOME/zshrc/personal_rc.zsh" ]]; then
        cp "$SCRIPT_DIR/personal_rc.zsh" "$FTAZSH_HOME/zshrc/personal_rc.zsh"
        ok "Example personal config seeded in ~/.config/ftazsh/zshrc/"
    else
        info "Personal config directory left untouched."
    fi
    ok "Configuration installed"
}

#######################################
# git: managed defaults via a config include
#######################################

# The global git config file `git config --global` would write to.
gitconfig_target() {
    local xdg="${XDG_CONFIG_HOME:-$HOME/.config}/git/config"
    if [[ -f "$HOME/.gitconfig" ]]; then
        printf '%s' "$HOME/.gitconfig"
    elif [[ -f "$xdg" ]]; then
        printf '%s' "$xdg"
    else
        printf '%s' "$HOME/.gitconfig"
    fi
}

gitconfig_has_include() {
    local file="$1" include="$2"
    [[ -f "$file" ]] || return 1
    git config --file "$file" --get-all include.path 2>/dev/null | grep -qxF "$include"
}

# Include ftazsh's git defaults from the user's global config. The include
# goes at the TOP of the file so that everything the user sets (now or later
# with `git config --global`) takes precedence over ftazsh's defaults.
configure_git() {
    local include="$FTAZSH_HOME/gitconfig" target tmp
    target="$(gitconfig_target)"
    if gitconfig_has_include "$target" "$include"; then
        ok "git already includes ftazsh defaults (${target/#$HOME/~})"
        return 0
    fi
    mkdir -p "$(dirname "$target")"
    tmp="$(mktemp "${target}.ftazsh.XXXXXX")"
    [[ -f "$target" ]] && cp -p "$target" "$tmp"   # inherit the file mode
    {
        printf '# ftazsh-managed: git defaults from ftazsh (removed by uninstall.sh). Anything below overrides them.\n'
        printf '[include]\n\tpath = %s\n' "$include"
        if [[ -f "$target" ]]; then
            printf '\n'
            cat "$target"
        fi
    } > "$tmp"
    mv -f "$tmp" "$target"
    ok "git defaults included from ${target/#$HOME/~} (your own settings win)"
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

    if ! grep -qx "$ZSH_TARGET" "$(shells_file)"; then
        info "Adding $ZSH_TARGET to $(shells_file) (requires sudo)..."
        echo "$ZSH_TARGET" | sudo tee -a "$(shells_file)" >/dev/null
    fi

    info "Changing login shell to $ZSH_TARGET (you may be asked for your password)..."
    chsh -s "$ZSH_TARGET"
    ok "Login shell changed. Takes effect in new terminal windows."
}

#######################################
# Main
#######################################

# Reset the auto-update bookkeeping: a fresh install is up to date, and the
# next background check happens after one full interval.
record_install_state() {
    local state="$FTAZSH_HOME/state"
    mkdir -p "$state"
    rm -f "$state/update-available"
    printf 'last=%s\nnext=%s\n' "$(date +%s)" "$(( $(date +%s) + 7 * 86400 ))" > "$state/update-check"
}

print_summary() {
    echo
    ok "ftazsh is installed! 🎉"
    info "Next steps:"
    echo "    1. Open a new terminal window (or run: exec zsh)"
    echo "    2. Set your terminal font to a Nerd Font, e.g. 'JetBrainsMono Nerd Font' or 'MesloLGS Nerd Font'"
    echo "    3. iTerm2: import iterm2-profile.json (Settings → Profiles → Other Actions → Import JSON)"
    echo "    4. Tune the prompt anytime with: p10k configure"
    echo "    5. Put personal config in ~/.config/ftazsh/zshrc/ — ftazsh never touches that folder"
    echo "    6. Check your setup with: ftazsh doctor   |   keep it current with: ftazsh update"
}

main() {
    parse_args "$@"
    bootstrap_if_needed "$@"
    info "Starting ftazsh installation..."
    require_macos
    ensure_homebrew
    update_homebrew
    install_brew_formulae
    install_brew_casks
    upgrade_brew_tools
    backup_zshrc
    create_directories
    install_omz
    migrate_legacy_install
    install_plugin_repos
    install_p10k
    sync_repo
    copy_config_files
    configure_git
    prime_tools
    record_install_state
    ensure_default_shell
    print_summary
}

# Run only when executed directly (or piped into bash) — sourcing, e.g. from
# tests, is side-effect free.
if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
    trap 'err "Installation failed while running: ${BASH_COMMAND}"' ERR
    main "$@"
fi
