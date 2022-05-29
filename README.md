# ftazsh
A simple script to setup an awesome shell environment.
Quickly install and setup zsh and oh-my-zsh (https://github.com/robbyrussell/oh-my-zsh) with
* powerlevel10k theme (https://github.com/romkatv/powerlevel10k)
* Nerd-Fonts (https://github.com/ryanoasis/nerd-fonts)
* zsh-completions (https://github.com/zsh-users/zsh-completions)
* zsh-autosuggestions (https://github.com/zsh-users/zsh-autosuggestions)
* zsh-syntax-highlighting (https://github.com/zsh-users/zsh-syntax-highlighting)
* history-substring-search (https://github.com/zsh-users/zsh-history-substring-search)
* fzf (https://github.com/junegunn/fzf)
* k (https://github.com/supercrabtree/k)
* marker (https://github.com/pindexis/marker)
* todotxt (https://github.com/todotxt/todo.txt-cli)

Sets following useful aliases and ohmyzsh plugins. **You can add more or overwrite these in your personal zsh config files under `~/.config/ftazsh/zshrc/`** 
* l="ls -lah"         - just type "l" instead of "ls -lah"
* alias k="k -h"	  - show human readable filesizes, in kb, mb etc
* e="exit"
* [x="extract"](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/extract)         - extract any compressed files
* [z](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/z)   - quickly jump to most visited directories
* [web-search](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/web-search)    - search on the web from cli
* [sudo](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/sudo)                - easily prefix your commands with sudo by pressing `esc` twice
* [systemd](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/systemd)          - many useful aliases for systemd
* https               - make httpie use https
* myip - (wget -qO- https://wtfismyip.com/text)       - what's my ip: quickly find out external IP
* cheat - (https://github.com/chubin/cheat.sh)        - cheatsheets in the terminal!
* speedtest - (curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -) run speedtest on the fly
* dadjoke - (curl https://icanhazdadjoke.com)         - terminally sick jokes
* dict - (curl "dict://dict.org/d:$1 $2 $3")          - dictionary definitions
* ipgeo - (curl "http://api.db-ip.com/v2/free/$1")    - finds geo location from IP
* corona - (curl "https://corona-stats.online/")      - shows corona virus spread live stats


## Installation
Requirements:
* `git` to clone it.
* `python3` or `python` is required to run option '-c' which copies history from .bash_history

``` bash
git clone https://github.com/anxuanzi/ftazsh
cd ftazsh
./install.sh -c        # only run with '-c' the first time, running multiple times will duplicate history entries
```
This will install the setup under `~/.config/ftazsh/`
Change your terminal's fonts to either "RobotoMono Nerd Font" or "Hack Nerd Font" or "DejaVu Sans Mono Nerd Fonts".
You can also manually install Nerd Fonts of your choice.

## Notes
* If you are already using zsh, your zsh config will be backed up to .zshrc-backup-date

* If the text/icons look broken, make sure your terminal is using one of the Nerd fonts. [discussion](https://github.com/powerline/fonts/issues/185). I recommend "RobotoMono Nerd Font"

* marker's shortcut "Ctr+t" clashed with fzf so I rebound it to "Ctr +b"

* All oh-my-zsh plugins are installed under ~/.config/ftazsh/oh-my-zsh/plugin, Other tools (fzf,marker,todo) are installed in ~/.config/ftazsh/

* The look of the shell can be very easily customised[https://github.com/bhilburn/powerlevel9k#prompt-customization] by overwriting POWERLEVEL10K settings
in your personal config file under ~/.config/ftazsh/zshrc/ . See my setup under example/personal_rc.zsh

Suggestions about more cool tools are always welcome :)
