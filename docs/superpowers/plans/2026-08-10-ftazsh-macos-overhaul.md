# ftazsh macOS Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild ftazsh as a macOS-only, Homebrew-native, tested zsh environment installer with modern unix tools wired into the shell config.

**Architecture:** Two-phase zsh config load (pre-OMZ `ftazshrc.zsh`, post-OMZ `tools.zsh`) orchestrated by a copied `~/.zshrc`; a function-per-step bash installer that is sourceable for unit testing; Docker-based Linux tests for everything except Homebrew, which is covered by a macOS CI job.

**Tech Stack:** bash 3.2 (macOS stock), zsh 5.9, Homebrew, oh-my-zsh, Powerlevel10k, bats-core, shellcheck, Docker (ubuntu:24.04), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-10-ftazsh-macos-overhaul-design.md` (authoritative for scope and rationale).

## Global Constraints

- Installer must run on stock macOS bash 3.2: `set -euo pipefail` allowed; NO associative arrays, NO `${var,,}`, NO `mapfile`.
- Every function in `install.sh`/`uninstall.sh` must work when the file is sourced; `main "$@"` only runs under `[[ "${BASH_SOURCE[0]}" == "$0" ]]`.
- Managed-file marker (exact string, first line of repo `.zshrc`): `# ftazsh-managed — do not edit; personal config goes in ~/.config/ftazsh/zshrc/`. Detection everywhere: `grep -q "ftazsh-managed"`.
- Formulae (exact list/order): `git eza bat fd ripgrep fzf zoxide jq`. Casks: `font-jetbrains-mono-nerd-font font-hack-nerd-font`.
- Env overrides honored by installer (for tests): `FTAZSH_OMZ_REPO` (default `https://github.com/ohmyzsh/ohmyzsh.git`), `FTAZSH_PLUGIN_BASE_URL` (default `https://github.com/zsh-users`). Third-party plugins (exact): `zsh-autosuggestions zsh-syntax-highlighting zsh-completions` cloned under `$HOME/.config/ftazsh/oh-my-zsh/custom/plugins/`.
- Shell config files must never emit errors when a tool is missing: guard every integration with `command -v <tool> >/dev/null`.
- All zsh files must pass `zsh -n`; all bash files must pass shellcheck with repo `.shellcheckrc`.
- Backups: `~/.zshrc-backup-$(date +%Y-%m-%d-%H%M%S)`; never overwrite an existing backup; skip backup when current `~/.zshrc` is ftazsh-managed.
- Never overwrite any existing file inside `~/.config/ftazsh/zshrc/`.

---

### Task 1: Test scaffolding (Makefile, shellcheck config, Docker image)

**Files:**
- Create: `Makefile`, `.shellcheckrc`, `tests/docker/Dockerfile`, `tests/docker/run.sh`

**Interfaces:**
- Produces: `make lint` (shellcheck on `install.sh uninstall.sh tests/integration/zsh_boot.sh` + `zsh -n` on `.zshrc *.zsh`), `make unit` (`bats tests/unit`), `make integration` (`bash tests/integration/zsh_boot.sh`), `make test` (lint+unit+integration), `make docker-test` (build image, run `tests/docker/run.sh` in container as non-root).
- Docker image: ubuntu:24.04 + `zsh git curl ca-certificates locales bats shellcheck make fzf zoxide eza` (deliberately NO bat/fd — degradation path), `en_US.UTF-8` locale, non-root user `tester`, repo mounted/copied to `/home/tester/ftazsh`.

- [ ] Write the four files; `run.sh` executes `make lint unit integration` inside the container.
- [ ] Verify: `docker build -f tests/docker/Dockerfile -t ftazsh-test .` succeeds; `make lint` passes trivially for files that exist so far (guard targets against missing files until later tasks land).
- [ ] Commit: `test: add lint/unit/integration scaffolding and Docker test image`

### Task 2: Unit tests for installer (red)

**Files:**
- Create: `tests/unit/install.bats`, `tests/unit/helpers.bash`

**Interfaces:**
- Consumes installer contract (Task 3 must satisfy): functions `require_macos`, `parse_args`, `usage`, `ensure_homebrew`, `install_brew_formulae`, `install_brew_casks`, `backup_zshrc`, `create_directories`, `install_omz`, `install_plugin_repos`, `copy_config_files`, `ensure_default_shell`, `main`; globals `UNATTENDED` (0/1), `FTAZSH_HOME` (`$HOME/.config/ftazsh`, computed at source time).
- Stub strategy (`helpers.bash`): `make_stubs` creates `$BATS_TEST_TMPDIR/bin` with executable fakes (`uname` echoing Darwin/Linux, `brew` logging `$*` to `$STUB_LOG` and honoring a `BREW_FAIL_ON` env, `chsh` logging, `dscl` echoing a configurable shell) and prepends it to PATH; `HOME=$BATS_TEST_TMPDIR/home`; installer sourced AFTER stubs, `SCRIPT_DIR` = repo checkout.

