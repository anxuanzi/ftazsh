# ftazsh core configuration — loaded BEFORE oh-my-zsh.
# Override anything set here from your own files in ~/.config/ftazsh/zshrc/.

#------------------------------------------------------------------------------
# OH MY ZSH
#------------------------------------------------------------------------------
export ZSH="$HOME/.config/ftazsh/oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# ftazsh manages oh-my-zsh with git (re-run install.sh to update everything),
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
