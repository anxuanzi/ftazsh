#!/bin/bash
# ftazsh uninstaller.
#
# Restores your most recent .zshrc backup (or removes the ftazsh-managed
# one), then deletes ~/.config/ftazsh. Homebrew tools and fonts are left
# installed — they may be used by other software — and the exact commands
# to remove them are printed at the end.
#
# Usage: ./uninstall.sh [OPTIONS]
#   -h, --help   Show this help
#   -y, --yes    Do not ask for confirmation

set -euo pipefail

FTAZSH_HOME="${FTAZSH_HOME:-$HOME/.config/ftazsh}"
ASSUME_YES=0

info() { printf '🔵  %s\n' "$*"; }
ok()   { printf '✅  %s\n' "$*"; }
err()  { printf '❌  %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [OPTIONS]

Removes the ftazsh zsh environment and restores your previous ~/.zshrc.

Options:
  -h, --help   Show this help and exit
  -y, --yes    Do not ask for confirmation
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

    local newest="" f
    for f in "$HOME"/.zshrc-backup-*; do
        [[ -e "$f" ]] || continue
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

remove_ftazsh_home() {
    if [[ -d "$FTAZSH_HOME" ]]; then
        rm -rf "$FTAZSH_HOME"
        ok "Removed $FTAZSH_HOME"
    else
        info "$FTAZSH_HOME not present."
    fi
}

print_leftovers() {
    echo
    info "Your login shell was not changed."
    info "Homebrew tools and fonts were left installed. To remove them too:"
    echo "    brew uninstall eza bat fd ripgrep fzf zoxide jq"
    echo "    brew uninstall --cask font-jetbrains-mono-nerd-font font-hack-nerd-font"
}

main() {
    parse_args "$@"

    if [[ "$ASSUME_YES" -ne 1 ]]; then
        printf 'Remove ftazsh (restores your previous ~/.zshrc)? [y/N] '
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
    remove_ftazsh_home
    print_leftovers
    ok "ftazsh uninstalled."
}

# Run only when executed directly — sourcing (e.g. from tests) is side-effect free.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    trap 'err "Uninstall failed while running: ${BASH_COMMAND}"' ERR
    main "$@"
fi
