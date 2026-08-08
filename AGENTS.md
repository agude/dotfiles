# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Overview

Personal dotfiles repository for managing shell configurations (Bash and Zsh),
Vim/Neovim setup, and development tool configurations across Unix-like systems.
Uses symbolic linking to install configurations from this centralized location
to the user's home directory.

## Shell Compatibility

`install.sh` must run under **Bash 3.2** (the macOS system default). Do not
use Bash 4+ features including:
- Associative arrays (`declare -A`)
- Namerefs (`declare -n`, `local -n`)
- `|&` (pipe stderr), `&>>` (append stdout+stderr)
- `readarray` / `mapfile`
- `${var,,}` / `${var^^}` case modification
- `coproc`

## Installation

```bash
./install.sh                   # default profile
./install.sh --profile work    # work profile
./install.sh --dry-run         # preview changes
./install.sh --show            # show active profile and enabled groups
```

The installer:
- Reads `links.conf` for declarative symlink definitions
- Sources the active profile (`profiles/*.sh`) for group/variable overrides
- Creates symlinks from `~/.dotfiles/` to appropriate locations in `$HOME`
- Links custom scripts from `bin/` to `~/bin/` (extensions stripped)
- Installs Vim/Neovim plugins using vim-plug
- Cleans up stale symlinks from previous runs

### Profile System

Profiles control which install groups are enabled and override config-file
paths (e.g., work-specific Claude settings).

- `profiles/default.sh` — base profile; defines all groups and variables
- `profiles/work.sh` — overlays work-specific LLM settings
- `profiles/server.sh`, `profiles/synology.sh`, `profiles/root.sh` — minimal
  environments
- `.active-profile` — persists the chosen profile between runs

### Link Manifest (`links.conf`)

Declarative symlink definitions. Format: `target | source | groups`. Variables
like `${HOME}` and profile-defined variables are expanded at runtime.
Procedural tasks (plugin install, glob loops) stay in `install.sh`.

## Architecture

### Modular Configuration System

Numbered configuration files sourced in order by both Bash and Zsh:

1. **Shared** (`shared/sharedrc.d/*.sh`): Shell-agnostic, sourced by both
2. **Bash-specific** (`bash/bashrc.d/*.bash`)
3. **Zsh-specific** (`zsh/zshrc.d/*.zsh`)

Numbering convention:
- `000-099`: Core environment (platform detection, XDG directories, PATH)
- `100-199`: User interface (aliases, prompts, history)
- `200+`: Language/tool-specific (Rust, nvm, opencode)

### Key Architecture Principles

1. **XDG Base Directory Compliance**: Respects `$XDG_CONFIG_HOME` and
   `$XDG_CACHE_HOME`
2. **Cross-shell Compatibility**: Common functionality in `shared/sharedrc.d/`
3. **Vim/Neovim Unification**: Both editors share config through symlinks
4. **Platform Detection**: `000.set_platform.sh` sets `$PLATFORM` early
5. **PATH Deduplication**: Zsh uses `typeset -U path`; bash guards each
   insertion with `[[ ":$PATH:" != *":$dir:"* ]]`

## Important Files and Locations

### Shell Configuration Entry Points
- `bash/bashrc` — main Bash config, symlinked to `~/.bashrc`, `~/.bash_profile`,
  `~/.bash_login`
- `zsh/zshrc` — main Zsh config, symlinked to `~/.zshrc`
- `bash/bashrc.profiler` — optional startup profiler

### Vim Configuration

**Main files:**
- `vim/vimrc` — main Vim configuration
- `vim/plug.vim` — vim-plug plugin manager and plugin-specific settings
- `vim/ideavimrc` — IntelliJ IDEA Vim emulation config
- Uses Space as leader key and backslash as local leader

