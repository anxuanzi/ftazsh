#!/bin/bash
# ftazsh installation script
# This script installs and configures a comprehensive ZSH setup with Oh My Zsh,
# Powerlevel10k theme, Nerd Fonts, and various useful plugins.

# Check if required dependencies are already installed
if command -v zsh &> /dev/null && command -v git &> /dev/null && command -v wget &> /dev/null; then
    echo -e "ZSH, Git, and wget are already installed\n"
else
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS specific installation
        if ! command -v brew &> /dev/null; then
            echo "Homebrew is not installed. Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        if brew install git zsh wget; then
            echo -e "zsh, wget, and git installed with Homebrew\n"
        else
            echo -e "Failed to install packages with Homebrew\n" && exit
        fi
    else
        # Linux specific installation
        if sudo apt install -y zsh git wget || sudo pacman -S zsh git wget || sudo dnf install -y zsh git wget || sudo yum install -y zsh git wget || pkg install git zsh wget ; then
            echo -e "zsh, wget, and git installed\n"
        else
            echo -e "Please install the following packages first, then try again: zsh git wget \n" && exit
        fi
    fi
fi

if mv -n ~/.zshrc ~/.zshrc-backup-$(date +"%Y-%m-%d"); then # backup .zshrc
    echo -e "Backed up the current .zshrc to .zshrc-backup-$(date +"%Y-%m-%d")\n"
fi

# Create main configuration directory
mkdir -p ~/.config/ftazsh       # the setup will be installed in here

# Check for previous quickzsh installation (predecessor to ftazsh)
if [ -d ~/.quickzsh ]; then
    echo -e "\n PREVIOUS SETUP FOUND AT '~/.quickzsh'. PLEASE MANUALLY MOVE ANY FILES YOU'D LIKE TO '~/.config/ftazsh' \n"
fi

# Install or update Oh My Zsh
echo -e "Installing oh-my-zsh\n"
if [ -d ~/.config/ftazsh/oh-my-zsh ]; then
    echo -e "oh-my-zsh is already installed\n"
    git -C ~/.config/ftazsh/oh-my-zsh remote set-url origin https://github.com/ohmyzsh/ohmyzsh.git
elif [ -d ~/.oh-my-zsh ]; then
    echo -e "oh-my-zsh is already installed at '~/.oh-my-zsh'. Moving it to '~/.config/ftazsh/oh-my-zsh'"
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
cp -f example-config/personal_rc.zsh ~/.config/ftazsh/zshrc/personal_rc.zsh  # Example configuration

# Create cache directory for ZSH completion files
mkdir -p ~/.cache/zsh/                                          # Stores .zcompdump files to avoid cluttering $HOME

# Move existing completion cache files if they exist
if [ -f ~/.zcompdump ]; then
    mv ~/.zcompdump* ~/.cache/zsh/
fi

# Install or update ZSH plugins

# zsh-autosuggestions: Fish-like autosuggestions for ZSH
if [ -d ~/.config/ftazsh/oh-my-zsh/plugins/zsh-autosuggestions ]; then
    cd ~/.config/ftazsh/oh-my-zsh/plugins/zsh-autosuggestions && git pull
else
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.config/ftazsh/oh-my-zsh/plugins/zsh-autosuggestions
fi

# zsh-syntax-highlighting: Fish-like syntax highlighting for ZSH
if [ -d ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-syntax-highlighting ]; then
    cd ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-syntax-highlighting && git pull
else
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi

# zsh-completions: Additional completion definitions for ZSH
if [ -d ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-completions ]; then
    cd ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-completions && git pull
else
    git clone --depth=1 https://github.com/zsh-users/zsh-completions ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-completions
fi

# zsh-history-substring-search: Fish-like history search for ZSH
if [ -d ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-history-substring-search ]; then
    cd ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-history-substring-search && git pull
else
    git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-history-substring-search
fi


# INSTALL FONTS

echo -e "Installing Nerd Fonts version of Hack, Roboto Mono, DejaVu Sans Mono, and JetBrains Mono\n"

