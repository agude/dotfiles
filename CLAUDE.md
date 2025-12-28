# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Overview

This is a personal dotfiles repository for managing shell configurations (Bash
and Zsh), Vim/Neovim setup, and various development tool configurations across
Unix-like systems. The repository uses symbolic linking to install
configurations from this centralized location to the user's home directory.

## Installation

Run the installation script to set up all configurations:

```bash
./install.sh
```

This script:
- Creates symlinks from `~/.dotfiles/` to appropriate locations in `$HOME`
- Sets up XDG Base Directory compliant configurations in `$XDG_CONFIG_HOME`
- Links custom scripts from `bin/` to `~/bin/`
- Installs Vim/Neovim plugins using vim-plug
- Links both Bash and Zsh configurations
- Links LLM tool configurations (Claude Code, Gemini CLI) to `~/.claude/` and `~/.gemini/`
- Links shared Agent Skills to `~/.claude/skills/`

## Architecture

### Modular Configuration System

The dotfiles use a **modular, numbered configuration loading system** for both
Bash and Zsh:

1. **Shared configurations** (`shared/sharedrc.d/`): Shell-agnostic `.sh`
   files sourced by both Bash and Zsh
2. **Shell-specific configs**:
   - Bash: `bash/bashrc.d/*.bash`
   - Zsh: `zsh/zshrc.d/*.zsh`

Files are loaded in numerical order (e.g., `000.set_platform.sh`,
`001.xdg_base_directory.sh`, `100.aliases.bash`). The numbering convention
groups related functionality:
- `000-099`: Core environment setup (platform detection, XDG directories)
- `100-199`: User interface (aliases, prompts, history)
- `200+`: Language/tool-specific configurations (Rust, RVM, Neovim)

### Key Architecture Principles

1. **XDG Base Directory Compliance**: Configurations respect
   `$XDG_CONFIG_HOME` (defaults to `~/.config`) and `$XDG_CACHE_HOME`
   (defaults to `~/.cache`)

2. **Cross-shell Compatibility**: Common functionality lives in
   `shared/sharedrc.d/` as `.sh` files, while shell-specific features are in
   their respective directories

3. **Vim/Neovim Unification**: Both editors share the same configuration
   through symlinks. Neovim's config directory points to the `vim/` directory,
   with conditional logic handling differences

4. **Platform Detection**: `000.set_platform.sh` sets `$PLATFORM` variable
   early, allowing subsequent configs to adapt to macOS/Linux differences

## Important Files and Locations

### Shell Configuration Entry Points
- `bash/bashrc`: Main Bash configuration, symlinked to `~/.bashrc`,
  `~/.bash_profile`, and `~/.bash_login`
- `zsh/zshrc`: Main Zsh configuration, symlinked to `~/.zshrc`

### Vim Configuration

**Main files:**
- `vim/vimrc`: Main Vim configuration
- `vim/plugins.vim`: Plugin-specific settings
- `vim/plug.vim`: vim-plug plugin manager
- `vim/ideavimrc`: IntelliJ IDEA Vim emulation config
- Uses Space as leader key (`\<Space>`) and backslash as local leader

**Directory structure:**
- `vim/plugin/`: Auto-loaded plugin files containing global functions
  - `visual_selection_search.vim`: Defines `VSetSearch()` for `*`/`#` in visual mode
  - `preserve.vim`: Defines `Preserve()` to run commands while preserving window state
  - `soft_wrap.vim`: Soft wrapping functionality
- `vim/autoload/`: Auto-loaded functions (lazy-loaded on first use)
  - `spaces.vim`: Functions for stripping trailing whitespace
  - `pythoncomplete.vim`: Python completion helpers
  - `undo_ftplugin.vim`: Undo filetype plugin settings
- `vim/after/`: Files loaded after default runtime files
  - `after/ftplugin/`: Filetype-specific settings (gitcommit, tex, cpp, etc.)
  - `after/syntax/`: Syntax overrides
- `vim/ftdetect/`: Filetype detection scripts (bash, markdown, vimwiki, etc.)
- `vim/plugged/`: Plugin installation directory (managed by vim-plug)

