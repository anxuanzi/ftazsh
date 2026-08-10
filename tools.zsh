# ftazsh tool integrations and aliases — loaded AFTER oh-my-zsh, so nothing
# here can be clobbered by oh-my-zsh defaults.
# Every integration is guarded with `command -v`: a machine without a tool
# gets a fully working shell, never an error.

#------------------------------------------------------------------------------
# LISTING
#------------------------------------------------------------------------------
alias l='ls -lAhrtF'    # all files, human sizes, oldest→newest, type markers
alias e='exit'

if command -v eza >/dev/null; then
    # The modern ls. `a` = everything with git status; `aa` = newest first.
    alias a='eza -la --git --colour-scale=all -g --smart-group --icons=always'
    alias aa='eza -la --git --colour-scale=all -g --smart-group --icons=always -s modified -r'
fi

#------------------------------------------------------------------------------
# BAT — syntax-highlighted pager, prettier man pages
#------------------------------------------------------------------------------
if command -v bat >/dev/null; then
    export MANPAGER="sh -c 'col -bx | bat --language man --plain'"
    export MANROFFOPT="-c"
fi

#------------------------------------------------------------------------------
# FZF — fuzzy finder: Ctrl-R history, Ctrl-T files, Alt-C cd
#------------------------------------------------------------------------------
if command -v fzf >/dev/null; then
    # `fzf --zsh` needs fzf ≥ 0.48 (Homebrew's is). Older fzf degrades silently.
    source <(fzf --zsh 2>/dev/null)
    export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border --info=inline"
    if command -v fd >/dev/null; then
        # Respect .gitignore, include hidden files.
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    fi
    if command -v bat >/dev/null; then
        export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
    fi
fi

#------------------------------------------------------------------------------
# ZOXIDE — smarter cd:  z <fuzzy-dir>,  zi = interactive picker
#------------------------------------------------------------------------------
if command -v zoxide >/dev/null; then
    eval "$(zoxide init zsh)"
fi

#------------------------------------------------------------------------------
# NETWORK HELPERS
#------------------------------------------------------------------------------
myip() { curl -fsS https://wtfismyip.com/text }

# Cheat sheets from cheat.sh:  cheat tar   |   cheat python3 "read a file"
cheat() {
    if [[ -n "${2:-}" ]]; then
        local topic="$1"
        shift
        local IFS='+'
        curl -fsS "https://cheat.sh/${topic}/$*"
    else
        curl -fsS "https://cheat.sh/${1:-}"
    fi
}

speedtest() {
    if command -v python3 >/dev/null; then
        curl -fsS https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
    else
        echo "speedtest requires python3 (brew install python)" >&2
        return 1
    fi
}

dadjoke() { curl -fsS https://icanhazdadjoke.com; echo }

# Geo info for an IP:  ipgeo 8.8.8.8   |   ipgeo  (your own IP)
ipgeo() {
    if [[ -n "${1:-}" ]]; then
        curl -fsS "https://api.db-ip.com/v2/free/$1"
    else
        curl -fsS "https://api.db-ip.com/v2/free/$(myip)"
    fi
}
