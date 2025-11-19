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
- Links Claude Code settings and custom commands to `~/.claude/`

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
- `vim/vimrc`: Main Vim configuration
- `vim/plugins.vim`: Plugin-specific settings
- `vim/plug.vim`: vim-plug plugin manager
- `vim/ideavimrc`: IntelliJ IDEA Vim emulation config
- Uses Space as leader key (`\<Space>`) and backslash as local leader

### Git Configuration
- `config/git/config`: Git configuration with aliases and sensible defaults
- Notable aliases: `lg` (pretty log graph), `up` (pull + rebase + update
  submodules), `bclean` (delete merged branches)
- Merge strategy: fast-forward only (`merge.ff = only`)
- Pull strategy: rebase by default

### Claude Code Configuration
- `config/claude/settings.json`: User-level settings synced across machines
- `config/claude/commands/`: Custom slash commands (`.md` files)
- `~/.claude/` is a real directory; only specific files are symlinked:
  - `~/.claude/settings.json` → `config/claude/settings.json`
  - `~/.claude/commands/` → `config/claude/commands/`
- Runtime files (history, debug, session-env, etc.) stay in `~/.claude/` and
  are not tracked

**Note:** Claude Code currently doesn't follow XDG Base Directory specification
and hardcodes `~/.claude/`. When Anthropic adds XDG support, this can be
refactored to use `$XDG_CONFIG_HOME`. API keys and personal preferences should
go in `~/.claude/settings.local.json` (automatically git-ignored).

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

### Adding Claude Code Custom Commands

1. Create a `.md` file in `config/claude/commands/`:
   ```bash
   touch config/claude/commands/mycommand.md
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

See `config/claude/commands/README.md` for detailed syntax and examples.

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