Test cases (each `run` in subshell):
- [ ] `require_macos` exits non-zero with "macOS" in output when stub uname prints Linux; succeeds on Darwin.
- [ ] `parse_args --help` exits 0 and prints "Usage"; `parse_args --bogus` exits 2; `parse_args --unattended` sets `UNATTENDED=1`.
- [ ] `backup_zshrc`: creates `~/.zshrc-backup-*` when a foreign `.zshrc` exists; does nothing when `.zshrc` contains `ftazsh-managed`; does nothing when no `.zshrc`.
- [ ] `create_directories`: creates `$FTAZSH_HOME`, `$FTAZSH_HOME/zshrc`, `~/.cache/zsh`; migrates a pre-seeded `~/.zcompdump-x` into `~/.cache/zsh/`; runs cleanly with no `.zcompdump*` present.
- [ ] `install_omz` + `install_plugin_repos` with `FTAZSH_OMZ_REPO`/`FTAZSH_PLUGIN_BASE_URL` pointing at local `file://` fixture repos (built by helper `make_fixture_repo <dir> <name>` using real `git init/commit`): fresh clone creates dirs; second run updates without error; a legacy `$FTAZSH_HOME/oh-my-zsh/plugins/zsh-autosuggestions` dir is deleted (migration).
- [ ] `copy_config_files`: installs `~/.zshrc` (marker present), `ftazshrc.zsh tools.zsh p10k.zsh` into `$FTAZSH_HOME`, `personal_rc.zsh` into `$FTAZSH_HOME/zshrc/` only when absent — pre-seeded edited copy survives byte-identical.
- [ ] `install_brew_formulae` with stub brew: `brew list --formula` reports `git jq` installed → `brew install` called only for the other six; `BREW_FAIL_ON=eza` → function returns non-zero and names eza.
- [ ] `ensure_default_shell`: dscl reports `/bin/zsh` → no `chsh` in stub log; dscl reports `/bin/bash` + `UNATTENDED=1` → no chsh, prints hint; `/bin/bash` attended → chsh logged.
- [ ] Verify red: `bats tests/unit` fails with "command not found" style errors (install.sh not yet rewritten).
- [ ] Commit: `test: unit tests for installer functions (red)`

### Task 3: Rewrite install.sh (green)

**Files:**
- Rewrite: `install.sh`

**Interfaces:**
- Produces every function/global from Task 2's contract. `main` order: `require_macos → parse_args → ensure_homebrew → install_brew_formulae → install_brew_casks → backup_zshrc → create_directories → install_omz → install_plugin_repos → copy_config_files → ensure_default_shell → summary`. `set -euo pipefail` + ERR trap printing the failing command. Logging helpers `info/ok/warn/err` (emoji style retained). No trailing `exit 0`.

- [ ] Implement; run `bats tests/unit` until green.
- [ ] Run `shellcheck install.sh` clean.
- [ ] Commit: `feat: macOS-only Homebrew-native installer, testable and idempotent`

### Task 4: Rework zsh configs

**Files:**
- Rewrite: `.zshrc` (orchestrator: instant prompt → ftazshrc.zsh → p10k.zsh → `zshrc/*` user files → oh-my-zsh → tools.zsh; marker line first)
- Rewrite: `ftazshrc.zsh` (pre-OMZ: `$ZSH`, theme, plugins per Global Constraints list `macos brew git python pip docker extract sudo zsh-autosuggestions zsh-syntax-highlighting history-substring-search`, `fpath+=` zsh-completions/src, `HISTSIZE/SAVEHIST=50000`, `ZSH_COMPDUMP` under `~/.cache/zsh`, PATH `~/.local/bin`; NO `TERM` export, NO systemd/z, NO npm cruft)
- Create: `tools.zsh` (post-OMZ: `l/a/aa/e` aliases, `myip` via curl, `cheat/speedtest/dadjoke/ipgeo` functions, `FZF_DEFAULT_OPTS`, fd-based `FZF_DEFAULT_COMMAND`, bat preview + MANPAGER, `source <(fzf --zsh)` guarded, `zoxide init` guarded)
- Rewrite: `personal_rc.zsh` (trimmed example; no `extract` duplicate, no `ls` override)

- [ ] Implement all four; every integration guarded by `command -v`.
- [ ] Verify: `zsh -n .zshrc ftazshrc.zsh tools.zsh personal_rc.zsh` all pass (via `make lint`).
- [ ] Commit: `feat: two-phase zsh config with modern tools wired in`

