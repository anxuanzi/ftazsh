#!/bin/bash
# Shell configuration functions for ftazsh

# Source utility functions
source "$(dirname "$0")/utils.sh"

# Change the default shell to ZSH
change_default_shell() {
    # 1. Determine the Zsh path based on OS
    local zsh_path

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # On macOS, use the system zsh
        zsh_path="/bin/zsh"
        if [ ! -f "$zsh_path" ]; then
            print_error "System Zsh not found at '$zsh_path'. Please ensure zsh is installed."
            return 1
        fi
    else
        # On other systems, use zsh from PATH
        if ! zsh_path=$(which zsh); then
            print_error "Zsh not found in your PATH. Please install Zsh first."
            return 1
        fi
    fi

    print_message "Zsh is located at: $zsh_path"

    # 2. Check if the Zsh path is in /etc/shells.
    local shells_file="/etc/shells"
    if ! grep -q "^${zsh_path}$" "$shells_file"; then
        print_message "'$zsh_path' is not listed in $shells_file."
        print_message "We need to add it. This requires administrator privileges."

        # 3. Add the Zsh path to /etc/shells using sudo.
        # The 'tee' command is used to append to a file requiring root privileges.
        if echo "$zsh_path" | sudo tee -a "$shells_file" > /dev/null; then
            print_success "Successfully added '$zsh_path' to $shells_file."
        else
            print_error "Failed to add '$zsh_path' to $shells_file. Please check your permissions."
            return 1
        fi
    else
        print_success "'$zsh_path' is already in $shells_file."
    fi

    # 4. Change the shell.
    print_message "Attempting to change the default shell to '$zsh_path'..."
    if chsh -s "$zsh_path"; then
        print_success "Default shell changed successfully."
    else
        print_error "Failed to change the shell with 'chsh'. Please try running 'chsh -s $zsh_path' manually."
        return 1
    fi

    # 5. Update Oh My Zsh if it exists.
    # Check if the OMZ directory exists before trying to update.
    print_message "Updating Oh My Zsh..."
    # We run this in a subshell to avoid issues with the current script's environment.
    if $zsh_path -i -c 'omz update'; then
        print_success "Oh My Zsh update completed."
    else
        # A failed update is not critical, so we'll just warn the user.
        print_error "Oh My Zsh update command finished with a non-zero status. Check the output above."
    fi
    
    return 0
}

# Backup existing .zshrc file
backup_zshrc() {
    if mv -n ~/.zshrc ~/.zshrc-backup-$(date +"%Y-%m-%d"); then
        print_success "Backed up the current .zshrc to .zshrc-backup-$(date +"%Y-%m-%d")\n"
    fi
}

# Set up ZDOTDIR to point to the ftazsh config directory
setup_zdotdir() {
    # This allows zsh to find configuration files in ~/.config/ftazsh
    echo 'export ZDOTDIR=~/.config/ftazsh' >> ~/.zshenv
    print_success "Set ZDOTDIR to ~/.config/ftazsh in ~/.zshenv"
}

# Create necessary directories for ftazsh
create_directories() {
    # Create main configuration directory
    mkdir -p ~/.config/ftazsh
    
    # Create directory for user-specific configurations
    mkdir -p ~/.config/ftazsh/zshrc
    
    # Create cache directory for ZSH completion files
    mkdir -p ~/.cache/zsh/
    
    # Move existing completion cache files if they exist
    if [ -f ~/.zcompdump ]; then
        mv ~/.zcompdump* ~/.cache/zsh/
    fi
    
    print_success "Created necessary directories for ftazsh"
}