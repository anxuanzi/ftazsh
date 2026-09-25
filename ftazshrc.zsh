# ftazsh core configuration — loaded BEFORE oh-my-zsh.
# Override anything set here from your own files in ~/.config/ftazsh/zshrc/.

#------------------------------------------------------------------------------
# HOMEBREW — tools (including git) installed by Homebrew come first
#------------------------------------------------------------------------------
# Terminals normally get Homebrew from ~/.zprofile, but not every shell is a
# login shell. Set it up here if needed, then make sure Homebrew's bin dirs
# lead PATH so Homebrew's git (the latest, reftable-capable one) is *the* git,
# not the older one that ships with Xcode's command line tools.
if [[ -z "$HOMEBREW_PREFIX" ]]; then
    for _ftazsh_brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$_ftazsh_brew" ]]; then
            eval "$("$_ftazsh_brew" shellenv)"
            break
        fi
    done
    unset _ftazsh_brew
fi
typeset -U path fpath
if [[ -n "$HOMEBREW_PREFIX" ]]; then
    path=("$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin" $path)
    # Completions for Homebrew-installed tools (gh, eza, fd, rg, delta, …).
    # Must be on fpath before oh-my-zsh runs compinit. Appended, not
    # prepended, so zsh's own `_git` (which oh-my-zsh's git plugin builds
    # on) keeps precedence over git's bundled completion script.
    [[ ! -d "$HOMEBREW_PREFIX/share/zsh/site-functions" ]] \
        || fpath+=("$HOMEBREW_PREFIX/share/zsh/site-functions")
fi

# The `ftazsh` command (update, doctor, reinstall, …).
path=("${FTAZSH_HOME:-$HOME/.config/ftazsh}/bin" $path)

#------------------------------------------------------------------------------
# OH MY ZSH
#------------------------------------------------------------------------------
export ZSH="$HOME/.config/ftazsh/oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# ftazsh manages oh-my-zsh with git (`ftazsh update` updates everything),
# so oh-my-zsh's own update prompts are disabled.
zstyle ':omz:update' mode disabled

# Keep completion dumps out of $HOME.
command mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
export ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump-${HOST%%.*}-${ZSH_VERSION}"

# Extra completion definitions (fpath must be extended before compinit runs).
fpath+=("$ZSH/custom/plugins/zsh-completions/src")

#------------------------------------------------------------------------------
# PLUGINS
#------------------------------------------------------------------------------
# zsh-syntax-highlighting wraps all ZLE widgets and must load last;
# history-substring-search must load after zsh-syntax-highlighting.
# Add your own in ~/.config/ftazsh/zshrc/:   plugins+=(docker-compose)
# Remove a default one there with:           plugins=(${plugins:#docker})
plugins=(
    git                      # git aliases (gst, gco, glog, …)
    python
    pip
    docker
    extract                  # `extract <any-archive>`
    sudo                     # press ESC twice to prepend sudo
    zsh-autosuggestions      # fish-like inline suggestions
    zsh-syntax-highlighting  # fish-like command coloring
    history-substring-search # type, then ↑/↓ to search matching history
)

# macOS-only plugins (prepended so the widget-wrapping plugins stay last).
if [[ "$OSTYPE" == darwin* ]]; then
    plugins=(macos brew $plugins)
fi

#------------------------------------------------------------------------------
# HISTORY
#------------------------------------------------------------------------------
HISTSIZE=50000
SAVEHIST=50000
# setopt hist_ignore_all_dups   # uncomment to drop duplicated history entries

#------------------------------------------------------------------------------
# PATH
#------------------------------------------------------------------------------
# Tools installed with pipx or `pip install --user`.
export PATH="$PATH:$HOME/.local/bin"
