# Dotfiles Improvement Plan

## Objective

Make installation and shell startup safer, deterministic, independently
testable, and easier to maintain without expanding dotfiles into machine
provisioning.

## Constraints

- Preserve Bash 3.2 compatibility for `install.sh` and portable hook code.
- Preserve the broad `.*` rule in `.gitignore`.
- Preserve the separation between repository `AGENTS.md` and `llm/AGENTS.md`.
- Preserve the ownership boundary: Ansible provisions machines, dotfiles owns
  user-level configuration, and external repositories self-register.
- Back up real files, directories, and foreign symlinks before replacement.
- Do not replace the known command-string guard limitation with additional
  fragile regular expressions; use structured parsing or conservative policy.
- Protect the current uncommitted changes in
  `llm/codex/agude.config.toml` while changing Codex configuration handling.

## Phase 1: Establish Safety Tests

- [x] Add isolated installer behavior tests.
  - Approach: Run `install.sh` with a temporary `HOME` and controlled fixture
    repository. Cover clean installs and hostile pre-existing state.
  - Acceptance criteria:
    - Correct links remain unchanged on repeated installation.
    - Real files, real directories, and foreign symlinks are backed up.
    - Missing sources do not enter the manifest.
    - Profile switches remove only repository-owned stale links.
    - Dry runs make no filesystem changes.
    - Empty and malformed active-profile files return explicit errors.
  - Files: `install.sh`, new installer Bats tests.

- [x] Run every tracked hook test in CI.
  - Approach: Add the Claude and Codex hook Bats suites to the existing test
    workflow before changing guard or lifecycle behavior.
  - Acceptance criteria:
    - `llm/claude/hooks.d/tests/` runs on every push and pull request.
    - `llm/codex/hooks.d/tests/` runs on every push and pull request.
    - Hook tests run under Bash 3.2 in addition to the normal Linux/macOS jobs.
  - Files: `.github/workflows/test.yaml`, hook test directories.

## Phase 2: Fix Destructive Installer Edge Cases

- [x] Make `ensure_real_dir` ownership-aware.
  - Depends on: isolated installer behavior tests.
  - Approach: Reuse the ownership and backup rules from `_place_link`. Remove a
    symlink directly only when it is owned by dotfiles.
  - Acceptance criteria:
    - Foreign symlinks such as `~/.config`, `~/bin`, and skill directories are
      backed up before replacement.
    - Dotfiles-owned symlinks are replaced without unnecessary backups.
    - Existing real directories remain unchanged.
  - Files: `install.sh`, installer tests.

- [x] Stop overwriting unmanaged Firefox and systemd files.
  - Depends on: ownership-aware directory handling.
  - Approach: Route service files and Firefox `user.js` through explicit
    ownership handling. Prefer managed symlinks where consumers support them;
    otherwise back up foreign files before copying.
  - Acceptance criteria:
    - Existing user-owned files are never overwritten without a backup.
    - Managed files participate in profile cleanup or have equivalent explicit
      lifecycle handling.
    - Multiple Firefox profiles are handled deterministically.
  - Files: `install.sh`, `config/firefox/user.js`, `config/systemd/user/`,
    installer tests.

- [x] Harden `empty-downloads` path validation.
  - Approach: Resolve the physical target portably, reject paths outside the
    physical home directory, and prevent traversal into mounted filesystems.
  - Acceptance criteria:
    - `..` components cannot escape the home directory.
    - Symlinked intermediate directories cannot escape the home directory.
    - A leaf `Downloads` symlink is handled explicitly and safely.
    - Mounted filesystems beneath Downloads are not traversed.
    - Tests exercise every rejected path without touching real user data.
  - Files: `bin/empty-downloads.sh`, new Bats tests.

## Phase 3: Fix Confirmed Configuration Bugs

- [x] Keep Codex machine-local state out of the repository.
  - Approach: Stop symlinking a writable Codex profile directly into the
    repository. Use a tracked template plus an untracked local profile, or pass
    portable settings through the wrapper while Codex owns its writable files.
  - Acceptance criteria:
    - Project trust, hook hashes, and TUI state do not modify tracked files.
    - Portable approval, sandbox, reasoning, personality, hook, and memory
      settings remain active.
    - `codex --profile agude` continues to work.
    - Existing uncommitted local state is preserved until deliberately migrated.
  - Files: `llm/codex/agude.config.toml`, `links.conf`,
    `profiles/default.sh`, `shared/sharedrc.d/100.aliases.sh`, `AGENTS.md`.