**Directory structure:**
- `vim/plugin/` — auto-loaded plugin files (global functions)
- `vim/autoload/` — lazy-loaded functions
- `vim/after/ftplugin/` — filetype-specific settings
- `vim/after/syntax/` — syntax overrides
- `vim/ftdetect/` — filetype detection scripts
- `vim/plugged/` — plugin install directory (managed by vim-plug)

**XDG compliance:**
All cache files use `g:VIM_CACHE_DIR` (`$XDG_CACHE_HOME/vim/`):
backups, swap, undo files. Spell file stays at `~/.vim/spell/en.utf-8.add`.

### Git Configuration
- `config/git/config` — aliases and defaults
- Notable: `merge.ff = only`, `pull.rebase = true`,
  `merge.conflictstyle = zdiff3`
- Aliases: `lg` (graph log), `up` (pull+rebase+submodules), `bclean` (delete
  merged branches), `fpush` (force-with-lease)

### LLM Tool Configurations

All LLM configs live under `llm/`:

#### Shared Agent Context
- `llm/AGENTS.md` — shared instructions (commit style, tone) for all LLM agents
- Symlinked to `~/.claude/CLAUDE.md` and `~/.gemini/GEMINI.md`

#### Claude Code
- `llm/claude/settings.json` — user-level settings synced across machines
- `llm/claude/settings.work.json` — work profile override
- `llm/claude/statusline-command.sh` — status line script (username, cwd, git
  state, context usage). Wired via `statusLine` key in settings files.
- `llm/claude/hooks.d/PreToolUse/` — coat-tree hooks:
  - `010.git-guard.sh` — blocks hook/signing bypass flags
  - `020.git-push-guard.sh` — blocks force push and push to main
  - `030.gh-guard.sh` — gates GitHub CLI operations by risk level

`~/.claude/` is a real directory; only specific files are symlinked. This
allows external commands, skills, and settings (work-specific, machine-local)
to coexist. Runtime files stay in `~/.claude/` untracked.

#### Gemini CLI
- `llm/gemini/settings.json` — user-level settings
- `~/.gemini/` follows the same selective-symlink pattern as `~/.claude/`

