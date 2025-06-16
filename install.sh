#!/bin/bash
# ftazsh installation script
# This script installs and configures a comprehensive ZSH setup with Oh My Zsh,
# Powerlevel10k theme, Nerd Fonts, and various useful plugins.
#
# Usage: ./install.sh [OPTIONS]
#
# Options:
#   --cp-hist, -c    Copy bash_history to zsh_history

print_message() {
    echo -e "🔵  $1"
}

print_success() {
    echo -e "✅  $1"
}

print_error() {
    echo -e "❌  $1" >&2
}

# Check if required dependencies are already installed
if command -v zsh &> /dev/null && command -v git &> /dev/null && command -v wget &> /dev/null; then
    print_success "ZSH, Git, and wget are already installed\n"
else
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS specific installation
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
        if brew install git zsh wget; then
            print_success "zsh, wget, and git installed with Homebrew\n"
        else
            print_error "Failed to install packages with Homebrew\n" && exit
        fi
    else
        # Linux specific installation
        if sudo apt install -y zsh git wget || sudo pacman -S zsh git wget || sudo dnf install -y zsh git wget || sudo yum install -y zsh git wget || pkg install git zsh wget ; then
            print_success "zsh, wget, and git installed\n"
        else
            print_error "Please install the following packages first, then try again: zsh git wget \n" && exit
        fi
    fi
fi

if mv -n ~/.zshrc ~/.zshrc-backup-$(date +"%Y-%m-%d"); then # backup .zshrc
    print_success "Backed up the current .zshrc to .zshrc-backup-$(date +"%Y-%m-%d")\n"
fi

# Create main configuration directory
mkdir -p ~/.config/ftazsh       # the setup will be installed in here

# Check for previous quickzsh installation (predecessor to ftazsh)
if [ -d ~/.quickzsh ]; then
    print_message "\n PREVIOUS SETUP FOUND AT '~/.quickzsh'. PLEASE MANUALLY MOVE ANY FILES YOU'D LIKE TO '~/.config/ftazsh' \n"
fi

# Install or update Oh My Zsh
print_message "Installing oh-my-zsh\n"
if [ -d ~/.config/ftazsh/oh-my-zsh ]; then
    print_success "oh-my-zsh is already installed\n"
    git -C ~/.config/ftazsh/oh-my-zsh remote set-url origin https://github.com/ohmyzsh/ohmyzsh.git
elif [ -d ~/.oh-my-zsh ]; then
    print_message "oh-my-zsh is already installed at '~/.oh-my-zsh'. Moving it to '~/.config/ftazsh/oh-my-zsh'"
    export ZSH="$HOME/.config/ftazsh/oh-my-zsh"
    mv ~/.oh-my-zsh ~/.config/ftazsh/oh-my-zsh
    git -C ~/.config/ftazsh/oh-my-zsh remote set-url origin https://github.com/ohmyzsh/ohmyzsh.git
else
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.config/ftazsh/oh-my-zsh
fi

# Copy configuration files to their respective locations
cp -f .zshrc ~/                                                  # Main .zshrc file
cp -f ftazshrc.zsh ~/.config/ftazsh/                            # ftazsh main configuration
cp -f p10k.zsh ~/.config/ftazsh/                                # Powerlevel10k theme configuration

# Create directory for user-specific configurations
mkdir -p ~/.config/ftazsh/zshrc                                 # User's personal ZSH configurations go here
cp -f additional-config/personal_rc.zsh ~/.config/ftazsh/zshrc/personal_rc.zsh  # Example configuration

# Create cache directory for ZSH completion files
mkdir -p ~/.cache/zsh/                                          # Stores .zcompdump files to avoid cluttering $HOME

# Move existing completion cache files if they exist
if [ -f ~/.zcompdump ]; then
    mv ~/.zcompdump* ~/.cache/zsh/
fi

# Install or update ZSH plugins

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


# INSTALL FONTS

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

