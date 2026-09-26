#!/bin/bash
# ftazsh uninstaller — removes everything ftazsh set up.
#
# Always:
#   * restores your most recent ~/.zshrc backup (or removes the ftazsh-managed one)
#   * removes ftazsh's include from your global git config (your own settings stay)
#   * deletes ~/.config/ftazsh (oh-my-zsh, plugins, Powerlevel10k, the ftazsh
#     clone and CLI, managed configs — and your ~/.config/ftazsh/zshrc/ files,
#     which are backed up next to your ~/.zshrc backups first)
#   * deletes the caches ftazsh created (completion dumps, p10k, gitstatus)
# Optional:
#   --tools  also `brew uninstall`s the tools and fonts ftazsh manages
#   --purge  --tools plus those tools' caches (bat, tealdeer)
# Never touched: Homebrew itself, ~/.zprofile, your ~/.zshrc-backup-* files,
# zoxide's directory database.
#
# Usage: ./uninstall.sh [OPTIONS]
#   -h, --help   Show this help
#   -y, --yes    Do not ask for confirmation
#       --tools  Also uninstall the Homebrew tools and fonts ftazsh manages
#       --purge  --tools plus the tools' caches

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
FTAZSH_HOME="${FTAZSH_HOME:-$HOME/.config/ftazsh}"

# Reuse the tool list and git-config helpers from the installer (sourcing it
# is side-effect free). Our own functions below override its usage/main.
# shellcheck source=install.sh
source "$SCRIPT_DIR/install.sh"

ASSUME_YES=0
REMOVE_TOOLS=0
PURGE=0

info() { printf '🔵  %s\n' "$*"; }
ok()   { printf '✅  %s\n' "$*"; }
warn() { printf '⚠️   %s\n' "$*" >&2; }
err()  { printf '❌  %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [OPTIONS]

Removes the ftazsh zsh environment and restores your previous ~/.zshrc.

Options:
  -h, --help   Show this help and exit
  -y, --yes    Do not ask for confirmation
      --tools  Also uninstall the Homebrew tools and fonts ftazsh manages
      --purge  --tools plus the tools' caches (bat, tealdeer)
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -y|--yes)
                ASSUME_YES=1
                ;;
            --tools)
                REMOVE_TOOLS=1
                ;;
            --purge)
                REMOVE_TOOLS=1
                PURGE=1
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

restore_zshrc() {
    local zshrc="$HOME/.zshrc"

    # Never touch a .zshrc the user wrote themselves.
    if [[ -f "$zshrc" ]] && ! grep -q "ftazsh-managed" "$zshrc"; then
        info "Your ~/.zshrc is not ftazsh-managed; leaving it untouched."
        return 0
    fi

    # The newest backup of YOUR .zshrc: backups of ftazsh's own file (kept
    # when tools had appended to it) and the -ftazsh-personal directories
    # are not candidates.
    local newest="" f
    for f in "$HOME"/.zshrc-backup-*; do
        [[ -f "$f" ]] || continue
        grep -q "ftazsh-managed" "$f" && continue
        if [[ -z "$newest" || "$f" -nt "$newest" ]]; then
            newest="$f"
        fi
    done

    if [[ -n "$newest" ]]; then
        cp -p "$newest" "$zshrc"
        ok "Restored ~/.zshrc from ${newest##*/} (backup file kept)"
    elif [[ -f "$zshrc" ]]; then
        rm -f "$zshrc"
        ok "Removed ftazsh-managed ~/.zshrc (no backup to restore)"
    else
        info "No ~/.zshrc to restore."
    fi
}

