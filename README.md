# ftazsh - Fast, Awesome ZSH Setup

A comprehensive ZSH configuration framework that provides a beautiful, informative, and feature-rich terminal experience. ftazsh is designed to work perfectly on macOS and Linux systems with minimal setup.

## What is ftazsh?

ftazsh is a carefully curated collection of ZSH tools and configurations that transforms your terminal into a powerful development environment. It combines the best features of:

* [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh) - A delightful community-driven framework for managing your Zsh configuration
* [Powerlevel10k](https://github.com/romkatv/powerlevel10k) - A beautiful and informative ZSH theme
* [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) - Iconic font aggregator, collection, and patcher
* Various plugins and tools that enhance your terminal experience

## Features

ftazsh includes the following components:

* **Powerlevel10k theme** - A fast, flexible, and powerful ZSH theme
* **Nerd Fonts** - Fonts patched with icons for a beautiful terminal experience
* **Useful plugins**:
  * [zsh-completions](https://github.com/zsh-users/zsh-completions) - Additional completion definitions
  * [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) - Fish-like autosuggestions
  * [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) - Fish-like syntax highlighting
  * [history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) - Fish-like history search
  * [fzf](https://github.com/junegunn/fzf) - A command-line fuzzy finder
  * [k](https://github.com/supercrabtree/k) - Directory listings for ZSH with git features
  * [marker](https://github.com/pindexis/marker) - Bookmark your shell commands

* **Useful aliases and functions**:
  * `l="ls --hyperlink=auto -lAhrtF"` - Enhanced list command (on macOS, hyperlink is automatically disabled)
  * `a='eza -la --git --colour-scale all -g --smart-group --icons always'` - Better ls command (requires eza to be installed)
  * `k="k -h"` - Show human-readable file sizes
  * `e="exit"` - Quick exit
  * `myip` - Quickly find out your external IP
  * `cheat` - Access cheatsheets in the terminal
  * `speedtest` - Run a network speed test
  * `dadjoke` - Get a random dad joke
  * `ipgeo` - Find geo location from an IP address

## Directory Structure

ftazsh uses the following directory structure:

```
~/.config/ftazsh/           # Main configuration directory
├── oh-my-zsh/              # Oh My Zsh installation
├── zshrc/                  # Your personal ZSH configurations (add files here)
├── ftazshrc.zsh            # Main ftazsh configuration
├── p10k.zsh                # Powerlevel10k configuration
├── fzf/                    # Fuzzy finder
└── marker/                 # Command bookmarker
```

## Installation

### Requirements

* macOS or Linux
* `git` to clone the repository
* `zsh` (will be installed if not present)
* `wget` (will be installed if not present)

### macOS Installation

```bash
# Clone the repository
git clone https://github.com/anxuanzi/ftazsh
cd ftazsh

# Run the installation script
./install.sh

# Optional: Copy bash history to zsh history
./install.sh -c
```

The script will:
1. Install Homebrew if not already installed (on macOS)
2. Configure Homebrew in your .zprofile file (on macOS)
3. Install required packages (zsh, git, wget)
4. Back up your existing .zshrc file
5. Install Oh My Zsh and plugins
6. Install Nerd Fonts
7. Set up the ftazsh configuration

After installation, restart your terminal or run `source ~/.zshrc` to apply the changes.

### Fonts

For the best experience, change your terminal's font to one of the installed Nerd Fonts:
* "Hack Nerd Font"
* "RobotoMono Nerd Font"
* "DejaVu Sans Mono Nerd Font"

### iTerm2 Users

If you're using iTerm2 on macOS, you can import the included profile:
1. Open iTerm2
2. Go to Preferences > Profiles
3. Click the "+" button to create a new profile
4. Click "Other Actions..." > "Import JSON Profiles..."
5. Select the `iterm2-profile.json` file from the ftazsh directory

## Customization

### Adding Your Own Configurations

All personal configurations should be placed in the `~/.config/ftazsh/zshrc/` directory. You can create one or multiple files in this directory, and they will be automatically sourced when your shell starts.

Example: Create a file `~/.config/ftazsh/zshrc/my_config.zsh` with your custom settings:

```zsh
# Add more plugins
plugins+=(docker docker-compose)

# Custom aliases
alias dc="docker-compose"
alias k8s="kubectl"

# Custom functions
function mkcd() {
  mkdir -p "$1" && cd "$1"
}
```

See the `example-config/personal_rc.zsh` file for more examples.

### Customizing the Prompt

The Powerlevel10k theme is highly customizable. You can run `p10k configure` to launch the configuration wizard, or edit `~/.config/ftazsh/p10k.zsh` directly.

## Troubleshooting

### Broken Icons or Fonts

If icons or text appear broken in your terminal:
1. Make sure you've installed the Nerd Fonts
2. Set your terminal to use one of the Nerd Fonts (Hack, RobotoMono, or DejaVu Sans Mono)
3. Ensure your terminal supports Unicode and has proper encoding settings

### Command Not Found: eza

The `a` and `aa` aliases use the `eza` command, which is not installed by default. To install it:

```bash
# On macOS
brew install eza

# On Linux
sudo apt install eza  # Debian/Ubuntu
sudo dnf install eza  # Fedora
```

Or remove/modify these aliases in your personal configuration.

## Notes

* Your original .zshrc file is backed up to `.zshrc-backup-YYYY-MM-DD`
* Marker's shortcut "Ctrl+t" is rebound to "Ctrl+b" to avoid conflicts with fzf
* All Oh My Zsh plugins are installed under `~/.config/ftazsh/oh-my-zsh/plugins/`
* Other tools (fzf, marker) are installed in `~/.config/ftazsh/`

## Contributing

Suggestions for more cool tools and improvements are always welcome! Feel free to open an issue or pull request.