# Install or update Powerlevel10k theme
if [ -d ~/.config/ftazsh/oh-my-zsh/custom/themes/powerlevel10k ]; then
    cd ~/.config/ftazsh/oh-my-zsh/custom/themes/powerlevel10k && git pull && cd -
else
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.config/ftazsh/oh-my-zsh/custom/themes/powerlevel10k
fi

# Install or update fzf (fuzzy finder)
if [ -d ~/.config/ftazsh/fzf ]; then
    cd ~/.config/ftazsh/fzf && git pull && cd -
    ~/.config/ftazsh/fzf/install --all --key-bindings --completion --no-update-rc
else
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.config/ftazsh/fzf
    ~/.config/ftazsh/fzf/install --all --key-bindings --completion --no-update-rc
fi

# Install or update k plugin (directory listings for ZSH with git features)
if [ -d ~/.config/ftazsh/oh-my-zsh/custom/plugins/k ]; then
    cd ~/.config/ftazsh/oh-my-zsh/custom/plugins/k && git pull && cd -
else
    git clone --depth 1 https://github.com/supercrabtree/k ~/.config/ftazsh/oh-my-zsh/custom/plugins/k
fi

# Install or update marker (bookmark your shell commands)
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
cd "$(dirname "$0")"

# Optional: Copy bash history to zsh history if requested
if [[ $1 == "--cp-hist" ]] || [[ $1 == "-c" ]]; then
    print_message "\nCopying bash_history to zsh_history\n"
    if command -v python &>/dev/null; then
        wget -q --show-progress https://gist.githubusercontent.com/muendelezaji/c14722ab66b505a49861b8a74e52b274/raw/49f0fb7f661bdf794742257f58950d209dd6cb62/bash-to-zsh-hist.py
        cat ~/.bash_history | python bash-to-zsh-hist.py >> ~/.zsh_history
    else
        if command -v python3 &>/dev/null; then
            wget -q --show-progress https://gist.githubusercontent.com/muendelezaji/c14722ab66b505a49861b8a74e52b274/raw/49f0fb7f661bdf794742257f58950d209dd6cb62/bash-to-zsh-hist.py
            cat ~/.bash_history | python3 bash-to-zsh-hist.py >> ~/.zsh_history
        else
            print_error "Python is not installed, can't copy bash_history to zsh_history\n"
        fi
    fi
else
    print_message "\nNot copying bash_history to zsh_history, as --cp-hist or -c is not supplied\n"
fi
# Return to original directory in case previous operations changed it
cd "$(dirname "$0")"

# Directory for user configurations was already created earlier

# Set ZDOTDIR to point to the ftazsh config directory
# This allows zsh to find configuration files in ~/.config/ftazsh
echo 'export ZDOTDIR=~/.config/ftazsh' >> ~/.zshenv

# Final steps: Change default shell to ZSH and update Oh My Zsh
print_message "\nSudo access is needed to change default shell\n"

# Function to change the default shell to ZSH
change_default_shell() {
    # 1. Locate the Homebrew Zsh executable.
    local zsh_path
    if ! zsh_path=$(which zsh); then
        print_error "Zsh not found in your PATH. Please install Zsh first (e.g., 'brew install zsh')."
        exit 1
    fi

    # Check if it's the Homebrew path.
    if [[ "$zsh_path" != "/opt/homebrew/bin/zsh" ]] && [[ "$zsh_path" != "/usr/local/bin/zsh" ]]; then
        print_message "The detected Zsh is at '$zsh_path', which doesn't seem to be a Homebrew installation."
        print_message "The script will proceed, but this is intended for Homebrew-managed shells."
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
            exit 1
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
        exit 1
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
}

# Call the function to change the default shell
change_default_shell

echo ""
print_success "🎉 Installation successful!"
print_message "Please exit this terminal and start a new session for the changes to take effect."

# Return to original directory before exiting
cd "$(dirname "$0")"
exit
