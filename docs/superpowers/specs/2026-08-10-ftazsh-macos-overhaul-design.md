# ftazsh macOS Overhaul — Design

**Date:** 2026-08-10
**Status:** Implemented and merged to main (2026-08-10). Original directive: "well designed, written and tested, developer friendly, modern unix tools ready to go, macOS latest only, test in Docker"
**Branch:** `redesign/macos-overhaul`

## Goals

1. macOS (latest) only — remove Linux paths and legacy migration features.
2. Well designed & written — strict-mode installer, idempotent re-runs, honest exit codes.
3. Tested — lint + unit tests + Docker integration tests + CI workflow.
4. Developer friendly — clear output, `--help`, safe re-runs, uninstaller, no surprise sudo prompts.
5. Modern unix tools ready to go — installed by the installer *and* wired into the shell config with graceful fallbacks.

## Assessment of current state (defects found)

Correctness bugs:

- `install.sh` ends with unconditional `exit 0` — the installer always reports success, even on failure.
- No strict mode / error strategy; failed steps cascade silently.
- `.zshrc:41` sets `FZF_DEFAULT_OPS` (typo — never read by fzf; should be `FZF_DEFAULT_OPTS`).
- `alias l` in `ftazshrc.zsh` is silently clobbered: oh-my-zsh's `lib/directories.zsh` defines `alias l='ls -lah'` and OMZ loads *after* ftazsh aliases.
- Plugin order violates upstream requirements: `zsh-syntax-highlighting` must load last among widgets, with `history-substring-search` after it. Current list loads syntax highlighting early.
- `zsh-autosuggestions` is cloned into `$ZSH/plugins/` (inside the OMZ git worktree) — this dirties the OMZ repo and breaks `omz update`.
- `zsh-completions` is cloned but never added to `fpath` — dead weight; completions never load.
- `zsh-history-substring-search` is cloned into custom/plugins, but the plugins list uses OMZ's *built-in* `history-substring-search` — the clone is dead weight.
- `k` is cloned but absent from the plugins list — dead weight.
- `mv ~/.zcompdump*` with an unmatched glob fails (bash passes the literal pattern).
- Re-running the installer re-backs-up ftazsh's *own* generated `.zshrc` and `mv -n` silently no-ops on same-day collisions.
- `copy_config_files` force-overwrites `personal_rc.zsh` inside the *user's personal config directory* on every run — destroys user edits.

Design problems:

- `export TERM="xterm-256color"` in shell config — breaks terminals that set their own TERM (kitty, ghostty, tmux).
- Full `nerd-fonts` repo clone (multi-GB) to install a handful of fonts.
- `marker` is abandoned upstream (Python-2-era; `install.py` flaky on modern Python).
- Bash-history migration downloads a gist and pipes it into Python — supply-chain risk for a legacy need (macOS defaults to zsh since Catalina, 2019).
- `wget` is installed as a dependency solely for that gist; macOS ships curl.
- `chsh` runs unconditionally (sudo prompt) even when the login shell is already `/bin/zsh` — which it is on every modern macOS.
- `omz update` runs immediately after a fresh clone, inside `change_default_shell` of all places.
- `systemd` plugin loaded on macOS.
- Linux path uses `sudo apt || sudo pacman || sudo dnf || sudo yum || pkg` — repeated sudo attempts; removed per macOS-only directive.
- `NPM_PACKAGES=~/.npm` PATH entry (npm does not install binaries there by default) and `~/.config/ftazsh/bin` on PATH but never created.
- Dependency check early-returns when zsh/git/wget exist, so Homebrew is never guaranteed for later steps.

Documentation/asset drift:

- README documents `scripts/` and `examples/` directories that do not exist; usage header says `install_new.sh`; `l`/`a` alias docs are wrong; marker links to the wrong upstream.
- `iterm2-profile.json` references `JetBrainsMonoNerdFontCompleteM-ExtraBold` — a Nerd Fonts **v2** name that no longer exists in v3 releases, so a fresh install can't resolve the profile's font.
- No tests, no CI, no uninstaller.

## Approaches considered

**A. Keep the architecture, overhaul the implementation (chosen).** Keep oh-my-zsh + Powerlevel10k + the `~/.config/ftazsh` layout + copied `~/.zshrc`. Rewrite the installer macOS-native (Homebrew for tools *and* fonts), fix the config-loading order with a two-phase design, wire in modern tools, add tests/CI/uninstaller. Lowest user-facing disruption; preserves the p10k config and muscle memory; delivers every stated goal.

