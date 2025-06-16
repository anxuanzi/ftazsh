#!/bin/bash
# Plugins and themes installation for ftazsh

# Source utility functions
source "$(dirname "$0")/utils.sh"

# Install or update Oh My Zsh
install_oh_my_zsh() {
    print_message "Installing oh-my-zsh\n"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended
}

# Install or update Powerlevel10k theme
install_powerlevel10k() {
    print_message "Installing Powerlevel10k theme\n"
    if [ -d ~/.config/ftazsh/oh-my-zsh/custom/themes/powerlevel10k ]; then
        cd ~/.config/ftazsh/oh-my-zsh/custom/themes/powerlevel10k && git pull && cd -
        print_success "Powerlevel10k theme updated\n"
    else
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.config/ftazsh/oh-my-zsh/custom/themes/powerlevel10k
        print_success "Powerlevel10k theme installed\n"
    fi
}

# Install or update ZSH plugins
install_zsh_plugins() {
    print_message "Installing ZSH plugins\n"
    
    # zsh-autosuggestions: Fish-like autosuggestions for ZSH
    if [ -d ~/.config/ftazsh/oh-my-zsh/plugins/zsh-autosuggestions ]; then
        cd ~/.config/ftazsh/oh-my-zsh/plugins/zsh-autosuggestions && git pull && cd -
    else
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.config/ftazsh/oh-my-zsh/plugins/zsh-autosuggestions
    fi

    # zsh-syntax-highlighting: Fish-like syntax highlighting for ZSH
    if [ -d ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-syntax-highlighting ]; then
        cd ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-syntax-highlighting && git pull && cd -
    else
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-syntax-highlighting
    fi

    # zsh-completions: Additional completion definitions for ZSH
    if [ -d ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-completions ]; then
        cd ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-completions && git pull && cd -
    else
        git clone --depth=1 https://github.com/zsh-users/zsh-completions ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-completions
    fi

    # zsh-history-substring-search: Fish-like history search for ZSH
    if [ -d ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-history-substring-search ]; then
        cd ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-history-substring-search && git pull && cd -
    else
        git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-history-substring-search
    fi
    
    # k plugin (directory listings for ZSH with git features)
    if [ -d ~/.config/ftazsh/oh-my-zsh/custom/plugins/k ]; then
        cd ~/.config/ftazsh/oh-my-zsh/custom/plugins/k && git pull && cd -
    else
        git clone --depth 1 https://github.com/supercrabtree/k ~/.config/ftazsh/oh-my-zsh/custom/plugins/k
    fi
    
    print_success "ZSH plugins installed\n"
}

# Install or update fzf (fuzzy finder)
install_fzf() {
    print_message "Installing fzf (fuzzy finder)\n"
    if [ -d ~/.config/ftazsh/fzf ]; then
        cd ~/.config/ftazsh/fzf && git pull && cd -
        ~/.config/ftazsh/fzf/install --all --key-bindings --completion --no-update-rc
    else
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.config/ftazsh/fzf
        ~/.config/ftazsh/fzf/install --all --key-bindings --completion --no-update-rc
    fi
    print_success "fzf installed\n"
}

# Install or update marker (bookmark your shell commands)
install_marker() {
    print_message "Installing marker (command bookmarker)\n"
    if [ -d ~/.config/ftazsh/marker ]; then
        cd ~/.config/ftazsh/marker && git pull && cd -
    else
        git clone --depth 1 https://github.com/jotyGill/marker ~/.config/ftazsh/marker
    fi

    # Run marker installation script
    if ~/.config/ftazsh/marker/install.py; then
        print_success "Installed Marker\n"
    else
        print_error "Marker Installation Had Issues\n"
    fi
    
    # Return to original directory in case marker installation changed it
    cd "$(dirname "$0")/.."
}