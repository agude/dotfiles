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
just install                   # default profile
just install --profile work    # work profile
just install --dry-run         # preview changes
just install --show            # show active profile and enabled groups
just bootstrap                 # install + editor plugins
```

On a fresh machine without `just`, run `./install.sh` directly.

The installer:
- Reads `links.conf` for declarative symlink definitions
- Sources the active profile (`profiles/*.sh`) for group/variable overrides
- Creates symlinks from `~/.dotfiles/` to appropriate locations in `$HOME`
- Links custom scripts from `bin/` to `~/bin/` (extensions stripped)
- Initializes mutable application directories without contacting the network
- Leaves Vim/Neovim plugin installation to `bootstrap-vim-plugins`
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
Procedural tasks (directory initialization, glob loops) stay in `install.sh`.

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
- Symlinked to `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`,
  and `~/.pi/agent/AGENTS.md`

#### Claude Code
- `llm/claude/settings.json` — user-level settings synced across machines
- `llm/claude/settings.work.json` — work profile override
- `llm/claude/statusline-command.sh` — status line script (username, cwd, git
  state, context usage). Wired via `statusLine` key in settings files.
- `llm/claude/hooks.d/` — coat-tree hooks (one subdirectory per event):
  - `PreToolUse/010.git-guard.sh` — blocks hook/signing bypass flags
  - `PreToolUse/020.git-push-guard.sh` — blocks force push and push to main
  - `PreToolUse/030.gh-guard.sh` — gates GitHub CLI operations by risk level
  - `SessionStart/010.knowledge.sh` — initializes KB session capture, injects context
  - `UserPromptSubmit/010.knowledge.sh` — appends user prompts to session buffer
  - `Stop/010.knowledge.sh` — appends assistant responses to session buffer
  - `SessionEnd/010.knowledge.sh` — flushes session buffer into KB observation

`~/.claude/` is a real directory; only specific files are symlinked. This
allows external commands, skills, and settings (work-specific, machine-local)
to coexist. Runtime files stay in `~/.claude/` untracked.

#### Codex CLI
- `llm/codex/agude.config.toml` — portable template for the `agude` profile
- `llm/codex/hooks.json` — hook definitions for KB session capture
- `llm/codex/hooks.d/` — session hook shims (same core API as Claude, JSON protocol)
- `~/.codex/agude.config.toml` is a real mutable file, created from the template
  only when absent. Codex writes project trust and hook state into this file.
- `~/.codex/config.toml` is **not** symlinked — Codex owns it for machine-local
  global settings. The `codex` alias injects `--profile agude`.

#### Johnny.Decimal
- `llm/johnnydecimal/config.json` — portable configuration template
- `${XDG_CONFIG_HOME}/johnnydecimal/config.json` — mutable local configuration,
  initialized once by `install.sh`

#### OpenCode
- `llm/opencode/opencode.json` — global config (providers, models)
- `llm/opencode/plugin/knowledge.ts` — TypeScript plugin for KB session capture
- `~/.config/opencode/AGENTS.md` is symlinked to `llm/AGENTS.md` as the global
  instruction file.
- `~/.config/opencode/opencode.json` follows the XDG layout and is symlinked
  from the repository; the plugin is symlinked into
  `~/.config/opencode/plugin/` (auto-discovered).
- `~/.agents/skills/` is the native cross-harness global skills directory;
  shared skills are linked there by the installer.
- Capture defaults to on; `KNOWLEDGE_OBSERVE=0 opencode` opts out. The plugin
  is the single gate — there is deliberately no shell wrapper setting the
  variable, so launches that skip `sharedrc.d` still capture.
- Subagents are child sessions (`parentID` set) and are deliberately not
  captured, matching the Claude rule of one transcript per conversation.
- **Permission keys differ in shape.** `read`, `edit`, `glob`, `grep`, `list`,
  `bash`, `task`, `external_directory`, `lsp`, and `skill` accept either a bare
  action or a `{pattern: action}` map. `webfetch`, `websearch`, `todowrite`,
  `question`, and `doom_loop` accept only a bare `allow`/`ask`/`deny` — a
  pattern map there makes OpenCode refuse to start. `just lint-opencode`
  catches it.

#### Pi coding agent
- `llm/pi/settings.json` — template for `~/.pi/agent/settings.json`,
  installed copy-once; Pi owns the file afterwards (trust decisions,
  `/settings` writes)
- `llm/pi/extensions/knowledge.ts` — extension for KB session capture,
  glob-linked into `~/.pi/agent/extensions/` (auto-discovered)
- `~/.pi/agent/AGENTS.md` is symlinked to the shared instructions; Pi also
  reads project `AGENTS.md`/`CLAUDE.md`
- Config dir is hardcoded to `~/.pi/agent` — no XDG support. Keep it
  canonical rather than exporting `PI_CODING_AGENT_DIR`: launches that skip
  `sharedrc.d` would silently fork state into `~/.pi`.
- PATH comes from `shared/sharedrc.d/203.pi.sh`, which follows pi's
  version-agnostic `~/.local/share/pi-node/current` symlink
- Capture gates and semantics match the OpenCode plugin: on unless
  `KNOWLEDGE_OBSERVE=0`; context injection ignores the variable

#### Agent Skills
- `llm/skills/` — shared [Agent Skills](https://agentskills.io) symlinked to
  `~/.claude/skills/` and `~/.agents/skills/`
- `~/.agents/skills/` is the cross-harness location: Codex, Pi, and OpenCode
  discover it natively. Claude Code only reads `~/.claude/skills`, so both
  targets are linked.
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
- `bootstrap-vim-plugins.sh` — explicit vim-plug download and synchronization
- `pre-commit.sh` — delegates repository linting to `just lint`

### CI
- `.github/workflows/test.yaml` — runs justfile recipes for lint, unit tests,
  Bash 3.2 shell tests, and Linux/macOS integration tests (`just test-integration`)
- `just lint-opencode` validates `llm/opencode/opencode.json` with the locally
  installed OpenCode (`opencode debug config --pure`) rather than a vendored
  schema, so it can never drift from the binary in use. It prints a skip line
  and passes when OpenCode is absent, which is the CI case; the pre-commit
  hook is where it actually bites.

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
After changing the plugin list, run `bootstrap-vim-plugins`.

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
- Codex profile: `~/.codex/agude.config.toml` (local mutable state initialized
  from the tracked template)

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
`DOTFILES_DIR`. `ensure_real_dir()` applies the same ownership boundary when a
real parent directory is required.

| Situation | Action |
|---|---|
| Symlink already points at the correct target | Skip silently |
| Symlink points into `$DOTFILES_DIR` but wrong target | Replace |
| Real file/dir, or a foreign symlink | Back up to `*.dotfiles-backup.<epoch>` |
| Source file missing from the repo | Warn, skip, do not add to the manifest |

Backups are epoch-timestamped so a re-run cannot clobber a previous one. Real
directories and foreign parent symlinks are backed up before replacement.

Cleanup removes a symlink only when `readlink` shows it points into
`$DOTFILES_DIR`, so links owned by other tools are never touched. One manifest
diff removes every previously managed link absent from the current run,
including deleted sources and links disabled by a profile switch.

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
- **Vim plugin setup is explicit and network-dependent.** Normal installation
  and editor startup do not download anything. `bootstrap-vim-plugins` chooses
  Neovim first, then Vim, and runs `PlugInstall --sync`.

## Deliberate — Do Not "Fix"

Things that look like bugs and are not:

- **The bare `claude` command is pinned to a specific model on purpose.**
  `opus` / `sonnet` / `fable` aliases exist for overrides.
- **OpenCode's bash permission is allow-by-default on purpose.** `"*": "allow"`
  with an `ask` tier (rm, chmod, chown, git reset --hard, git clean, gh pr
  merge) and a `deny` tier is deliberate, not an oversight. The previous
  ask-by-default allowlist prompted constantly because OpenCode evaluates
  every sub-command of a pipeline separately — `cat x | head` checks `cat x`
  *and* a bare `head`, and `$(id -u)` is checked on its own — so an allowlist
  has to cover bare forms and every pipeline sink. Splitting also means denies
  still fire inside `foo && rm -rf x`.
- **`permission.external_directory` deliberately has no `"*"` key.** Rules are
  last-match-wins, and OpenCode appends automatic allowances for skill
  directories before the user config. A catch-all `"*": "ask"` there overrides
  them and re-prompts for every skill.
- **The broad `.*` rule in `.gitignore` stays** until it actually bites.
- **There are two different agent docs, and reviewers conflate them.** This
  file (repo root, with `CLAUDE.md` as a symlink to it) documents *this repo*.
  `llm/AGENTS.md` is a short cross-project commit-style and tone document,
  symlinked to `~/.claude/CLAUDE.md`. Intentionally
  separate documents.
