#!/bin/bash

if command -v zsh &> /dev/null && command -v git &> /dev/null && command -v wget &> /dev/null; then
    echo -e "ZSH and Git are already installed\n"
else
    if sudo apt install -y zsh git wget || sudo pacman -S zsh git wget || sudo dnf install -y zsh git wget || sudo yum install -y zsh git wget || sudo brew install git zsh wget || pkg install git zsh wget ; then
        echo -e "zsh wget and git Installed\n"
    else
        echo -e "Please install the following packages first, then try again: zsh git wget \n" && exit
    fi
fi

if mv -n ~/.zshrc ~/.zshrc-backup-$(date +"%Y-%m-%d"); then # backup .zshrc
    echo -e "Backed up the current .zshrc to .zshrc-backup-date\n"
fi

mkdir -p ~/.config/ftazsh       # the setup will be installed in here

if [ -d ~/.quickzsh ]; then
    echo -e "\n PREVIOUS SETUP FOUND AT '~/.quickzsh'. PLEASE MANUALLY MOVE ANY FILES YOU'D LIKE TO '~/.config/ftazsh' \n"
fi

echo -e "Installing oh-my-zsh\n"
if [ -d ~/.config/ftazsh/oh-my-zsh ]; then
    echo -e "oh-my-zsh is already installed\n"
    git -C ~/.config/ftazsh/oh-my-zsh remote set-url origin https://github.com/ohmyzsh/ohmyzsh.git
elif [ -d ~/.oh-my-zsh ]; then
    echo -e "oh-my-zsh in already installed at '~/.oh-my-zsh'. Moving it to '~/.config/ftazsh/oh-my-zsh'"
    export ZSH="$HOME/.config/ftazsh/oh-my-zsh"
    mv ~/.oh-my-zsh ~/.config/ftazsh/oh-my-zsh
    git -C ~/.config/ftazsh/oh-my-zsh remote set-url origin https://github.com/ohmyzsh/ohmyzsh.git
else
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.config/ftazsh/oh-my-zsh
fi

cp -f .zshrc ~/
cp -f ftazshrc.zsh ~/.config/ftazsh/

mkdir -p ~/.config/ftazsh/zshrc         # PLACE YOUR ZSHRC CONFIGURATIONS OVER THERE
mkdir -p ~/.cache/zsh/                # this will be used to store .zcompdump zsh completion cache files which normally clutter $HOME

if [ -f ~/.zcompdump ]; then
    mv ~/.zcompdump* ~/.cache/zsh/
fi

if [ -d ~/.config/ftazsh/oh-my-zsh/plugins/zsh-autosuggestions ]; then
    cd ~/.config/ftazsh/oh-my-zsh/plugins/zsh-autosuggestions && git pull
else
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.config/ftazsh/oh-my-zsh/plugins/zsh-autosuggestions
fi

if [ -d ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-syntax-highlighting ]; then
    cd ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-syntax-highlighting && git pull
else
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi

if [ -d ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-completions ]; then
    cd ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-completions && git pull
else
    git clone --depth=1 https://github.com/zsh-users/zsh-completions ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-completions
fi

if [ -d ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-history-substring-search ]; then
    cd ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-history-substring-search && git pull
else
    git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search ~/.config/ftazsh/oh-my-zsh/custom/plugins/zsh-history-substring-search
fi


# INSTALL FONTS

echo -e "Installing Nerd Fonts version of Hack, Roboto Mono, DejaVu Sans Mono\n"

wget -q --show-progress -N https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Regular/complete/Hack%20Regular%20Nerd%20Font%20Complete.ttf -P ~/.fonts/
wget -q --show-progress -N https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/RobotoMono/Regular/complete/Roboto%20Mono%20Nerd%20Font%20Complete.ttf -P ~/.fonts/
wget -q --show-progress -N https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/DejaVuSansMono/Regular/complete/DejaVu%20Sans%20Mono%20Nerd%20Font%20Complete.ttf -P ~/.fonts/

fc-cache -fv ~/.fonts

if [ -d ~/.config/ftazsh/oh-my-zsh/custom/themes/powerlevel10k ]; then
    cd ~/.config/ftazsh/oh-my-zsh/custom/themes/powerlevel10k && git pull
else
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.config/ftazsh/oh-my-zsh/custom/themes/powerlevel10k
fi

if [ -d ~/.~/.config/ftazsh/fzf ]; then
    cd ~/.config/ftazsh/fzf && git pull
    ~/.config/ftazsh/fzf/install --all --key-bindings --completion --no-update-rc
else
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.config/ftazsh/fzf
    ~/.config/ftazsh/fzf/install --all --key-bindings --completion --no-update-rc
fi

if [ -d ~/.config/ftazsh/oh-my-zsh/custom/plugins/k ]; then
    cd ~/.config/ftazsh/oh-my-zsh/custom/plugins/k && git pull
else
    git clone --depth 1 https://github.com/supercrabtree/k ~/.config/ftazsh/oh-my-zsh/custom/plugins/k
fi

if [ -d ~/.config/ftazsh/marker ]; then
    cd ~/.config/ftazsh/marker && git pull
else
    git clone --depth 1 https://github.com/jotyGill/marker ~/.config/ftazsh/marker
fi

if ~/.config/ftazsh/marker/install.py; then
    echo -e "Installed Marker\n"
else
    echo -e "Marker Installation Had Issues\n"
fi

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

ZDOTDIR="~/.config/ftazsh/zshrc"
if [ ! -d $ZDOTDIR ]; then
    mkdir -p $ZDOTDIR
fi

# source ~/.zshrc
echo -e "\nSudo access is needed to change default shell\n"

if chsh -s $(which zsh) && /bin/zsh -i -c 'omz update'; then
    echo -e "Installation Successful, exit terminal and enter a new session"
else
    echo -e "Something is wrong"
fi
exit