# Check if nerd-fonts directory already exists
if [ -d ./nerd-fonts ]; then
    echo -e "Nerd Fonts repository already exists, updating...\n"
    cd ./nerd-fonts && git pull && cd ..
else
    git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git
fi

# Install the fonts
if chmod +x ./nerd-fonts/install.sh && ./nerd-fonts/install.sh; then
    echo -e "Nerd Fonts installed successfully\n"
else
    echo -e "There was an issue installing Nerd Fonts\n"
fi

# Clean up nerd-fonts repository to save space
echo -e "Cleaning up Nerd Fonts repository...\n"
rm -rf ./nerd-fonts

# Install or update Powerlevel10k theme
if [ -d ~/.config/ftazsh/oh-my-zsh/custom/themes/powerlevel10k ]; then
    cd ~/.config/ftazsh/oh-my-zsh/custom/themes/powerlevel10k && git pull
else
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.config/ftazsh/oh-my-zsh/custom/themes/powerlevel10k
fi

# Install or update fzf (fuzzy finder)
if [ -d ~/.config/ftazsh/fzf ]; then
    cd ~/.config/ftazsh/fzf && git pull
    ~/.config/ftazsh/fzf/install --all --key-bindings --completion --no-update-rc
else
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.config/ftazsh/fzf
    ~/.config/ftazsh/fzf/install --all --key-bindings --completion --no-update-rc
fi

# Install or update k plugin (directory listings for ZSH with git features)
if [ -d ~/.config/ftazsh/oh-my-zsh/custom/plugins/k ]; then
    cd ~/.config/ftazsh/oh-my-zsh/custom/plugins/k && git pull
else
    git clone --depth 1 https://github.com/supercrabtree/k ~/.config/ftazsh/oh-my-zsh/custom/plugins/k
fi

# Install or update marker (bookmark your shell commands)
if [ -d ~/.config/ftazsh/marker ]; then
    cd ~/.config/ftazsh/marker && git pull
else
    git clone --depth 1 https://github.com/jotyGill/marker ~/.config/ftazsh/marker
fi

# Run marker installation script
if ~/.config/ftazsh/marker/install.py; then
    echo -e "Installed Marker\n"
else
    echo -e "Marker Installation Had Issues\n"
fi

# Optional: Copy bash history to zsh history if requested
if [[ $1 == "--cp-hist" ]] || [[ $1 == "-c" ]]; then
    echo -e "\nCopying bash_history to zsh_history\n"
    if command -v python &>/dev/null; then
        wget -q --show-progress https://gist.githubusercontent.com/muendelezaji/c14722ab66b505a49861b8a74e52b274/raw/49f0fb7f661bdf794742257f58950d209dd6cb62/bash-to-zsh-hist.py
        cat ~/.bash_history | python bash-to-zsh-hist.py >> ~/.zsh_history
    else
        if command -v python3 &>/dev/null; then
            wget -q --show-progress https://gist.githubusercontent.com/muendelezaji/c14722ab66b505a49861b8a74e52b274/raw/49f0fb7f661bdf794742257f58950d209dd6cb62/bash-to-zsh-hist.py
            cat ~/.bash_history | python3 bash-to-zsh-hist.py >> ~/.zsh_history
        else
            echo "Python is not installed, can't copy bash_history to zsh_history\n"
        fi
    fi
else
    echo -e "\nNot copying bash_history to zsh_history, as --cp-hist or -c is not supplied\n"
fi

# Directory for user configurations was already created earlier

# Set ZDOTDIR to point to the ftazsh config directory
# This allows zsh to find configuration files in ~/.config/ftazsh
echo 'export ZDOTDIR=~/.config/ftazsh' >> ~/.zshenv

# Final steps: Change default shell to ZSH and update Oh My Zsh
echo -e "\nSudo access is needed to change default shell\n"

if chsh -s $(which zsh) && /bin/zsh -i -c 'omz update'; then
    echo -e "Installation Successful, exit terminal and enter a new session"
else
    echo -e "Something went wrong during the final setup"
fi
exit
