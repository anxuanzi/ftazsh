#!/bin/bash
# ftazsh installation script
# This script installs and configures a comprehensive ZSH setup with Oh My Zsh,
# Powerlevel10k theme, Nerd Fonts, and various useful plugins.
#
# Usage: ./install_new.sh [OPTIONS]
#
# Options:
#   --cp-hist, -c    Copy bash_history to zsh_history

# Determine the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#######################################
# UTILITY FUNCTIONS
#######################################

# Print a regular message
print_message() {
    echo -e "🔵  $1"
}

# Print a success message
print_success() {
    echo -e "✅  $1"
}

# Print an error message
print_error() {
    echo -e "❌  $1" >&2
}

#######################################
# DEPENDENCY INSTALLATION FUNCTIONS
#######################################

# Install dependencies based on the operating system
install_dependencies() {
    # Check if required dependencies are already installed
    if command -v zsh &> /dev/null && command -v git &> /dev/null && command -v wget &> /dev/null; then
        print_success "ZSH, Git, and wget are already installed\n"
        return 0
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS specific installation
        install_macos_dependencies
    else
        # Linux specific installation
        install_linux_dependencies
    fi
}

# Install dependencies on macOS
install_macos_dependencies() {
    if ! command -v brew &> /dev/null; then
        print_message "Homebrew is not installed. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Configure Homebrew in the user's profile
        print_message "Configuring Homebrew in user's profile..."
        echo >> "$HOME/.zprofile"

        # Detect Homebrew location based on architecture
        if [[ -f /opt/homebrew/bin/brew ]]; then
            # Apple Silicon Mac
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            # Intel Mac
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$HOME/.zprofile"
            eval "$(/usr/local/bin/brew shellenv)"
        else
            # Try to find brew in PATH as fallback
            BREW_PATH=$(which brew)
            if [[ -n "$BREW_PATH" ]]; then
                echo "eval \"\$(${BREW_PATH} shellenv)\"" >> "$HOME/.zprofile"
                eval "$(${BREW_PATH} shellenv)"
            else
                print_error "Warning: Could not determine Homebrew location"
            fi
        fi
    fi
    
    # On macOS, use system zsh (/bin/zsh) instead of Homebrew zsh
    if brew install git wget; then
        print_success "git and wget installed with Homebrew\n"
        # Check if system zsh exists
        if [ -f /bin/zsh ]; then
            print_success "Using system zsh (/bin/zsh)\n"
            return 0
        else
            print_error "System zsh (/bin/zsh) not found. Please ensure zsh is installed.\n"
            return 1
        fi
    else
        print_error "Failed to install packages with Homebrew\n"
        return 1
    fi
}

# Install dependencies on Linux
install_linux_dependencies() {
    if sudo apt install -y zsh git wget || sudo pacman -S zsh git wget || sudo dnf install -y zsh git wget || sudo yum install -y zsh git wget || pkg install git zsh wget ; then
        print_success "zsh, wget, and git installed\n"
        return 0
    else
        print_error "Please install the following packages first, then try again: zsh git wget \n"
        return 1
    fi
}

#######################################
# SHELL CONFIGURATION FUNCTIONS
#######################################

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

#######################################
# PLUGINS AND THEMES INSTALLATION
#######################################

# Install or update Oh My Zsh
install_oh_my_zsh() {
    print_message "Installing oh-my-zsh\n"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended --skip-chsh --keep-zshrc
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
    cd "$SCRIPT_DIR"
}

#######################################
# FONTS INSTALLATION
#######################################

# Install or update Nerd Fonts
install_nerd_fonts() {
    print_message "Installing Nerd Fonts version of Hack, Roboto Mono, DejaVu Sans Mono, and JetBrains Mono\n"

    # Check if nerd-fonts directory already exists
    if [ -d "$SCRIPT_DIR/nerd-fonts" ]; then
        print_message "Nerd Fonts repository already exists, checking for updates...\n"
        # Store the current commit hash before pulling
        cd "$SCRIPT_DIR/nerd-fonts"
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
        cd "$SCRIPT_DIR"
    else
        cd "$SCRIPT_DIR"
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

#######################################
# CONFIGURATION FILES INSTALLATION
#######################################

# Copy configuration files to their respective locations
copy_config_files() {
    print_message "Copying configuration files\n"
    
    # Copy main configuration files
    cp -f "$SCRIPT_DIR/.zshrc" ~/                                # Main .zshrc file
    cp -f "$SCRIPT_DIR/ftazshrc.zsh" ~/.config/ftazsh/           # ftazsh main configuration
    cp -f "$SCRIPT_DIR/p10k.zsh" ~/.config/ftazsh/               # Powerlevel10k theme configuration
    
    print_success "Main configuration files copied\n"
    
    # Copy example configuration
    mkdir -p ~/.config/ftazsh/zshrc                                     # User's personal ZSH configurations go here
    cp -f "$SCRIPT_DIR/personal_rc.zsh" ~/.config/ftazsh/zshrc/personal_rc.zsh  # Example configuration
    
    print_success "Personal configuration copied\n"
}

#######################################
# HISTORY MIGRATION FUNCTIONS
#######################################

# Copy bash history to zsh history
copy_bash_history() {
    print_message "\nCopying bash_history to zsh_history\n"
    if command -v python &>/dev/null; then
        wget -q --show-progress https://gist.githubusercontent.com/muendelezaji/c14722ab66b505a49861b8a74e52b274/raw/49f0fb7f661bdf794742257f58950d209dd6cb62/bash-to-zsh-hist.py
        cat ~/.bash_history | python bash-to-zsh-hist.py >> ~/.zsh_history
        rm bash-to-zsh-hist.py
        print_success "Bash history copied to Zsh history using Python\n"
    else
        if command -v python3 &>/dev/null; then
            wget -q --show-progress https://gist.githubusercontent.com/muendelezaji/c14722ab66b505a49861b8a74e52b274/raw/49f0fb7f661bdf794742257f58950d209dd6cb62/bash-to-zsh-hist.py
            cat ~/.bash_history | python3 bash-to-zsh-hist.py >> ~/.zsh_history
            rm bash-to-zsh-hist.py
            print_success "Bash history copied to Zsh history using Python3\n"
        else
            print_error "Python is not installed, can't copy bash_history to zsh_history\n"
            return 1
        fi
    fi
    return 0
}

#######################################
# MAIN INSTALLATION FUNCTION
#######################################

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

    # Step 3: Set up ZDOTDIR
    print_message "Setting up ZDOTDIR...\n"
    setup_zdotdir
    
    # Step 4: Install Oh My Zsh and plugins
    print_message "Installing Oh My Zsh and plugins...\n"
    install_oh_my_zsh
    install_zsh_plugins
    install_powerlevel10k
    
    # Step 5: Install additional tools
    print_message "Installing additional tools...\n"
    install_fzf
    install_marker
    
    # Step 6: Install Nerd Fonts
    print_message "Installing Nerd Fonts...\n"
    install_nerd_fonts
    
    # Step 7: Copy configuration files
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