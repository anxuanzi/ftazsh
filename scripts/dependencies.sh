#!/bin/bash
# Dependencies installation for ftazsh

# Source utility functions
source "$(dirname "$0")/utils.sh"

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