**XDG compliance:**
All cache files use `g:VIM_CACHE_DIR` (`$XDG_CACHE_HOME/vim/`):
- Backups: `$XDG_CACHE_HOME/vim/backup/`
- Swap files: `$XDG_CACHE_HOME/vim/swap/`
- Undo files: `$XDG_CACHE_HOME/vim/undo/`
- Spell file: `~/.vim/spell/en.utf-8.add` (intentionally not in cache as it's user data)

**Key features:**
- Persistent undo with 10,000 levels
- Ripgrep integration for `:grep` if available
- Returns to last cursor position when reopening files
- Very magic mode enabled by default for searches (`/\v`)
- Custom mappings: `H`/`L` for line start/end, `Y` for yank to EOL, `U` for redo

### Git Configuration
- `config/git/config`: Git configuration with aliases and sensible defaults
- Notable aliases: `lg` (pretty log graph), `up` (pull + rebase + update
  submodules), `bclean` (delete merged branches)
- Merge strategy: fast-forward only (`merge.ff = only`)
- Pull strategy: rebase by default

### LLM Tool Configurations

All LLM tool configurations are organized under the `llm/` directory:

#### Claude Code Configuration
- `llm/claude/settings.json`: User-level settings synced across machines
- `llm/claude/commands/`: Custom slash commands (`.md` files)
- `llm/claude/CLAUDE.md`: Project-level context file
- `~/.claude/` is a real directory; only specific files are symlinked:
  - `~/.claude/settings.json` → `llm/claude/settings.json`
  - `~/.claude/commands/` → `llm/claude/commands/`
  - `~/.claude/CLAUDE.md` → `llm/claude/CLAUDE.md`
  - `~/.claude/skills/` → `llm/skills/` (shared Agent Skills)
- Runtime files (history, debug, session-env, etc.) stay in `~/.claude/` and
  are not tracked

**Note:** Claude Code currently doesn't follow XDG Base Directory specification
and hardcodes `~/.claude/`. When Anthropic adds XDG support, this can be
refactored to use `$XDG_CONFIG_HOME`. API keys and personal preferences should
go in `~/.claude/settings.local.json` (automatically git-ignored).

#### Gemini CLI Configuration
- `llm/gemini/settings.json`: User-level settings synced across machines
- `~/.gemini/` is a real directory; only specific files are symlinked:
  - `~/.gemini/settings.json` → `llm/gemini/settings.json`
- Runtime files (sessions, tmp, shell_history, etc.) stay in `~/.gemini/` and
  are not tracked

**Key settings:**
- Auto-approves read-only operations (matching Claude Code's security model)
- Uses `GEMINI.md` as context file (similar to Claude's `CLAUDE.md`)
- Enabled tools: smart edit, todo tracking, ripgrep integration
- Security: Destructive operations require explicit confirmation

**Note:** Gemini CLI uses `~/.gemini/` for user settings (not fully XDG
compliant). API keys and personal preferences should go in
`~/.gemini/settings.local.json` or environment variables (see Gemini docs).

#### Agent Skills
- `llm/skills/`: Shared [Agent Skills](https://agentskills.io) available across
  multiple LLM tools
- Symlinked to `~/.claude/skills/` for use by Claude Code and Goose
- Each skill is a folder containing `SKILL.md` with optional `scripts/`,
  `references/`, and `assets/` directories
- See `llm/skills/README.md` for details on creating and using skills

### Custom Scripts (bin/)
Scripts are symlinked to `~/bin/` without file extensions:
- `sync.py`: File synchronization utility
- `crush.py`: File compression tool
- `makepy.sh`: Python script template generator
- `apt-full.sh`: Apt update/upgrade wrapper
- `rmspace.sh`: Whitespace removal utility
- `tnice.sh`: Process priority wrapper

## Modifying Configurations

### Adding New Shell Configuration

1. Create appropriately numbered file in the correct directory:
   - Shared: `shared/sharedrc.d/NNN.description.sh`
   - Bash: `bash/bashrc.d/NNN.description.bash`
   - Zsh: `zsh/zshrc.d/NNN.description.zsh`

2. Use existing numbering conventions for placement

3. No need to modify main `bashrc` or `zshrc` - files are auto-sourced

### Adding Vim Plugins

Plugins are managed with vim-plug. The plugin installation location is
`vim/plugged/`.

### Adding Agent Skills

Agent Skills are passive knowledge that LLM agents draw on automatically (unlike
slash commands which are explicitly invoked).

1. Create a new skill directory in `llm/skills/`:
   ```bash
   mkdir llm/skills/my-skill
   ```

2. Create `SKILL.md` with required frontmatter:
   ```yaml
   ---
   name: my-skill
   description: Clear description of what this skill does and when to use it
   ---

   # My Skill

   [Markdown instructions for the agent - keep under 500 lines]
   ```

3. Optionally add supporting resources:
   - `scripts/`: Executable code (Python, Bash, JavaScript)
   - `references/`: Supporting docs loaded on demand
   - `assets/`: Templates, images, data files

4. Skills are automatically available after re-running `./install.sh`

See `llm/skills/README.md` for the complete specification.

### Adding Claude Code Custom Commands

1. Create a `.md` file in `llm/claude/commands/`:
   ```bash
   touch llm/claude/commands/mycommand.md
   ```

2. Add frontmatter and prompt content:
   ```markdown
   ---
   description: "Brief description"
   allowed-tools: ["bash", "read"]
   argument-hint: "[optional args]"
   ---

   Your command prompt here. Use $1, $2 for arguments.
   ```

3. Commands are automatically available after the next shell restart or
   re-running `./install.sh`

See `llm/claude/commands/README.md` for detailed syntax and examples.

### Local Overrides

- Shell aliases: Create `~/.localaliases` (not tracked in git)
- Git config: Create `~/.gitconfig_local` (automatically included)
- Claude Code secrets: Create `~/.claude/settings.local.json` (git-ignored, for
  API keys and machine-specific settings)

## Common Patterns

### Path Management
- User scripts should go in `~/bin/` (already in PATH via shell configs)
- Both shells use unique path arrays to prevent duplicates

### File Permissions
- Default umask is `077` (files readable only by owner)
- Scripts and directories created by install.sh use `0700` permissions

### Vim Cache Management
- All Vim cache files go to `$XDG_CACHE_HOME/vim/` (backups, undo, swap, etc.)
- Cache directories are created automatically if missing
