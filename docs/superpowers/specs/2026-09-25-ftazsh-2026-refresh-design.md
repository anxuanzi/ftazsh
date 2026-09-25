# ftazsh September 2026 Refresh — Design

**Date:** 2026-09-25
**Status:** Implemented on branch `tonyan/wonderful-ramanujan-ngdyyh`.
**Directive:** keep the macOS zsh environment current with the September 2026
ecosystem (latest macOS, Homebrew, modern unix tools), make the latest git the
default git with reftable support in the git integration, add self-update,
and make install/uninstall clean and complete — with a way to test everything
on the maintainer's own Mac.

## Facts this design is based on (verified 2026-09-25)

| Area | Fact | Source |
|---|---|---|
| macOS | macOS 27 "Golden Gate" released 2026-09-14, Apple Silicon only; macOS 26 Tahoe is the last Intel release | MacRumors / Wikipedia |
| Homebrew | 5.0.0 (Nov 2025): download concurrency, Tahoe support; 6.0.0 (Jun 2026): tap trust, internal JSON API default, **ask mode default for developers**; 7.0.0 (Sep 2026): macOS 27 Tier 1, **Intel macOS Tier 3 (no new bottles)**, ask mode default (`HOMEBREW_NO_ASK` disables), `brew shellenv` sets PATH directly, `brew vulns` advisory only | brew.sh blog, Manpage |
| Homebrew fonts | `font-jetbrains-mono-nerd-font` / `font-hack-nerd-font` 3.5.1, install into `~/Library/Fonts` | formulae.brew.sh API |
| Git | 2.55.0 (2026-06-29) is current; 2.56-rc0 2026-09-11; **Git 3.0** (late 2026) defaults: SHA-256, **reftable**, `main`, `safe.bareRepository=explicit`, Rust required | git-scm.com BreakingChanges, GitHub/GitLab blogs |
| Reftable | `git init --ref-format=reftable` since 2.45; `git refs migrate --ref-format=reftable` since 2.46 (keeps reflogs; not with linked worktrees); `MERGE_HEAD` stays a file, `CHERRY_PICK_HEAD`/`REVERT_HEAD` live in the ref store | git-refs docs, verified locally with git 2.55 |
| libgit2 | cannot open reftable repositories (backend in development) | libgit2#5352 |
| Powerlevel10k | gitstatusd (libgit2-based) shows branch `.invalid` in reftable repos; issue open since 2026-03-30; p10k is in maintenance mode | romkatv/powerlevel10k#2941 |
| Tools | every formula added has an `arm64_golden_gate` bottle and no heavy runtime deps (git-delta: libgit2, oniguruma) | formulae.brew.sh API |
| GitHub Actions | `macos-latest` = macOS 26 arm64 since July 2026 | actions/runner-images#14167 |
| zsh | 5.9.x remains current (5.9.2 in Homebrew); macOS ships 5.9 | zsh.sourceforge.io |

## Goals

1. **Current tool set** — add the modern unix tools that have become standard
   (delta, difftastic, lazygit, gh, dust, duf, procs, btop, sd, hyperfine,
   tealdeer, yazi), wire them in, keep graceful degradation.
2. **Latest macOS + Homebrew** — survive Homebrew 6/7 ask mode, Intel Tier 3,
   macOS 27; fonts verified by file presence, not only by `brew list`.
3. **Latest git as *the* git, reftable-ready** — Homebrew git first on PATH in
   every ftazsh shell; managed git defaults; prompt correct in reftable repos;
   reftable helpers.
4. **Self-update** — `ftazsh update` + background check with prompt / auto /
   reminder / disabled modes.
5. **Complete uninstall and clean reinstall** — including git config, caches,
   optional tools, personal-config backup; `ftazsh reinstall`.
6. **Testable without a Mac, and on a Mac** — Linux suite in Docker/CI, real
   macOS CI job, and `make mac-test` sandboxed run with cleanup.

## Decisions

### Tool set

`git eza bat fd ripgrep fzf zoxide jq git-delta difftastic lazygit gh dust
duf procs btop sd hyperfine tealdeer yazi` (Homebrew formulae) plus the two
Nerd Font casks. Chosen for adoption, maintenance and bottle availability on
macOS 26/27. Classic commands (`du`, `ps`, `top`, `sed`) are **not** aliased
to their replacements — scripts and muscle memory keep working; the new tools
are used by their own names. Shell wiring only where it adds value (`lg`,
`y`, `tree`, fzf previews, delta/difftastic through git config).

### Homebrew hardening