- [x] Remove terminal escape residue from the work Claude model.
  - Acceptance criteria: The work profile contains a valid intentional model
    identifier and starts without invalid-model fallback behavior.
  - Files: `llm/claude/settings.work.json`.

- [x] Make ripgrep configuration valid or optional.
  - Approach: Track and link the intended ripgrep configuration, or export
    `RIPGREP_CONFIG_PATH` only when the file exists.
  - Acceptance criteria: `rg --files` runs without a missing-config error on a
    fresh installation and on profiles without a ripgrep configuration.
  - Files: `shared/sharedrc.d/001.xdg_base_directory.sh`, `links.conf`, optional
    `config/ripgrep/config`.

## Phase 4: Make Shell Reloads Deterministic

- [x] Make Bash prompt hook registration idempotent.
  - Approach: Register `history -a` and `build_prompt` exactly once while
    preserving any pre-existing `PROMPT_COMMAND` content and the original exit
    status.
  - Acceptance criteria:
    - Repeated `source ~/.bashrc` does not duplicate either hook.
    - A failing command remains visible after every reload.
    - Existing third-party prompt hooks remain intact.
  - Files: `bash/bashrc.d/002.history.bash`,
    `bash/bashrc.d/107.prompt.bash`, shell startup tests.

- [x] Split shell-specific bin-subdirectory glob handling.
  - Approach: Move Bash and Zsh glob logic into their shell-specific module
    directories, or replace it with independently parseable shared code.
  - Acceptance criteria:
    - The Bash implementation parses without requiring `extglob` first.
    - The Zsh implementation handles an empty `~/bin` without `nomatch` errors.
    - Bash preserves the caller's previous `nullglob` setting.
    - Hidden directories are treated consistently and intentionally.
    - Repeated reloads do not duplicate PATH entries.
  - Files: `shared/sharedrc.d/002.bin_subdirs.sh`, `bash/bashrc.d/`,
    `zsh/zshrc.d/`, startup tests.

- [x] Separate XDG declarations from directory initialization.
  - Approach: Keep noninteractive startup limited to environment declarations;
    move Jupyter, Gimp, and GnuPG directory creation into installation or an
    explicit initialization module.
  - Acceptance criteria:
    - Noninteractive Bash startup does not create directories.
    - Interactive Bash and Zsh receive identical XDG variables.
    - `GNUPGHOME` is created with mode `0700` when initialization runs.
  - Files: `shared/sharedrc.d/001.xdg_base_directory.sh`, `install.sh`, shell
    startup tests.

- [x] Prevent duplicate macOS compiler flags.
  - Acceptance criteria: Repeated Zsh reloads leave exactly one
    `-falign-functions=8` entry and preserve existing `CFLAGS` ordering.
  - Files: `zsh/zshrc.d/110.macos.zsh`.

## Phase 5: Harden Command Guards

- [x] Add regression tests for guard bypasses before changing policy.
  - Cover force refspecs beginning with `+`, fully qualified main/master
    destinations, commands with environment prefixes, chained commands, and
    newly introduced destructive `gh` subcommands.
  - Files: `llm/claude/hooks.d/tests/`.

- [x] Replace fragile push parsing with structured command analysis.
  - Depends on: guard regression tests.
  - Acceptance criteria:
    - Force pushes are blocked regardless of flag or refspec spelling.
    - Pushes to `main`, `master`, `refs/heads/main`, and
      `refs/heads/master` are blocked.
    - Ordinary feature-branch pushes remain allowed.
    - Text inside commit messages and heredocs is not mistaken for a command.
  - Files: `llm/claude/hooks.d/PreToolUse/010.git-guard.sh`,
    `llm/claude/hooks.d/PreToolUse/020.git-push-guard.sh`, tests.

