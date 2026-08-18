# Dotfiles

Personal Bash, Zsh, Vim/Neovim, Git, desktop, and agent-tool configuration for
Unix-like systems. Installation is profile-driven, local-only, and safe to
repeat.

## Install

Clone the repository at `~/.dotfiles`, then run:

```bash
./install.sh
```

The installer selects `default` on a noninteractive first run and records the
choice in `.active-profile`. Use a different profile or inspect changes with:

```bash
./install.sh --profile work
./install.sh --dry-run
./install.sh --show
```

Profiles in `profiles/` enable groups and override tracked configuration
templates. `default` installs the complete desktop setup. `work` changes the
Claude settings template. `server`, `synology`, and `root` provide reduced
environments.

Normal installation does not contact the network. Vim plugins are a separate,
explicit bootstrap:

```bash
bootstrap-vim-plugins
# or, from this repository:
just bootstrap-vim-plugins
```

## Structure

- `links.conf` owns simple target-to-source symlinks.
- `install.sh` owns profile loading, directory initialization, procedural
  linking, manifest cleanup, and backups.
- `shared/sharedrc.d/` contains syntax shared by Bash and Zsh.
- `bash/bashrc.d/` and `zsh/zshrc.d/` contain shell-specific behavior.
- `config/`, `vim/`, and `llm/` contain application configuration.
- `bin/` contains scripts installed into `~/bin` without extensions.

The installer replaces only symlinks that point into this repository. Real
files, directories, and foreign symlinks are moved to timestamped backups.
The manifest cleanup removes only previously managed dotfiles symlinks.

Mutable application state stays local. Git overrides belong in
`~/.gitconfig_local`; Claude overrides belong in
`~/.claude/settings.local.json`; Codex project trust and hook state live in the
real file `~/.codex/agude.config.toml`, initialized once from the tracked
template.

## Verify

Install `just`, ShellCheck, Bats, Zsh, jq, Python, and uv, then run:

```bash
just check
```

This runs all static checks plus the shell and PDF test suites. CI also runs
the shell suite under Bash 3.2 and performs installation smoke tests on Linux
and macOS.

Repository implementation rules and portability constraints are documented in
[AGENTS.md](AGENTS.md).