`HOMEBREW_NO_ASK=1`, `HOMEBREW_NO_ENV_HINTS=1`, `HOMEBREW_NO_AUTO_UPDATE=1`
exported by the installer, with one explicit `brew update` per run (so new
formulae are known without auto-updating 20 times). Casks are reinstalled when
`brew list` reports them but the font files are gone. `--upgrade` (used by
`ftazsh update`) upgrades only *outdated managed* formulae/casks. Intel Macs
get a one-line Tier-3 warning.

### git as the default git

`ftazshrc.zsh` evaluates `brew shellenv` if needed and then forces
`$HOMEBREW_PREFIX/bin` and `sbin` to the front of `path` (deduplicated with
`typeset -U`), so `git` resolves to Homebrew's in login and non-login
interactive shells alike. Homebrew's `site-functions` are **appended** to
`fpath` before compinit (completions for every brewed tool) — appended rather
than prepended so zsh's own `_git`, which oh-my-zsh's git aliases build on,
keeps precedence over git's bundled completion script. `ftazsh doctor` checks
the resolved path and version (≥ 2.45).

### Managed git defaults via an include *at the top* of the global config

`~/.config/ftazsh/gitconfig` holds the defaults. The installer prepends

```
# ftazsh-managed: …
[include]
	path = /Users/you/.config/ftazsh/gitconfig
```

to `~/.gitconfig` (or `$XDG_CONFIG_HOME/git/config` when only that exists).
Because git applies later values over earlier ones, everything the user sets
overrides ftazsh. `git config --global include.path` would *append* and
invert that precedence, which is why the file is edited directly (atomic
temp-file + rename, mode preserved). Uninstall removes exactly that block
(`git config --unset-all --fixed-value` + cleanup of the marker and an empty
`[include]` header). The pager is `bin/ftazsh-pager` (delta if present,
otherwise `less`/`cat`) so git never breaks if delta disappears.
`credential.helper = osxkeychain` restores Keychain credentials, which
Homebrew's git loses because it does not read Apple's system gitconfig.
`init.defaultRefFormat` is deliberately **not** set — GUIs on libgit2 can't
open reftable repos yet; `ftazsh reftable on` opts in.

### Reftable-safe Powerlevel10k prompt

Alternatives considered:

* *Disable gitstatusd* (`POWERLEVEL9K_DISABLE_GITSTATUS`) → vcs_info
  everywhere: correct but slow, loses async, regresses every classic repo.
* *Custom segment replacing `vcs`*: p10k only starts gitstatusd when a segment
  named `vcs` is in use, so a renamed segment loses gitstatusd entirely.
* *Wrap `gitstatus_query_p9k_`*: the async state machine expects `tout` +
  callback; faking a sync answer leaves p10k waiting forever.
* **Chosen — prefix `_p9k_vcs_status_save` and `_p9k_vcs_render`.** Both the
  sync and async paths pass through these two functions right after
  gitstatusd's (wrong) answer arrives. `git.zsh` prepends one line to each:
  `_ftazsh_vcs_fixup`, which (a) returns immediately unless
  `VCS_STATUS_RESULT` is `ok-*`/`norepo-*`, (b) locates the git dir with pure
  zsh (handles worktrees, submodules, bare repos, `$GIT_DIR`), (c) checks
  `reftable/tables.list` in the common dir, and only then (d) recomputes every
  `VCS_STATUS_*` variable from `git status --porcelain=v2 --branch
  --show-stash` (+ `cat-file --batch-check` for the reftable-stored
  `CHERRY_PICK_HEAD`/`REVERT_HEAD`, `describe` when detached, `log -1` for
  the summary), memoized so the save/render pair costs one scan. The render
  prefix skips the fixup while a query is in flight (p10k re-renders from its
  cache, which already holds fixed values). p10k's async machinery, caching,
  styling and the user's `my_git_formatter` are untouched; `p10k reload`
  keeps functions, and `_p9k_deinit` only unsets `_p9k_*` variables (ours are
  `_ftazsh_*`). Large repos (index > 16 MB, `FTAZSH_VCS_MAX_INDEX_BYTES`) use
  `for-each-ref` only and report dirty state as unknown. `FTAZSH_P10K_SHIM`
  exposes success; `ftazsh doctor` reports it. Verified in the integration
  test with the real gitstatusd running (Linux binary fetched by p10k).

### Self-update

* `install.sh` keeps `~/.config/ftazsh/repo`: a clone of whatever checkout
  the installer ran from, with `origin` set to the upstream URL (override:
  `FTAZSH_REPO_URL`) and the tracked branch in `git config ftazsh.branch`
  (`FTAZSH_REPO_BRANCH`). Running from the managed clone itself only refreshes
  that metadata. Without any git checkout (zip / `curl | bash`) it clones the
  upstream; `curl | bash` bootstraps by cloning and re-executing.
