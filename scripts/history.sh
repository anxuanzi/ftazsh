#!/bin/bash
# History migration functions for ftazsh

# Source utility functions
source "$(dirname "$0")/utils.sh"

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