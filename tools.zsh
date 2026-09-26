# ftazsh tool integrations and aliases — loaded AFTER oh-my-zsh, so nothing
# here can be clobbered by oh-my-zsh defaults.
# Every integration is guarded with `command -v`: a machine without a tool
# gets a fully working shell, never an error.

#------------------------------------------------------------------------------
# LISTING — eza is the default ls (icons, colors, directories first, git status)
#------------------------------------------------------------------------------
alias l='ls -lAhrtF'    # all files, human sizes, oldest→newest (plain ls fallback)
alias e='exit'

if command -v eza >/dev/null; then
    # Icons need a Nerd Font (installed) and only show on a terminal
    # (--icons=auto), so `ls | grep …` keeps working. Long views show each
    # file's git status. (eza >= 0.22 only accepts --color-scale, not --colour-scale.)
    alias ls='eza --icons=auto --group-directories-first'
    alias ll='eza -l --git --header --icons=auto --group-directories-first --color-scale=all'
    alias la='eza -la --git --header --icons=auto --group-directories-first --color-scale=all'
    alias l='eza -la --git --icons=auto --group-directories-first -s modified'   # everything, oldest → newest
    alias lt='eza --tree --level=2 --icons=auto --git-ignore'                    # two-level tree
    # `a` = everything with git status and color-scaled sizes/dates; `aa` = newest first.
    alias a='eza -la --git --color-scale=all -g --smart-group --icons=always'
    alias aa='eza -la --git --color-scale=all -g --smart-group --icons=always -s modified -r'
    # macOS ships no `tree`; eza has one built in.
    command -v tree >/dev/null || alias tree='eza --tree --icons=auto --git-ignore'
    # The real ls is one escape away:  \ls -la   or   command ls
fi

#------------------------------------------------------------------------------
# FISH-STYLE SHELL — zsh-users plugins, configured so they just work
#------------------------------------------------------------------------------
# zsh-autosuggestions: grey suggestion after the cursor. → or End accepts it,
# Ctrl-→ / Alt-F accepts one word, Ctrl-F one character. Suggestions come
# from history first, then from what Tab would complete.
if (( $+functions[_zsh_autosuggest_start] )); then
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'   # readable grey on dark and light themes
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=40         # no suggestions while pasting long text
fi

# zsh-syntax-highlighting: valid commands green, unknown ones red, matching
# brackets highlighted, and a few dangerous patterns flagged. (These arrays
# must be set after the plugin loads, which is why they live here.)
if (( $+functions[_zsh_highlight] )); then
    ZSH_HIGHLIGHT_HIGHLIGHTERS+=(brackets pattern)
    ZSH_HIGHLIGHT_MAXLENGTH=512                     # keep typing snappy on very long lines
    ZSH_HIGHLIGHT_STYLES[comment]='fg=244'          # the default (black) is invisible on dark terminals
    typeset -gA ZSH_HIGHLIGHT_PATTERNS
    ZSH_HIGHLIGHT_PATTERNS+=('rm -rf *' 'fg=white,bold,bg=red')
    ZSH_HIGHLIGHT_PATTERNS+=('sudo rm *' 'fg=white,bold,bg=red')
fi

# history-substring-search: type part of a command, then ↑/↓ walk through the
# commands containing it (oh-my-zsh binds the arrow keys; Ctrl-P/Ctrl-N and
# vi-mode k/j are added here). Each match is shown once.
if (( $+widgets[history-substring-search-up] )); then
    HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
    bindkey '^[[A' history-substring-search-up      # arrows in terminals that don't use application mode
    bindkey '^[[B' history-substring-search-down
    bindkey -M emacs '^P' history-substring-search-up
    bindkey -M emacs '^N' history-substring-search-down
    bindkey -M vicmd 'k' history-substring-search-up
    bindkey -M vicmd 'j' history-substring-search-down
fi

# Completion menu: results grouped by kind with a heading, navigable with the
# arrow keys (Tab twice opens it). Case- and hyphen-insensitive matching,
# colors and caching are configured by oh-my-zsh.
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}%B-- %d --%b%f'
zstyle ':completion:*:messages' format '%F{magenta}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- no matches --%f'
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' complete-options true

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
    # Ctrl-R: Ctrl-/ toggles a preview of the full command line.
    export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window up:3:hidden:wrap --bind 'ctrl-/:toggle-preview'"
    if command -v fd >/dev/null; then
        # Respect .gitignore, include hidden files.
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
    fi
    if command -v bat >/dev/null; then
        export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
    fi
    if command -v eza >/dev/null; then
        export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons=always {} | head -200'"
    fi
fi

#------------------------------------------------------------------------------
# ZOXIDE — smarter cd:  z <dir> jumps,  zi picks interactively,  z <dir> Space Tab
# completes. FTAZSH_ZOXIDE_CMD=cd (settings.zsh) makes zoxide *be* cd (cd / cdi).
#------------------------------------------------------------------------------
if command -v zoxide >/dev/null; then
    # zi's picker: zoxide's own fzf defaults, with the directory preview drawn
    # by eza (icons, colors) instead of plain ls. Your own _ZO_FZF_OPTS wins.
    if [[ -z "${_ZO_FZF_OPTS:-}" ]] && command -v eza >/dev/null; then
        export _ZO_FZF_OPTS="--exact --no-sort --bind=ctrl-z:ignore,btab:up,tab:down --cycle --keep-right --border=sharp --height=45% --info=inline --layout=reverse --tabstop=1 --exit-0 --select-1 --preview='eza --group-directories-first --icons=always --color=always {2..}' --preview-window=down,30%,sharp"
    fi
    # After compinit (oh-my-zsh ran it), as zoxide requires for its completion.
    eval "$(zoxide init zsh --cmd "${FTAZSH_ZOXIDE_CMD:-z}")"
fi

#------------------------------------------------------------------------------
# GIT TOOLS — lazygit (lg), delta and difftastic are wired up in gitconfig
#------------------------------------------------------------------------------
if command -v lazygit >/dev/null; then
    alias lg='lazygit'
fi

#------------------------------------------------------------------------------
# YAZI — terminal file manager: `y` opens it and cds to where you quit (q)
#------------------------------------------------------------------------------
if command -v yazi >/dev/null; then
    y() {
        local tmp cwd
        tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        command yazi "$@" --cwd-file="$tmp"
        IFS= read -r -d '' cwd < "$tmp"
        [[ "$cwd" != "$PWD" && -d "$cwd" ]] && builtin cd -- "$cwd"
        command rm -f -- "$tmp"
    }
fi

#------------------------------------------------------------------------------
# TEALDEER — `tldr <command>` for community cheat sheets (cache primed at install)
#------------------------------------------------------------------------------
# btop, dust, duf, procs, sd, hyperfine, gh need no shell wiring — just use them.

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