* `ftazsh update`: `git fetch origin <branch>`, `checkout -B <branch>
  FETCH_HEAD`, then `install.sh --unattended [--upgrade]` from the clone.
  `--check` only reports (exit 0/1/2); `--background` is the silent variant
  the startup hook uses. State lives in `~/.config/ftazsh/state/`
  (`update-check` with `last=`/`next=` epochs, `update-available`,
  `update-snooze`).
* `update.zsh` runs at the very top of `~/.zshrc`, *before* the p10k instant
  prompt, because it may print or ask. It never fetches in the foreground: a
  detached background job runs the check when due (claiming the slot first so
  parallel shells don't all fetch); results are acted on at the next start.
  Modes: `prompt` (15 s timeout; `n` snoozes an interval; timeout snoozes a
  day), `auto`, `reminder`, `disabled`. Settings come from
  `settings.zsh`, sourced first; `FTAZSH_UPDATING=1` (exported by the CLI and
  by the tests) silences the hook in shells ftazsh's own scripts start.
* Managed files are installed with temp-file + `mv` so a running `ftazsh`
  keeps reading its old inode while being replaced.

### Uninstall / reinstall

`uninstall.sh` sources `install.sh` for the tool list and git helpers. Always:
restore `.zshrc`, remove the git include, back up `zshrc/` to
`~/.zshrc-backup-<ts>-ftazsh-personal`, remove `~/.config/ftazsh`, remove
compdumps / p10k / gitstatus caches. `--tools` brew-uninstalls installed
managed formulae and casks (git included, on purpose); `--purge` adds bat /
tealdeer caches. Never: Homebrew, `~/.zprofile`, `.zshrc` backups, zoxide db.
`ftazsh reinstall` stages a copy of the clone (fetching the latest when
online), runs its `uninstall.sh --yes`, then its `install.sh`. `backup_zshrc`
skips backups identical to the newest one, so uninstall/reinstall cycles don't
pile up copies.

### Testing

* **Unit (bats, 70 tests):** installer, uninstaller and CLI with stubbed
  `uname`/`brew`/`chsh`/`dscl`; local `file://` fixtures for oh-my-zsh,
  plugins, p10k and an "upstream" ftazsh that snapshots the working tree.
  Includes a full `main --unattended` run and the `update`/`reinstall`/
  `reftable migrate` flows.
* **Integration (Linux/macOS, 47 checks):** real clones, real zsh boots,
  `zpty`-based prompt rendering (`tests/lib/render-prompt.zsh`) for reftable
  and classic repos with gitstatusd when fetchable, collector unit checks
  (detached, staged, stash, merge, cherry-pick), the update flow with the
  startup reminder, uninstall.
* **CI:** Linux job (lint/unit/integration; runner git ≥ 2.45), a macOS job
  (real install, tools, Homebrew git default, boot, git include + pager,
  doctor, reftable prompt render, update flow against a local upstream
  branch, idempotent re-install, uninstall) and a second macOS job that runs
  the sandboxed smoke test below on the runner. `workflow_dispatch` allows
  on-demand runs. Docker image installs git from the git-core PPA for the
  reftable checks.
* **On the maintainer's Mac:** `tests/macos/smoke.sh` (`make mac-test`) —
  sandboxed `HOME`, real Homebrew (with `HOMEBREW_CASK_OPTS=--fontdir` and
  `HOMEBREW_CACHE` pointed at the real locations), records pre-existing
  formulae/casks and removes only what it installed, verifies everything the
  CI does plus the real-gitstatusd reftable prompt and `reftable migrate`,
  then uninstalls and checks the sandbox is clean.

## Out of scope

Switching prompt engines (Starship), replacing oh-my-zsh, enabling reftable
or SHA-256 by default, git fsmonitor (opt-in, spawns daemons), atuin (would
replace fzf's Ctrl-R), Linux support.

## Risks and mitigations

* p10k internals change → shim installs only if both functions exist; doctor
  reports `FTAZSH_P10K_SHIM=0`; prompt degrades to upstream behaviour.
* `git status` cost in huge reftable repos → index-size guard.
* Update check on flaky networks → background only, low-speed timeouts,
  retry in an hour, never blocks a shell.
* Homebrew removing `brew list --formula/--cask` semantics → CI macOS job
  runs the real thing on `macos-latest` on every PR.