### Task 5: Integration test — real zsh boot (Docker)

**Files:**
- Create: `tests/integration/zsh_boot.sh`

**Interfaces:**
- Consumes installer functions (sourced; skips brew/macOS steps) to build a real layout under a scratch `$HOME`: `create_directories`, `install_omz`, `install_plugin_repos` (network clones), `copy_config_files`.
- Runs `zsh -i -c '<assert>'` with `HOME=$SCRATCH`, `POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true`, `POWERLEVEL9K_INSTANT_PROMPT=off`, `POWERLEVEL9K_DISABLE_GITSTATUS=true`.

Assertions (each a numbered check with clear pass/fail output; script exits non-zero on first failure):
- [ ] Interactive boot writes nothing to stderr.
- [ ] `alias l`, `alias e` defined; `alias a` defined iff eza present (present in image).
- [ ] `whence -w cheat dadjoke ipgeo` are functions; `alias myip` uses curl.
- [ ] `$plugins` contains `zsh-autosuggestions zsh-syntax-highlighting history-substring-search`; widget `history-substring-search-up` exists; function `_zsh_highlight` exists; `_zsh_autosuggest_start` exists.
- [ ] `$fpath` contains `custom/plugins/zsh-completions/src`.
- [ ] `FZF_DEFAULT_OPTS` non-empty; `FZF_DEFAULT_OPS` NOT set.
- [ ] zoxide active: `whence -w z` is a function (image has zoxide).
- [ ] User override contract: write `$SCRATCH/.config/ftazsh/zshrc/99-user.zsh` with `alias usertest='echo ok'` and `plugins+=(encode64)`; re-boot; both `alias usertest` and `whence -w encode64` succeed.
- [ ] Degradation: image has no bat/fd — boot stays clean (covered by stderr check) and MANPAGER unset.
- [ ] Verify: `make docker-test` green end-to-end.
- [ ] Commit: `test: Docker integration test boots real zsh against installed layout`

### Task 6: uninstall.sh + unit tests

**Files:**
- Create: `uninstall.sh`; Create: `tests/unit/uninstall.bats`

**Interfaces:**
- Functions: `restore_zshrc` (newest backup by mtime → `~/.zshrc`; if none and current is managed → remove `~/.zshrc`; foreign `.zshrc` untouched), `remove_ftazsh_home` (rm -rf `$FTAZSH_HOME`), `parse_args` (`--yes/-y` skips confirm, `--help`), `main` (confirm unless `--yes`; prints brew uninstall hints, never runs brew).

- [ ] Write bats tests first (restore newest of two backups; managed-no-backup removal; foreign `.zshrc` untouched; `--yes` non-interactive) → red.
- [ ] Implement `uninstall.sh` → green; shellcheck clean.
- [ ] Commit: `feat: uninstaller with backup restore and tests`

### Task 7: README rewrite + iTerm profile font fix

**Files:**
- Rewrite: `README.md` (macOS-only; actual layout; tool table; customization contract; testing section `make docker-test`; uninstall; "removed features" note: Linux, marker, k, bash-history migration)
- Modify: `iterm2-profile.json` — `"Normal Font"` → `"JetBrainsMonoNF-ExtraBold 14"` (Nerd Fonts v3 postscript name; verify exact name against the installed cask in CI/macOS notes)

- [ ] Implement both; `python3 -c 'import json;json.load(open("iterm2-profile.json"))'` passes.
- [ ] Commit: `docs: rewrite README for macOS-only scope; fix iTerm profile font name`

### Task 8: CI workflow + full verification

**Files:**
- Create: `.github/workflows/ci.yml` — job `linux`: ubuntu-latest, apt-installs test deps, `make lint unit integration`; job `macos`: macos-latest, `./install.sh --unattended`, then assert `command -v eza bat fd rg fzf zoxide jq`, `grep ftazsh-managed ~/.zshrc`, `zsh -i -c exit` clean.

- [ ] Write workflow; validate YAML (`python3 -c 'import yaml,sys;yaml.safe_load(open("ci.yml"))'` or equivalent).
- [ ] Run `make docker-test` one final time from clean checkout state; run host-safe checks (`shellcheck`, `zsh -n`).
- [ ] Commit: `ci: lint+unit+integration on Linux, real install on macOS`

## Self-Review

- Spec coverage: installer (T3), configs (T4), tools+fonts (T3/T4), tests (T1/T2/T5/T6), CI (T8), uninstaller (T6), README/profile (T7) — all spec sections mapped.
- Placeholders: none; interface contracts are exact (names, lists, marker string, env overrides).
- Type consistency: function names in T2 match T3's contract; assertion names in T5 match T4's outputs (`tools.zsh` guards, plugin list, fpath path).
