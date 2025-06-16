#!/bin/bash
# Fonts installation for ftazsh

# Source utility functions
source "$(dirname "$0")/utils.sh"

# Install or update Nerd Fonts
install_nerd_fonts() {
    print_message "Installing Nerd Fonts version of Hack, Roboto Mono, DejaVu Sans Mono, and JetBrains Mono\n"

    # Check if nerd-fonts directory already exists
    if [ -d ./nerd-fonts ]; then
        print_message "Nerd Fonts repository already exists, checking for updates...\n"
        # Store the current commit hash before pulling
        cd ./nerd-fonts
        BEFORE_HASH=$(git rev-parse HEAD)
        git pull
        AFTER_HASH=$(git rev-parse HEAD)

        # Only install if there were updates
        if [ "$BEFORE_HASH" != "$AFTER_HASH" ]; then
            print_message "Updates found, reinstalling fonts...\n"
            if chmod +x ./install.sh && ./install.sh; then
                print_success "Nerd Fonts updated successfully\n"
            else
                print_error "There was an issue updating Nerd Fonts\n"
            fi
        else
            print_success "Nerd Fonts are already up to date\n"
        fi
        cd ..
    else
        git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git

        # Install the fonts for the first time
        if chmod +x ./nerd-fonts/install.sh && ./nerd-fonts/install.sh; then
            print_success "Nerd Fonts installed successfully\n"
        else
            print_error "There was an issue installing Nerd Fonts\n"
        fi
    fi

    # Keep the nerd-fonts repository for future updates
    print_message "Keeping Nerd Fonts repository for future updates\n"
}