#### Agent Skills
- `llm/skills/` — shared [Agent Skills](https://agentskills.io) symlinked to
  `~/.claude/skills/`
- Each skill is a folder with `SKILL.md` plus optional `scripts/`,
  `references/`, `assets/`
- See `llm/skills/README.md` for the specification

### Other Configurations
- `config/ghostty/config.ghostty` — Ghostty terminal config
- `config/readline/inputrc` — Readline config
- `config/screen/screenrc` — GNU Screen config
- `config/systemd/` — systemd user services
- `config/launchd/` — macOS launchd plists

### Custom Scripts (`bin/`)
Scripts symlinked to `~/bin/` without file extensions:
- `crush.py` — PNG compression (parallel pngout wrapper)
- `apt-full.sh` — apt update/upgrade wrapper
- `empty-downloads.sh` — safely empties Downloads
- `rmspace.sh` — renames files replacing spaces with underscores
- `jd.sh` — Johnny.Decimal directory navigation helper
- `pre-commit.sh` — ShellCheck pre-commit hook

### CI
- `.github/workflows/test.yaml` — ShellCheck lint, skill tests (bats, pytest),
  install test on Ubuntu and macOS (including Bash 3.2), interactive shell
  smoke tests

## Modifying Configurations

### Adding New Shell Configuration

1. Create appropriately numbered file in the correct directory:
   - Shared: `shared/sharedrc.d/NNN.description.sh`
   - Bash: `bash/bashrc.d/NNN.description.bash`
   - Zsh: `zsh/zshrc.d/NNN.description.zsh`
2. Use existing numbering conventions for placement
3. No need to modify main `bashrc` or `zshrc` — files are auto-sourced

### Adding Vim Plugins

Managed with vim-plug in `vim/plug.vim`. Install location: `vim/plugged/`.

### Adding Agent Skills

1. Create `llm/skills/<name>/SKILL.md` with required frontmatter
2. Optionally add `scripts/`, `references/`, `assets/`
3. Skills are available after re-running `./install.sh`

See `llm/skills/README.md` for the specification.

### Adding Symlinks

Add a line to `links.conf` for simple symlinks. Use `install.sh` directly for
procedural tasks (glob loops, conditional logic).

### Local Overrides

- Shell aliases: `~/.localaliases` (not tracked)
- Git config: `~/.gitconfig_local` (auto-included)
- Claude Code: `~/.claude/settings.local.json` (git-ignored)

## Common Patterns

### Path Management
- User scripts go in `~/bin/` (on PATH via shell configs)
- Both shells prevent PATH duplicates on reload

### File Permissions
- Default umask is `077` (files readable only by owner)
- GNUPGHOME created with explicit `0700` permissions

## Installer Safety

**Never `rm -rf` unknown state — always back up.** `_place_link()` holds the
validate/backup/replace/symlink logic; `link()` is a thin wrapper prepending
`DOTFILES_DIR`, and `ext_link()` takes absolute source paths plus an ownership
prefix, for links into repos outside dotfiles (Knowledge, Wiki).

| Situation | Action |
|---|---|
| Symlink already points at the correct target | Skip silently |
| Symlink points into `$DOTFILES_DIR` but wrong target | Replace |
| Real file/dir, or a foreign symlink | Back up to `*.dotfiles-backup.<epoch>` |
| Source file missing from the repo | Warn, skip, do not add to the manifest |

Backups are epoch-timestamped so a re-run cannot clobber a previous one. The
`ext_link` extraction fixed a real bug: a real *directory* at the target used
to hit `rm: Is a directory`. Directories get backed up now.

Cleanup removes a symlink only when `readlink` shows it points into
`$DOTFILES_DIR`, so links owned by other tools are never touched. It runs two
passes: **dangling** (target deleted from the repo) and **unmanaged** (target
exists but was not in `MANAGED_LINKS` this run — catches links left behind by
a profile switch).

## Portability Constraints

- **No `mapfile`.** macOS ships bash 3.2. CI runs `install.sh` under
  `/bin/bash` 3.2 with `--dry-run` and exercises interactive shells.
- **Busybox (Synology DSM) lacks `tput` and `mesg`.** Both must be guarded or
  every SSH login spews errors — `command -v mesg >/dev/null && mesg n`, and
  the `LESS_TERMCAP` block wrapped in
  `if command -v tput >/dev/null && [[ $(tput colors) -ge 8 ]]`. **Do not use
  an early `return` from a sourced file to short-circuit**: shellcheck SC2317
  flags it as unreachable. Use an `if` block.
  (The `-sh: mesg: command not found` line from DSM's own `/etc/profile` is
  out of scope for this repo.)
- **`vim` resolves to nvim on these machines**, so plugin install is
  `if nvim / elif vim`; they share config via symlinks. Headless install is
  `nvim --headless "+PlugInstall --sync" +qa` with stderr suppressed, which
  kills the "Press 'R' to retry" noise. Real vim rejects `-T`.

## Deliberate — Do Not "Fix"

Things that look like bugs and are not:

- **The bare `claude` command is pinned to a specific model on purpose.**
  `opus` / `sonnet` / `fable` aliases exist for overrides.
- **The broad `.*` rule in `.gitignore` stays** until it actually bites.
- **There are two different agent docs, and reviewers conflate them.** This
  file (repo root, with `CLAUDE.md` as a symlink to it) documents *this repo*.
  `llm/AGENTS.md` is a short cross-project commit-style and tone document,
  symlinked to `~/.claude/CLAUDE.md` and `~/.gemini/GEMINI.md`. Intentionally
  separate documents.

**Known limitation:** `010.git-guard.sh` string-matches the full command, so
blocked-flag text appearing inside a commit message or heredoc triggers it. A
proper fix needs shell-aware parsing.