# Remove the `[include] path = ~/.config/ftazsh/gitconfig` block the installer
# added (and only that) from whichever global git config file holds it.
remove_gitconfig_include() {
    local include="$FTAZSH_HOME/gitconfig" f tmp found=0
    for f in "$HOME/.gitconfig" "${XDG_CONFIG_HOME:-$HOME/.config}/git/config"; do
        gitconfig_has_include "$f" "$include" || continue
        found=1
        if ! git config --file "$f" --fixed-value --unset-all include.path "$include" 2>/dev/null; then
            # git < 2.30 has no --fixed-value; escape the path for a regex match.
            git config --file "$f" --unset-all include.path "^$(printf '%s' "$include" | sed 's/[.[\*^$/]/\\&/g')\$"
        fi
        # Drop our marker comment and an [include] header left empty by the unset.
        tmp="$(mktemp "${f}.ftazsh.XXXXXX")"
        cp -p "$f" "$tmp"
        awk '
            { lines[NR] = $0 }
            END {
                for (i = 1; i <= NR; i++) {
                    if (lines[i] ~ /^# ftazsh-managed:/) continue
                    if (lines[i] ~ /^\[include\][ \t]*$/) {
                        empty = 1
                        for (j = i + 1; j <= NR; j++) {
                            if (lines[j] ~ /^[ \t]*$/) continue
                            if (lines[j] !~ /^\[/) empty = 0
                            break
                        }
                        if (empty) {
                            while (i + 1 <= NR && lines[i + 1] ~ /^[ \t]*$/) i++
                            continue
                        }
                    }
                    print lines[i]
                }
            }
        ' "$f" > "$tmp"
        mv -f "$tmp" "$f"
        ok "Removed ftazsh's include from ${f/#$HOME/~} (your own settings were kept)"
    done
    [[ "$found" -eq 1 ]] || info "No ftazsh include in your git config."
}

# Your personal files are precious: keep a copy next to the .zshrc backups.
backup_personal_config() {
    local src="$FTAZSH_HOME/zshrc" dest
    [[ -d "$src" ]] || return 0
    if [[ -z "$(ls -A "$src" 2>/dev/null)" ]]; then
        return 0
    fi
    dest="$HOME/.zshrc-backup-$(date +%Y-%m-%d-%H%M%S)-ftazsh-personal"
    while [[ -e "$dest" ]]; do
        dest="${dest}.1"
    done
    cp -Rp "$src" "$dest"
    ok "Copied your personal config (~/.config/ftazsh/zshrc/) to ${dest##*/}"
}

# Files an older ftazsh generated outside ~/.config/ftazsh.
remove_legacy_leftovers() {
    local f
    for f in "$HOME/.fzf.zsh" "$HOME/.fzf.bash"; do
        if [[ -f "$f" ]] && grep -q "config/ftazsh/fzf" "$f"; then
            rm -f "$f"
            ok "Removed ${f/#$HOME/~} (generated by an older ftazsh)"
        fi
    done
    if is_clone_of "$SCRIPT_DIR/nerd-fonts" "ryanoasis/nerd-fonts"; then
        rm -rf "$SCRIPT_DIR/nerd-fonts"
        ok "Removed the old nerd-fonts clone from the checkout"
    fi
}

remove_ftazsh_home() {
    if [[ -d "$FTAZSH_HOME" ]]; then
        rm -rf "$FTAZSH_HOME"
        ok "Removed $FTAZSH_HOME"
    else
        info "$FTAZSH_HOME not present."
    fi
}

# Caches created by ftazsh's shell setup (always removed) and, with --purge,
# the caches of the tools ftazsh installed.
remove_caches() {
    local cache="${XDG_CACHE_HOME:-$HOME/.cache}" f cleaned=0
    for f in "$cache"/zsh/.zcompdump* "$cache"/p10k-instant-prompt-*.zsh "$cache"/p10k-dump-*.zsh; do
        [[ -e "$f" ]] || continue
        rm -f "$f"
        cleaned=1
    done
    if [[ -d "$cache/zsh" ]] && [[ -z "$(ls -A "$cache/zsh" 2>/dev/null)" ]]; then
        rmdir "$cache/zsh"
    fi
    if [[ -d "$cache/gitstatus" ]]; then
        rm -rf "$cache/gitstatus"
        cleaned=1
    fi
    if [[ "$cleaned" -eq 1 ]]; then
        ok "Removed shell caches (completion dumps, Powerlevel10k, gitstatus)"
    fi

    if [[ "$PURGE" -eq 1 ]]; then
        for f in "$cache/bat" "$cache/tealdeer" "$HOME/Library/Caches/bat" "$HOME/Library/Caches/tealdeer"; do
            [[ -d "$f" ]] || continue
            rm -rf "$f"
            ok "Removed ${f/#$HOME/~}"
        done
    fi
    return 0
}

# --tools: uninstall the managed formulae and casks that are installed.
remove_tools() {
    [[ "$REMOVE_TOOLS" -eq 1 ]] || return 0
    if ! command -v brew >/dev/null 2>&1; then
        warn "Homebrew not found; cannot remove tools."
        return 0
    fi
    local installed f c
    local failed=()
    installed="$(brew list --formula 2>/dev/null || true)"
    for f in "${FORMULAE[@]}"; do
        printf '%s\n' "$installed" | grep -qx "$f" || continue
        if brew uninstall --formula "$f"; then
            ok "Uninstalled $f"
        else
            failed+=("$f")
        fi
    done
    installed="$(brew list --cask 2>/dev/null || true)"
    for c in "${CASKS[@]}"; do
        printf '%s\n' "$installed" | grep -qx "$c" || continue
        if brew uninstall --cask "$c"; then
            ok "Uninstalled $c"
        else
            failed+=("$c")
        fi
    done
    if [[ "${#failed[@]}" -gt 0 ]]; then
        warn "Could not uninstall: ${failed[*]} (other software may depend on them; see brew's message above)."
    fi
}

print_leftovers() {
    echo
    info "Your login shell was not changed."
    info "Homebrew itself and ~/.zprofile were left alone."
    if [[ "$REMOVE_TOOLS" -eq 0 ]]; then
        info "Homebrew tools and fonts were left installed. To remove them too:"
        echo "    ./uninstall.sh --tools      (or later: brew uninstall ${FORMULAE[*]})"
        echo "    brew uninstall --cask ${CASKS[*]}"
    fi
    if git config --global --get init.defaultRefFormat >/dev/null 2>&1; then
        info "git's init.defaultRefFormat is still set (from 'ftazsh reftable on'); unset with: git config --global --unset init.defaultRefFormat"
    fi
}

main() {
    parse_args "$@"

    if [[ "$ASSUME_YES" -ne 1 ]]; then
        echo "This removes ftazsh: restores your previous ~/.zshrc, removes ~/.config/ftazsh"
        echo "and ftazsh's git config include."
        [[ "$REMOVE_TOOLS" -eq 1 ]] && echo "Also uninstalls the Homebrew tools and fonts: ${FORMULAE[*]} ${CASKS[*]}"
        [[ "$PURGE" -eq 1 ]] && echo "And removes their caches."
        printf 'Continue? [y/N] '
        local reply
        read -r reply
        case "$reply" in
            y|Y|yes|YES) ;;
            *)
                info "Aborted; nothing was changed."
                exit 0
                ;;
        esac
    fi

    restore_zshrc
    remove_gitconfig_include
    backup_personal_config
    remove_ftazsh_home
    remove_legacy_leftovers
    remove_caches
    remove_tools
    print_leftovers
    ok "ftazsh uninstalled."
}

# Run only when executed directly — sourcing (e.g. from tests) is side-effect free.
if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
    trap 'err "Uninstall failed while running: ${BASH_COMMAND}"' ERR
    main "$@"
fi
