# ftazsh — a modern zsh environment for macOS

One command sets up a complete terminal environment on a fresh (or not so
fresh) Mac: [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh), the
[Powerlevel10k](https://github.com/romkatv/powerlevel10k) prompt, Nerd Fonts,
fish-style shell behavior, the latest git, and a curated set of modern unix
tools — installed with Homebrew and already wired into the shell and into git.
It keeps itself up to date, and it can be removed completely.

**macOS only** (macOS 15 Sequoia, 26 Tahoe, 27 Golden Gate; Apple Silicon or
Intel). The installer refuses to run anywhere else. Works with Homebrew 5–7.

## What you get

**Modern unix tools**, installed via Homebrew and integrated out of the box:

| Tool | What it replaces | How ftazsh wires it in |
|---|---|---|
| [git](https://git-scm.com) (Homebrew, 2.55+) | Apple's older git | Made the default `git`; reftable-ready ([details](#git)) |
| [eza](https://github.com/eza-community/eza) | `ls`, `tree` | **is** `ls`: icons, colors, directories first; `ll`/`la` long views with git status, `l` (oldest → newest), `lt` (tree), `a`/`aa` |
| [bat](https://github.com/sharkdp/bat) | `cat` / pager | colored `man` pages, fzf file previews |
| [fd](https://github.com/sharkdp/fd) | `find` | powers fzf file and directory search (respects `.gitignore`) |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | `grep` | installed, ready to use as `rg` |
| [fzf](https://github.com/junegunn/fzf) | — | `Ctrl-R` history (`Ctrl-/` preview), `Ctrl-T` files, `Alt-C` cd |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `cd` | `z <fuzzy-dir>` jumps, `zi` interactive picker |
| [jq](https://github.com/jqlang/jq) | — | installed, ready to use |
| [delta](https://github.com/dandavison/delta) | git's diff pager | git pager and `git add -p` filter ([git defaults](#git-defaults-ftazsh-sets)) |
| [difftastic](https://github.com/Wilfred/difftastic) | `diff` | `git dft`, `git dlog`, `git dshow` (structural diffs) |
| [lazygit](https://github.com/jesseduffield/lazygit) | — | `lg` |
| [gh](https://cli.github.com) | — | GitHub CLI, completions included |
| [dust](https://github.com/bootandy/dust) | `du` | installed |
| [duf](https://github.com/muesli/duf) | `df` | installed |
| [procs](https://github.com/dalance/procs) | `ps` | installed |
| [btop](https://github.com/aristocratos/btop) | `top` | installed |
| [sd](https://github.com/chmln/sd) | `sed` (find & replace) | installed |
| [hyperfine](https://github.com/sharkdp/hyperfine) | `time` | installed |
| [tealdeer](https://github.com/tealdeer-rs/tealdeer) | `man` (quick examples) | `tldr <command>`, page cache primed at install |
| [yazi](https://github.com/sxyazi/yazi) | — | `y` opens the file manager and cds to where you quit |

Completions for all of them are on `fpath` before oh-my-zsh runs `compinit`.

**Shell experience** (all of it is on by default; nothing to enable):

* Powerlevel10k prompt (instant prompt enabled, config included) — and it stays
  correct inside [reftable](#reftable) git repositories, which stock
  Powerlevel10k cannot read
* [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions): a
  grey suggestion appears as you type, from your history first and then from
  what Tab would complete. → or End accepts it, Ctrl-→ / Alt-F accepts one
  word.
* [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting):
  valid commands green, unknown ones red, matching brackets highlighted,
  `rm -rf *` flagged in red.
* [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search):
  type part of a command, then ↑/↓ (or Ctrl-P / Ctrl-N) walk through the
  commands containing it, each shown once.
* [zsh-completions](https://github.com/zsh-users/zsh-completions) plus the
  completions Homebrew ships for every installed tool: Tab opens a grouped,
  described menu you can navigate with the arrow keys; matching is case- and
  hyphen-insensitive.
* oh-my-zsh plugins `macos brew git python pip docker extract sudo`
* 50k-line shared history, completion dumps kept out of `$HOME`
* Helpers: `myip`, `cheat <topic>`, `speedtest`, `dadjoke`, `ipgeo [ip]`, `e` (exit)

**`ls` is eza.** `ls` lists with icons and colors, directories first; `ll`
and `la` are long views with a header and each file's git status; `l` shows
everything oldest → newest; `lt` is a two-level tree; `a`/`aa` add
color-scaled sizes and dates. Icons only appear on a terminal, so piping
`ls` into other commands keeps working. eza's flags differ from BSD ls in
places (`ls -lt` is `ll -s modified`, `ls -lS` is `ll -s size`); the original
is one escape away: `\ls`.

**Fonts:** twelve families, installed per user into `~/Library/Fonts` (where
macOS looks for a user's fonts; every app sees them, no admin rights needed):

* Nerd Fonts, patched with the icons the prompt uses: **JetBrains Mono**,
  **Hack**, **Meslo LGS** (Powerlevel10k's recommended font), **Fira Code**,
  **Caskaydia Cove** (Cascadia Code), **Sauce Code Pro** (Source Code Pro) and
  **Symbols Only** (icon fallback for any other font).
* The plain, unpatched versions for editors: JetBrains Mono, Fira Code,
  Cascadia Code, Source Code Pro, Hack.

Every family comes from a Homebrew cask. If a Nerd Font cask fails, the
installer downloads that family straight from the official nerd-fonts release
instead; a cask that Homebrew lists but whose files are gone is reinstalled;
and after installing, the installer and `ftazsh doctor` check that each
family's font file is actually present. The plain families are best effort
(a failure is a warning).

**Self-maintaining:** `ftazsh update` (or the automatic check, see below)
brings ftazsh, oh-my-zsh, the plugins, Powerlevel10k *and* the Homebrew tools
to their latest versions. `ftazsh doctor` tells you if anything is off.

## Install

```bash
git clone https://github.com/anxuanzi/ftazsh
cd ftazsh
./install.sh
```

or, without cloning first:

```bash
curl -fsSL https://raw.githubusercontent.com/anxuanzi/ftazsh/main/install.sh | bash
```

Re-running `./install.sh` later **updates** everything (oh-my-zsh, plugins,
theme, configs). It is idempotent and safe. Add `--upgrade` to also upgrade
the Homebrew tools (that is what `ftazsh update` does).

```
Usage: ./install.sh [OPTIONS]
  -h, --help        Show help
      --unattended  Non-interactive: never prompts, skips changing the
                    login shell (prints the command instead). For CI.
      --upgrade     Also upgrade the Homebrew tools ftazsh manages.
```

The installer:

1. Installs Homebrew if missing (and adds it to `~/.zprofile`); runs
   `brew update` once
2. Installs the tools and fonts listed above (skips what's already there;
   Homebrew 6+ "ask mode" is disabled for the run so nothing blocks; Nerd
   Fonts fall back to the official release download if a cask fails)
3. Backs up a pre-existing `~/.zshrc` to `~/.zshrc-backup-<timestamp>`
4. Clones oh-my-zsh, plugins, and Powerlevel10k under `~/.config/ftazsh/`
5. Keeps a clone of ftazsh itself in `~/.config/ftazsh/repo` — the source for
   `ftazsh update`
6. Installs the ftazsh config files and the `ftazsh` command
7. Includes ftazsh's [git defaults](#git-defaults-ftazsh-sets) from your
   global git config (your own settings always win)
8. Offers to make zsh your login shell — skipped automatically if it
   already is (which is the macOS default)

Then open a new terminal window. Run `p10k configure` any time to restyle
the prompt, and `ftazsh doctor` to check the installation.

### Terminal font

Set your terminal's font to one of the Nerd Fonts above (for example
**JetBrainsMono Nerd Font** or **MesloLGS Nerd Font**) so prompt icons
render. iTerm2 users can import the bundled profile (font pre-set):
*Settings → Profiles → Other Actions… → Import JSON Profiles…* → pick
`iterm2-profile.json`. To keep a font that has no icons, set **Symbols Nerd
Font Mono** as the fallback (iTerm2: *Use a different font for non-ASCII
text*; Kitty, WezTerm and Ghostty pick it up automatically).

## Upgrading from an older ftazsh

Run the installer again from an up-to-date checkout (or use the one-liner
above):

```bash
cd ftazsh && git pull && ./install.sh
```

That is the whole upgrade, whichever version you have:

* **From the August 2026 version** (`~/.config/ftazsh` with `ftazshrc.zsh`
  and `tools.zsh`): the managed configs are replaced in place, everything in
  `~/.config/ftazsh/zshrc/` is kept, the new tools and fonts are installed,
  the git defaults are included, and the managed clone that powers
  `ftazsh update` is created. From then on updates are automatic.
* **From the original ftazsh** (the one that cloned the whole nerd-fonts
  repository): the same, plus your old `~/.zshrc` (which had no
  ftazsh-managed marker) is backed up, and the leftovers this version no
  longer uses are removed: the in-tree `zsh-autosuggestions` clone, the `k`
  and `zsh-history-substring-search` plugin clones, ftazsh's own `fzf` clone
  and the `~/.fzf.zsh` / `~/.fzf.bash` it generated, the `marker` clone, and
  the multi-gigabyte `nerd-fonts` clone inside the checkout. Only clones the
  old installer made are touched; a plugin you put there yourself stays.
  marker's data in `~/.local/share/marker` is left alone. If one of your own
  files in `zshrc/` still adds a removed plugin (`k`, `z`, `marker`), remove
  that line to silence oh-my-zsh's warning.

`ftazsh doctor` points out any leftovers it still sees. Prefer a fresh start?
`ftazsh reinstall` (or `./uninstall.sh` followed by `./install.sh`) gives you
a clean install and keeps your `.zshrc` backups and personal files.

## Keeping it up to date

```
ftazsh update                 # ftazsh + oh-my-zsh + plugins + prompt + Homebrew tools
ftazsh update --no-tools      # same, but leave the Homebrew tools alone
ftazsh update --check         # just report (exit 0 = current, 1 = update available)
```

**Automatic updates.** Every 7 days a background job checks whether a new
ftazsh version exists (a `git fetch` of the managed clone; it never slows
the shell down). When one is found, the next shell you open asks:

```
[ftazsh] Update available (3 new commits). Update now? [Y/n]
```

`Enter`/`y` updates right there (and the new configuration is loaded into
that very shell); `n` snoozes for another interval; no answer within 15
seconds snoozes for a day. Tune this in `~/.config/ftazsh/settings.zsh`,
which ftazsh never overwrites:

```zsh
FTAZSH_UPDATE_MODE=prompt        # prompt | auto | reminder | disabled
FTAZSH_UPDATE_FREQUENCY_DAYS=7
FTAZSH_UPDATE_TOOLS=1            # 0 = updates don't touch the Homebrew tools
```

oh-my-zsh's own update prompts are disabled on purpose — ftazsh updates it.

## The `ftazsh` command

```
ftazsh update [--check] [--tools|--no-tools] [--yes]   update everything
ftazsh doctor                                          check the installation
ftazsh version                                         installed version
ftazsh reinstall [--yes]                               clean uninstall + fresh install
ftazsh uninstall [--yes] [--tools] [--purge]           remove ftazsh
ftazsh reftable status|on|off|migrate [DIR] [--yes]    git reftable helpers
```

`ftazsh doctor` verifies Homebrew, that `git` is Homebrew's and
reftable-capable, every managed tool, the fonts, the config files, the git
config include, the login shell, and that the reftable-safe prompt shim is
active. It exits non-zero if anything needs attention.

## Git

### The latest git is the default git

Apple's command line tools ship an older git. ftazsh installs Homebrew's
(2.55 or newer) and makes sure Homebrew's `bin` leads `PATH` in every
ftazsh shell — login or not — so `git` *is* the new one. `ftazsh doctor`
confirms it:

```
✅  git 2.55.0 is Homebrew's (/opt/homebrew/bin/git) — the default git
✅  git 2.55.0 supports reftable (git init --ref-format=reftable, git refs migrate)
⚠️   Apple's git: git version 2.50.1 (Apple Git-155) (shadowed, not used)
```

### Reftable

Git 2.45 introduced the [reftable](https://git-scm.com/docs/reftable) ref
storage backend and Git 3.0 makes it the default for new repositories. Its
one practical catch today: tools built on libgit2 cannot open such
repositories yet — including gitstatusd, the engine behind Powerlevel10k's
git prompt segment, which shows a bogus `.invalid` branch there
([romkatv/powerlevel10k#2941](https://github.com/romkatv/powerlevel10k/issues/2941)).

ftazsh fixes the prompt: `git.zsh` hooks the two Powerlevel10k functions that
turn gitstatusd's answer into prompt text and, in reftable repositories only,
recomputes the status with the git CLI (branch, upstream, ahead/behind,
staged/unstaged/untracked/conflicted counts, stashes, tags, and merge /
rebase / cherry-pick / revert / bisect state). Classic repositories keep the
fast gitstatusd path; styling and `p10k configure` are untouched. Very large
repositories (index over 16 MB, see `FTAZSH_VCS_MAX_INDEX_BYTES` in
`settings.zsh`) skip the dirty-state scan.

Nothing is switched to reftable for you. When you want it:

```
ftazsh reftable status            # git version, default format, this repo's format
ftazsh reftable on                # new repos (git init / clone) use reftable
ftazsh reftable off               # back to git's default
ftazsh reftable migrate [DIR]     # convert one repository (git refs migrate)
```

oh-my-zsh's git aliases, fzf, lazygit, gh and delta all go through the git
CLI, so they work in reftable repositories as-is.

### Git defaults ftazsh sets

`~/.config/ftazsh/gitconfig` is included from your global git config
**before** your own settings, so anything you set with `git config --global`
(now or later) overrides it. What it configures:

* `delta` as pager and `git add -p` filter (with navigation, line numbers,
  hyperlinks; via `bin/ftazsh-pager`, which falls back to `less` if delta is
  ever missing), `diff.colorMoved`, histogram diff, `zdiff3` conflict markers
* `git dft` / `git dlog` / `git dshow` — difftastic aliases
* `credential.helper = osxkeychain` (Homebrew's git does not read Apple's
  system gitconfig where this normally lives)
* `init.defaultBranch = main`, `push.autoSetupRemote`, `fetch.prune`,
  `rebase.autoSquash/autoStash/updateRefs`, `rerere`, `branch.sort` by date,
  `tag.sort` by version, `column.ui`, `commit.verbose`, `core.untrackedCache`

Uninstalling removes the include and leaves your own settings exactly as
they were.

## How the config is organized

```
~/.zshrc                      # thin orchestrator installed by ftazsh (marked "ftazsh-managed")
~/.config/ftazsh/
├── settings.zsh              # ← YOUR settings (update mode, …), seeded once, never overwritten
├── update.zsh                # startup update check (runs before the instant prompt)
├── ftazshrc.zsh              # core setup, loads BEFORE oh-my-zsh (Homebrew PATH, plugins, history)
├── p10k.zsh                  # Powerlevel10k prompt configuration
├── tools.zsh                 # tool integrations + aliases, loads AFTER oh-my-zsh
├── git.zsh                   # git integration: reftable-safe prompt
├── gitconfig                 # git defaults, included from your global git config
├── bin/ftazsh                # the ftazsh command (+ ftazsh-pager)
├── zshrc/                    # ← YOUR files live here (sourced in name order)
│   └── personal_rc.zsh       # example, seeded once, never overwritten
├── repo/                     # clone of ftazsh (source for updates)
├── state/                    # update-check bookkeeping
└── oh-my-zsh/                # oh-my-zsh + plugins + theme (managed by installer)
```

Load order: settings → update check → instant prompt → `ftazshrc.zsh` →
`p10k.zsh` → **your files** → oh-my-zsh → `tools.zsh` → `git.zsh`. Your files
load before oh-my-zsh, so they can add plugins; `tools.zsh` loads after it,
so ftazsh's aliases and keybindings can't be clobbered by oh-my-zsh defaults.

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

## Uninstall and clean reinstall

```bash
./uninstall.sh            # or: ftazsh uninstall     (add --yes to skip the confirmation)
./uninstall.sh --tools    # also brew-uninstall the tools and fonts ftazsh installed
./uninstall.sh --purge    # --tools plus their caches
```

Always: restores your most recent `.zshrc` backup, removes ftazsh's git
config include (your settings stay), backs up `~/.config/ftazsh/zshrc/` next
to the `.zshrc` backups, removes `~/.config/ftazsh` and the caches ftazsh
created. Never touched: Homebrew itself, `~/.zprofile`, your backups, zoxide's
database.

`ftazsh reinstall` does a full uninstall (keeping the tools) followed by a
fresh install of the latest version — the "start clean" button.

## Development & testing

The repo has a real test suite; everything except Homebrew itself runs in
Docker:

```bash
make docker-test    # build the Linux test image and run lint + unit + integration
make lint           # shellcheck + `zsh -n` on every script and config (host)
make unit           # bats unit tests for installer / uninstaller / ftazsh CLI
make integration    # real layout in a scratch HOME: zsh boot, reftable prompt, update flow
```

* Unit tests stub `uname`/`brew`/`chsh`/`dscl`, so no test touches your
  system. Upstream fixtures are snapshots of the working tree, so
  uncommitted changes are tested too.
* The integration test exercises the graceful-degradation paths on purpose
  (the image has no `bat`/`fd`, and an fzf too old for `--zsh`), renders the
  prompt in a real pseudo-terminal for a reftable repository (with gitstatusd
  when it can be fetched), and runs the whole `ftazsh update` flow against a
  local upstream.
* CI runs the Linux suite plus, on GitHub's macOS runners, a real
  `./install.sh --unattended` (tools on PATH, Homebrew git as default,
  reftable prompt, `ftazsh doctor`, the update flow, uninstall) **and** the
  sandboxed smoke test below. The workflow can also be started by hand from
  the repository's Actions tab (*Run workflow*).

### Testing on your own Mac

```bash
make mac-test                       # bash tests/macos/smoke.sh [--yes] [--keep-tools] [--keep-sandbox]
```

Runs the real installer against a **throwaway HOME** (CI runs exactly this
script on a macOS runner too): your `~/.zshrc`,
`~/.gitconfig`, `~/.config/ftazsh`, caches and history are never touched.
Homebrew is machine-wide, so the tools and fonts are installed for real —
and at the end the script uninstalls exactly those that were not on the
machine before (unless `--keep-tools`) and deletes the sandbox. In between it
checks everything the macOS CI job checks, using the real gitstatusd for the
reftable prompt, plus the update reminder, `ftazsh reftable migrate`, an
idempotent re-install and a clean uninstall. Takes a few minutes the first
time.

## Troubleshooting

**`ftazsh doctor` first.** It names the exact problem and the fix.

**`git` is not the new one?** Open a new terminal; ftazsh puts Homebrew
first on `PATH` in every interactive shell. If your own files in
`~/.config/ftazsh/zshrc/` reorder `PATH`, do it with `path=(… $path)`.

**Broken icons?** Your terminal isn't using a Nerd Font — see
[Terminal font](#terminal-font) above.

**`ls -lt` complains about `--time`?** `ls` is eza, whose flags differ from
BSD ls: sort with `ll -s modified` (add `-r` to reverse) or `ll -s size`, or
use `\ls -lt` for the original.

**Prompt looks wrong over SSH / in a basic terminal?** That's Powerlevel10k
adapting; run `p10k configure` to pick a more conservative style.

**Prompt shows `.invalid` as the branch?** That is Powerlevel10k without the
ftazsh shim in a reftable repository; `ftazsh doctor` reports whether the
shim is active (it needs `git.zsh` to be loaded — re-run `./install.sh`).

**Update check never runs?** It only runs in interactive shells with
`FTAZSH_UPDATE_MODE` other than `disabled`, and only when
`~/.config/ftazsh/repo` exists; `ftazsh update --check` runs it by hand.

**Where did my old `.zshrc` go?** `~/.zshrc-backup-<timestamp>` — the
installer prints the exact name when it backs it up.

## Changes in the September 2026 refresh

* Tools added: delta, difftastic, lazygit, gh, dust, duf, procs, btop, sd,
  hyperfine, tealdeer, yazi (all Homebrew-bottled for macOS 26/27 on Apple
  Silicon). fzf `Ctrl-R` preview toggle, `Alt-C` directory previews, `tree`.
* `ls` is eza (icons, colors, directories first, git status in `ll`/`la`).
* The zsh-users plugins come configured: suggestions from history then
  completion, brackets and dangerous-pattern highlighting with readable
  comments, unique substring history search with Ctrl-P/N and vi keys, and a
  grouped, described completion menu.
* Fonts: twelve families instead of two (Meslo LGS, Fira Code, Cascadia,
  Source Code Pro and the Symbols-only Nerd Fonts, plus the plain editor
  versions), each Nerd Font with a release-download fallback, and a presence
  check per family in the installer and in `ftazsh doctor`.
* Homebrew's git is now guaranteed to be the default `git` (PATH ordering in
  every ftazsh shell), with managed git defaults via a config include that
  your own settings override.
* Reftable support: the Powerlevel10k prompt works in reftable repositories
  (git CLI shim), plus `ftazsh reftable` helpers.
* Self-update: `ftazsh update`, automatic background checks with
  prompt/auto/reminder modes, `ftazsh doctor`, `ftazsh version`.
* Complete uninstall (`--tools`, `--purge`) and one-command clean reinstall.
* Homebrew 6/7 compatibility: ask mode disabled for unattended runs, one
  explicit `brew update`, cask reinstall when font files went missing, Intel
  Tier-3 warning.
* Managed files are replaced atomically; `~/.zshrc` backups are deduplicated.
* Tests: bats suites for installer, uninstaller and CLI; integration test with
  pseudo-terminal prompt rendering and the update flow; `make mac-test` for a
  sandboxed end-to-end run on your Mac.

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