**B. Replace oh-my-zsh with a lighter plugin manager (antidote/zinit) and/or starship.** Faster startup and cleaner internals, but discards the user's known workflow, invalidates the existing p10k investment, and was not asked for.

**C. Minimal bug-fix patch.** Fixes typos/exit codes only; does not deliver "modern tools ready to go" nor "tested".

A is chosen: B is a rewrite nobody asked for; C under-delivers.

## Design

### Repository layout (after)

```
ftazsh/
├── install.sh              # macOS-only installer (bash 3.2-compatible strict mode)
├── uninstall.sh            # restore backup, remove ~/.config/ftazsh
├── .zshrc                  # orchestrator, copied to ~/.zshrc (contains managed-by marker)
├── ftazshrc.zsh            # phase 1 — pre-OMZ: $ZSH, theme, plugins, options, history, fpath, PATH
├── tools.zsh               # phase 2 — post-OMZ: modern tool init, aliases, functions   [NEW]
├── p10k.zsh                # Powerlevel10k config (unchanged)
├── personal_rc.zsh         # example personal config (trimmed)
├── iterm2-profile.json     # font updated to Nerd Fonts v3 name
├── Makefile                # make lint / unit / integration / test / docker-test
├── tests/
│   ├── unit/install.bats   # bats unit tests with stubbed uname/brew/chsh/dscl
│   ├── integration/zsh_boot.sh  # real zsh boot against an installed layout
│   └── docker/Dockerfile   # Linux test image (zsh, bats, shellcheck, fzf, zoxide, eza)
├── .github/workflows/ci.yml
└── .shellcheckrc
```

### Shell config: two-phase load

`~/.zshrc` (orchestrator, marker line `# ftazsh-managed` near top):

1. Powerlevel10k instant prompt (unchanged).
2. `source ~/.config/ftazsh/ftazshrc.zsh` — **pre-OMZ**: `$ZSH`, `ZSH_THEME`, `plugins=(…)`, OMZ options, history sizes, `ZSH_COMPDUMP` in `~/.cache/zsh`, `fpath+=` for zsh-completions, PATH additions.
3. `source ~/.config/ftazsh/p10k.zsh` — prompt config (kept before user files so users can override P9K vars).
4. Source every file in `~/.config/ftazsh/zshrc/` — users may append to `plugins`, set env, override anything (existing contract, preserved).
5. `source $ZSH/oh-my-zsh.sh`.
6. `source ~/.config/ftazsh/tools.zsh` — **post-OMZ**: everything that must win over OMZ defaults — `l`/`a`/`aa` aliases, fzf keybindings (`source <(fzf --zsh)`), `zoxide init`, `FZF_*` env, functions (`cheat`, `myip`, `speedtest`, `dadjoke`, `ipgeo`).

This fixes the `l` clobbering and the Ctrl-R override problem structurally instead of by accident of ordering.

Every tool integration in `tools.zsh` is guarded with `command -v` — a machine missing a tool gets a working shell, never an error.

### Plugins (final list, in order)

`macos brew git python pip docker extract sudo zsh-autosuggestions zsh-syntax-highlighting history-substring-search`

- All third-party plugins cloned into `$ZSH/custom/plugins/` (never inside the OMZ worktree). Installer removes a legacy `$ZSH/plugins/zsh-autosuggestions` clone if found (migration).
- `zsh-completions` used via `fpath+=` (per its README), not as a plugin.
- `z` plugin dropped in favor of `zoxide` (`z`/`zi` commands via `zoxide init zsh`).
- `systemd`, `k`, `marker`, standalone `zsh-history-substring-search` clone: removed.
- `TERM` export: removed.

### Modern tool set (installed via Homebrew, wired in `tools.zsh`)

| Tool | Wiring |
|---|---|
| eza | `a` / `aa` aliases (existing muscle memory, kept) |
| bat | fzf Ctrl-T preview; colored man pages via `MANPAGER` |
| fd | `FZF_DEFAULT_COMMAND` / `FZF_CTRL_T_COMMAND` (respects .gitignore) |
| ripgrep | installed; no config needed |
| fzf | `source <(fzf --zsh)` post-OMZ; sane `FZF_DEFAULT_OPTS`; fixes the Ctrl-R note |
| zoxide | `eval "$(zoxide init zsh)"` post-OMZ; replaces OMZ `z` |
| jq | installed; no config needed |

