#!/bin/bash
# Configuration files installation for ftazsh

# Source utility functions
source "$(dirname "$0")/utils.sh"

# Copy configuration files to their respective locations
copy_config_files() {
    print_message "Copying configuration files\n"
    
    # Copy main configuration files
    cp -f "$(dirname "$0")/../.zshrc" ~/                                # Main .zshrc file
    cp -f "$(dirname "$0")/../ftazshrc.zsh" ~/.config/ftazsh/           # ftazsh main configuration
    cp -f "$(dirname "$0")/../p10k.zsh" ~/.config/ftazsh/               # Powerlevel10k theme configuration
    
    print_success "Main configuration files copied\n"
    
    # Copy example configuration
    mkdir -p ~/.config/ftazsh/zshrc                                     # User's personal ZSH configurations go here
    cp -f "$(dirname "$0")/../personal_rc.zsh" ~/.config/ftazsh/zshrc/personal_rc.zsh  # Example configuration
    
    print_success "Personal configuration copied\n"
}