#!/bin/bash
# ftazsh installation script
# This script installs and configures a comprehensive ZSH setup with Oh My Zsh,
# Powerlevel10k theme, Nerd Fonts, and various useful plugins.
#
# Usage: ./install.sh [OPTIONS]
#
# Options:
#   --cp-hist, -c    Copy bash_history to zsh_history

# Determine the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions and modules
source "$SCRIPT_DIR/scripts/utils.sh"
source "$SCRIPT_DIR/scripts/dependencies.sh"
source "$SCRIPT_DIR/scripts/shell_config.sh"
source "$SCRIPT_DIR/scripts/plugins_themes.sh"
source "$SCRIPT_DIR/scripts/fonts.sh"
source "$SCRIPT_DIR/scripts/config_files.sh"
source "$SCRIPT_DIR/scripts/history.sh"

# Main installation function
main() {
    print_message "Starting ftazsh installation...\n"
    
    # Step 1: Install dependencies
    print_message "Installing dependencies...\n"
    if ! install_dependencies; then
        print_error "Failed to install dependencies. Exiting.\n"
        exit 1
    fi
    
    # Step 2: Backup existing .zshrc and create directories
    print_message "Setting up directories...\n"
    backup_zshrc
    create_directories

    # Step 7: Set up ZDOTDIR
    print_message "Setting up ZDOTDIR...\n"
    setup_zdotdir
    
    # Step 3: Install Oh My Zsh and plugins
    print_message "Installing Oh My Zsh and plugins...\n"
    install_oh_my_zsh
    install_zsh_plugins
    install_powerlevel10k
    
    # Step 4: Install additional tools
    print_message "Installing additional tools...\n"
    install_fzf
    install_marker
    
    # Step 5: Install Nerd Fonts
    print_message "Installing Nerd Fonts...\n"
    install_nerd_fonts
    
    # Step 6: Copy configuration files
    print_message "Copying configuration files...\n"
    copy_config_files
    
    # Step 8: Copy bash history to zsh history if requested
    if [[ $1 == "--cp-hist" ]] || [[ $1 == "-c" ]]; then
        print_message "Copying bash history to zsh history...\n"
        copy_bash_history
    else
        print_message "Skipping bash history copy (use --cp-hist or -c to enable)\n"
    fi
    
    # Step 9: Change default shell to ZSH
    print_message "Changing default shell to ZSH...\n"
    print_message "\nSudo access is needed to change default shell\n"
    change_default_shell
    
    # Final message
    echo ""
    print_success "🎉 Installation successful!"
    print_message "Please exit this terminal and start a new session for the changes to take effect."
}

# Run the main function with all arguments
main "$@"

# Return to original directory before exiting
cd "$SCRIPT_DIR"
exit 0