Fonts via Homebrew casks (`font-jetbrains-mono-nerd-font`, `font-hack-nerd-font`) — replaces the multi-GB nerd-fonts repo clone. If the JetBrains Mono cask fails, the installer falls back to downloading the official nerd-fonts release zip and copying the TTFs into `~/Library/Fonts` (URL/destination overridable via `FTAZSH_JBM_FONT_URL`/`FTAZSH_FONT_DIR` for tests). iTerm profile font updated to the v3 name so the imported profile resolves.

### Installer design (`install.sh`)

- Bash 3.2-compatible (macOS ships 3.2): `set -euo pipefail`, `ERR` trap naming the failed step, no bash-4 features.
- Function-per-step; `main` guarded by `[[ "${BASH_SOURCE[0]}" == "$0" ]]` so tests can source the file and unit-test functions with stubs.
- Hard macOS guard (`uname -s` = Darwin) with a clear message.
- Flags: `--help/-h`, `--unattended` (no sudo, no chsh, no prompts — for CI), unknown flag → usage + exit 2. `--cp-hist` removed (legacy; documented in README changelog section).
- Steps: ensure Homebrew (idempotent shellenv line in `~/.zprofile`, appended only if absent) → install formulae (per-formula loop, report failures, fail at end if any) → install font casks → backup `~/.zshrc` (skip if ftazsh-managed; timestamped to the second) → create dirs, migrate `.zcompdump*` safely → clone-or-update OMZ + 3 plugin repos (`git -C … pull --ff-only` on update; legacy-location cleanup) → copy configs (**never overwrite files in the user's `zshrc/` dir**; example copied only if absent) → default shell: skip entirely if login shell is already zsh (query `dscl`, fall back to `$SHELL`), else `/etc/shells` + `chsh` (skipped under `--unattended`).
- Existing `~/.oh-my-zsh` installations are left untouched (previous script moved them; surprising — dropped).
- Honest exit status; summary of what happened and next steps at the end.

### Uninstaller (`uninstall.sh`)

Restores the newest `~/.zshrc-backup-*` (or removes the managed `.zshrc` if no backup), removes `~/.config/ftazsh` after confirmation (`--yes` to skip), prints the `brew uninstall` / `brew uninstall --cask` commands for the tools/fonts without running them (they may be used by other software).

### Testing

- **Lint:** shellcheck for `install.sh`/`uninstall.sh`/test scripts; `zsh -n` for every `.zsh` file and the repo `.zshrc`.
- **Unit (bats):** source `install.sh`, stub `uname`/`brew`/`chsh`/`dscl` via a PATH shim dir, `HOME` pointed at a temp dir. Covers: macOS guard, arg parsing, backup semantics (marker skip, timestamping), config copy (personal dir never clobbered), shell-change skip logic, per-formula brew loop, clone-or-update using local `file://` fixture repos (no network), legacy plugin-location migration.
- **Integration (Docker):** Linux image with zsh/git/fzf/zoxide/eza (bat/fd absent — exercises the graceful-degradation guards). Installs the real config layout (real OMZ + plugin clones), then boots interactive zsh with p10k wizard/gitstatus disabled and asserts: clean startup (no stderr), aliases/functions defined, plugins loaded, user-override file sourced, `plugins+=` from a user file takes effect, `FZF_DEFAULT_OPTS` set, fzf/zoxide integrations active.
- **CI (GitHub Actions):** ubuntu job runs lint + unit + integration natively (same scripts as Docker); macos-latest job runs `./install.sh --unattended` for real, then asserts tools on PATH and a clean zsh boot. (The macOS job is the true end-to-end; it runs on push/PR — not runnable from this machine.)
- **Local dev:** `make docker-test` builds the image and runs everything in a container; safe on the host Mac.

### Error handling philosophy

Installer: fail fast and loud per step, with the failing step named. Shell config: never fail — every optional integration is guarded; a missing tool degrades to stock behavior silently.

### Out of scope

Plugin-manager migration, dotfile symlinking/chezmoi, Linux support, prompt redesign (p10k config untouched), auto-configuring git with delta, atuin.
