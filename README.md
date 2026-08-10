# ftazsh — a modern zsh environment for macOS

One command sets up a complete terminal environment on a fresh (or not so
fresh) Mac: [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh), the
[Powerlevel10k](https://github.com/romkatv/powerlevel10k) prompt, Nerd Fonts,
fish-style shell behavior, and a curated set of modern unix tools — installed
with Homebrew and already wired into the shell config.

**macOS only.** The installer refuses to run anywhere else.

## What you get

**Modern unix tools**, installed via Homebrew and integrated out of the box:

| Tool | What it replaces | How ftazsh wires it in |
|---|---|---|
| [eza](https://github.com/eza-community/eza) | `ls` | `a` (detailed list with git status), `aa` (newest first) |
| [bat](https://github.com/sharkdp/bat) | `cat` / pager | colored `man` pages, fzf file previews |
| [fd](https://github.com/sharkdp/fd) | `find` | powers fzf file search (respects `.gitignore`) |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | `grep` | installed, ready to use as `rg` |
| [fzf](https://github.com/junegunn/fzf) | — | `Ctrl-R` history, `Ctrl-T` files, `Alt-C` cd |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `cd` | `z <fuzzy-dir>` jumps, `zi` interactive picker |
| [jq](https://github.com/jqlang/jq) | — | installed, ready to use |

**Shell experience:**

* Powerlevel10k prompt (instant prompt enabled, config included)
* Fish-style behavior: autosuggestions, syntax highlighting, ↑/↓ substring
  history search
* Extra completions (`zsh-completions`) and oh-my-zsh plugins:
  `macos brew git python pip docker extract sudo`
* 50k-line shared history, completion dumps kept out of `$HOME`
* Helpers: `myip`, `cheat <topic>`, `speedtest`, `dadjoke`, `ipgeo [ip]`,
  `l` (classic detailed `ls`), `e` (exit)

**Fonts:** JetBrains Mono Nerd Font and Hack Nerd Font via Homebrew casks —
no multi-gigabyte font repo clone.

## Install

```bash
git clone https://github.com/anxuanzi/ftazsh
cd ftazsh
./install.sh
```

Re-running `./install.sh` later **updates** everything (oh-my-zsh, plugins,
theme, configs). It is idempotent and safe.

```
Usage: ./install.sh [OPTIONS]
  -h, --help        Show help
      --unattended  Non-interactive: never prompts, skips changing the
                    login shell (prints the command instead). For CI.
```

The installer:

1. Installs Homebrew if missing (and adds it to `~/.zprofile`)
2. Installs the tools and fonts listed above (skips what's already there)
3. Backs up a pre-existing `~/.zshrc` to `~/.zshrc-backup-<timestamp>`
4. Clones oh-my-zsh, plugins, and Powerlevel10k under `~/.config/ftazsh/`
5. Installs the ftazsh config files
6. Offers to make zsh your login shell — skipped automatically if it
   already is (which is the macOS default)

Then open a new terminal window. Run `p10k configure` any time to restyle
the prompt.

### Terminal font

Set your terminal's font to **JetBrainsMono Nerd Font** or **Hack Nerd
Font** so prompt icons render. iTerm2 users can import the bundled profile
(font pre-set): *Settings → Profiles → Other Actions… → Import JSON
Profiles…* → pick `iterm2-profile.json`.

## How the config is organized

```
~/.zshrc                      # thin orchestrator installed by ftazsh (marked "ftazsh-managed")
~/.config/ftazsh/
├── ftazshrc.zsh              # core setup, loads BEFORE oh-my-zsh
├── p10k.zsh                  # Powerlevel10k prompt configuration
├── tools.zsh                 # tool integrations + aliases, loads AFTER oh-my-zsh
├── zshrc/                    # ← YOUR files live here (sourced in name order)
│   └── personal_rc.zsh       # example, seeded once, never overwritten
└── oh-my-zsh/                # oh-my-zsh + plugins + theme (managed by installer)
```

Load order: instant prompt → `ftazshrc.zsh` → `p10k.zsh` → **your files** →
oh-my-zsh → `tools.zsh`. Your files load before oh-my-zsh, so they can add
plugins; `tools.zsh` loads after it, so ftazsh's aliases and keybindings
can't be clobbered by oh-my-zsh defaults.

Every tool integration is guarded — if a tool is missing, the shell still
starts cleanly with stock behavior.

### Customizing

Put any number of files in `~/.config/ftazsh/zshrc/`. The installer never
touches that directory (the example is seeded only on first install).

```zsh
# ~/.config/ftazsh/zshrc/mine.zsh
plugins+=(docker-compose kubectl)        # add oh-my-zsh plugins
plugins=(${plugins:#docker})             # remove a default plugin
alias dc="docker compose"
export EDITOR="nvim"
```

oh-my-zsh's built-in auto-update prompts are disabled on purpose — re-run
`./install.sh` to update everything, including oh-my-zsh.

## Uninstall

```bash
./uninstall.sh        # add --yes to skip the confirmation
```

Restores your most recent `.zshrc` backup and removes `~/.config/ftazsh`.
Homebrew tools and fonts are left installed; the exact `brew uninstall`
commands are printed in case you want them gone too.

## Development & testing

The repo has a real test suite; everything except Homebrew itself runs in
Docker:

```bash
make docker-test    # build the Linux test image and run lint + unit + integration
make lint           # shellcheck + `zsh -n` on every config (host)
make unit           # bats unit tests for installer/uninstaller functions
make integration    # clones a real layout into a scratch HOME, boots zsh, asserts health
```

* Unit tests stub `uname`/`brew`/`chsh`/`dscl`, so no test touches your
  system.
* The integration test exercises the graceful-degradation paths on purpose
  (the image has no `bat`/`fd`, and an fzf too old for `--zsh`).
* CI runs the Linux suite plus a real `./install.sh --unattended` on a
  macOS runner.

## Troubleshooting

**Broken icons?** Your terminal isn't using a Nerd Font — see
[Terminal font](#terminal-font) above.

**Prompt looks wrong over SSH / in a basic terminal?** That's Powerlevel10k
adapting; run `p10k configure` to pick a more conservative style.

**Where did my old `.zshrc` go?** `~/.zshrc-backup-<timestamp>` — the
installer prints the exact name when it backs it up.

## Changes from earlier ftazsh versions

* Linux support removed — this is a macOS-only tool now.
* Fonts come from Homebrew casks instead of cloning the nerd-fonts repo
  (which was gigabytes). The iTerm2 profile now references the current
  (v3) font name, `JetBrainsMonoNF-ExtraBold`.
* `marker` (abandoned upstream) and the unused `k` plugin were dropped;
  fzf's `Ctrl-R` and `zoxide` cover the same ground.
* The oh-my-zsh `z` plugin was replaced by `zoxide`.
* `--cp-hist` (bash→zsh history migration) was removed — macOS has
  defaulted to zsh since 2019, and the feature piped a downloaded gist
  into Python.
* `wget` is no longer installed; macOS ships `curl`.
* The config no longer exports `TERM`.