- [x] Default unmatched GitHub mutations to confirmation.
  - Depends on: guard regression tests.
  - Approach: Explicitly allow known read-only and routine workflow commands;
    return `ask` for unknown or mutating operations instead of assuming safety.
  - Acceptance criteria:
    - New destructive `gh` commands cannot become automatically allowed.
    - Known read-only commands remain automatic.
    - Routine PR and issue workflows retain their documented behavior.
  - Files: `llm/claude/hooks.d/PreToolUse/030.gh-guard.sh`, tests.

## Phase 6: Consolidate Tooling and CI

- [x] Add a repository `justfile` as the single check definition.
  - Approach: Define `lint`, `test`, and `check`; keep all recipes read-only
    except explicitly named formatting or installation tasks.
  - Acceptance criteria:
    - `just lint` runs every static check.
    - `just test` runs installer, hook, Johnny Decimal, and PDF tests.
    - `just check` matches or exceeds every CI check.
  - Files: new `justfile`.

- [x] Make the pre-commit hook call the task runner.
  - Depends on: repository `justfile`.
  - Acceptance criteria: The hook contains no independent ShellCheck command
    definition and `just lint` is the only lint source of truth.
  - Files: `bin/pre-commit.sh`, `justfile`.

- [x] Make CI call task-runner recipes.
  - Depends on: repository `justfile` and complete hook test coverage.
  - Acceptance criteria:
    - Workflow YAML contains orchestration but no duplicated lint/test commands.
    - Linux, macOS, and Bash 3.2 coverage remain explicit.
    - Workflow concurrency cancels superseded runs.
    - Action versions match the project standard, including
      `actions/checkout@v7`.
  - Files: `.github/workflows/test.yaml`, `justfile`.

- [x] Add a concise human README.
  - Acceptance criteria: README documents installation, profiles, dry-run,
    architecture boundaries, and the standard local verification command.
  - Files: new `README.md`, `AGENTS.md` links where appropriate.

## Phase 7: Reduce Installer and Repository Complexity

- [x] Separate linking from network-dependent plugin setup.
  - Approach: Make normal installation deterministic and local. Move Vim/Neovim
    plugin installation into an explicit bootstrap or update command.
  - Acceptance criteria:
    - Re-running `install.sh` does not contact the network.
    - Link installation succeeds when GitHub or vim-plug is unavailable.
    - Plugin bootstrap remains one documented command.
  - Files: `install.sh`, `vim/plug.vim`, README.

- [x] Validate executable-name collisions in `bin/`.
  - Acceptance criteria: Two files that map to the same extensionless command
    name cause an explicit validation error before links are changed.
  - Files: `install.sh`, installer tests.

- [x] Move machine-specific Git trust into local configuration.
  - Acceptance criteria: The portable Git configuration contains no
    machine-specific `safe.directory`; the required entry remains available in
    `~/.gitconfig_local` on the relevant machine.
  - Files: `config/git/config`, local configuration documentation.

- [x] Trim irrelevant generated ignore rules.
  - Approach: Remove framework-specific Python template sections for artifacts
    this repository cannot produce. Preserve `.*` and all currently required
    skill/test/runtime exclusions.
  - Acceptance criteria:
    - Existing ignored runtime and build artifacts remain ignored.
    - Expected repository files are visible to `git status`.
    - The deliberate `.*` rule remains unchanged.
  - Files: `.gitignore`.

- [x] Correct stale architecture and profile documentation.
  - Remove references to the deleted `ext_link` function.
  - Describe the current single manifest-diff cleanup loop accurately.
  - Remove the nonexistent Gemini work-profile override from comments, or add
    the override if it is actually required.
  - Document the final Codex local-state design.
  - Files: `AGENTS.md`, `profiles/work.sh`, README.

## Completion Gate

- [x] `just check` passes locally.
- [ ] Linux, macOS, and Bash 3.2 CI jobs pass.
  - Local Linux and exact Bash 3.2 container checks pass; hosted macOS awaits CI.
- [x] Two consecutive installs are idempotent.
- [x] A profile switch removes only dotfiles-owned links.
- [x] Interactive Bash and Zsh start without errors and remain stable after two
  reloads.
- [x] A normal install performs no network access.
- [x] `git status` remains clean after starting Codex with the `agude` profile.
- [x] Installer and cleanup safety tests use only temporary homes and fixtures.
