---
name: project-standards
description: Creates new repositories from the user's per-language template repos and applies the same conventions by hand where no template exists. Covers the just runner contract, uv-locked tools, CI that calls recipes, pinned actions, pre-commit hooks, and releases. Use when starting a new project, or when choosing or explaining a new project's tooling, CI, hooks, or release flow.
compatibility: Requires git, uv 0.13 or newer, and just. The templates target GitHub Actions.
metadata:
  updated: "2026-10-16"
---

# Project Standards

Each language has a template repository that is itself a working project.
Create new projects from it with its `scripts/init`; do not copy files by
hand.

| Language | Repository | Local clone |
| --- | --- | --- |
| Python | `https://github.com/agude/python-template` | `~/Projects/python-template` |
| Bash | `https://github.com/agude/bash-template` | `~/Projects/bash-template` |

## Create a project

Use uv 0.13 or newer to download the final release of Python 3.15, which
the templates select in `.python-version`.

1. Clone the template if the local clone is missing:
   `git clone --recurse-submodules <repository> <local clone>`.
   `scripts/init` fetches `origin` and copies `origin/main`, so an existing
   clone needs no update. It warns when the checked-out `HEAD` differs.
2. From the clone, run `scripts/init` with a destination that does not
   exist:
   - Python: `scripts/init <dest> <import_name>`. Options:
     `--distribution NAME`, `--command NAME`, `--library` for no CLI, and
     `--no-publish` for no PyPI release workflow.
   - Bash: `scripts/init <dest> <name>`.

   Run `scripts/init --help` for the full usage. `init` fails, and creates
   nothing, if a name is invalid or a placeholder survives.
3. Set up and check the new project:
   `cd <dest> && just sync && just hooks-install && just check`.
4. Replace the example description and code, then commit. `init` stages the
   files but never commits.

For a Python package that will publish, register a PyPI Trusted Publisher
before the first release: the repository, workflow `release.yml`, and
Environment `pypi`. A blank Environment field allows any environment.

## Why the conventions exist

- **Runner contract.** Developers, the hook, and CI all call the same `just`
  recipes, so they cannot drift apart:

  | Recipe | Meaning |
  | --- | --- |
  | `default` | List the recipes. |
  | `sync` | Install from the lock. |
  | `lint` | Run every read-only static check, including actionlint and zizmor. |
  | `format` | Run the mutating fixers. |
  | `test` | Run the test suite. |
  | `check` | Run `lint`, `type-check` where it applies, and `test`. |
  | `hooks-install` | Install the Git hook. |
  | `lock` | Regenerate the lockfile. |

  `check` covers at least what CI runs, so a local pass predicts a CI pass.
- **uv only.** Every Python tool runs from the project's locked environment.
  A tool that happens to be on one machine's `PATH` fails in a hook or in CI.
  Non-Python projects get their tools from PyPI wrappers, such as
  `shellcheck-py` and `shfmt-py`, in a uv dev group.
- **Locked, with a 7-day delay.** `uv.lock` is committed, and CI installs
  with `uv sync --locked`. `exclude-newer = "7 days"` and a matching 7-day
  Dependabot `cooldown` keep a compromised release out until it has had time
  to be noticed and yanked.
- **CI calls recipes and nothing else**, apart from setup steps. Workflows
  hold no tool knowledge, so changing a check means changing one recipe.
- **SHA pins and the zizmor and actionlint gate.** Tags can be moved; commit
  SHAs cannot. Actions are pinned to a SHA with a `# vX.Y.Z` comment, which
  Dependabot updates. Every checkout sets `persist-credentials: false`, and
  each workflow starts from `permissions: {}` and grants per job.
  `just lint` runs zizmor and actionlint, so a violation fails locally.
- **`UV_PYTHON` in matrices.** Without it, uv follows `.python-version`, and
  every leg of a version matrix tests the same interpreter.
- **Bash 3.2.** macOS ships Bash 3.2. Scripts and recipes avoid newer
  features, and CI tests on Bash 5, in the `bash:3.2` container, and on
  macOS with `/bin/bash`. The Bash template's `AGENTS.md` lists the rules.
- **Read-only hook.** The pre-commit framework runs one local hook,
  `just lint`, against the staged content. It never rewrites files, and it
  fails loudly when `just` is missing.
- **Python packaging.** `uv_build`, with a static version in
  `pyproject.toml` that `just release <bump>` changes through
  `uv version --bump`. Code reads it with `importlib.metadata.version()`.
- **Repository files.** `AGENTS.md` with no `CLAUDE.md` symlink,
  `README.md`, CC0 1.0 in `LICENSE.md`, `.gitignore`, `.gitattributes`, and
  `.github/dependabot.yml`.

## A language with no template

Apply the same conventions by hand. Copy the shared pieces from the closer
template: `.pre-commit-config.yaml`, `.github/dependabot.yml`, the
`hooks-install` recipe, and the workflow job layout. Then add the language's
own lockfile and tools, and make `just check` pass.

If more projects in that language are likely, build a template repository
instead, on the pattern of the existing two: a working project with
distinctive placeholders, a `scripts/init` marked `export-ignore`, Bats tests
for `init`, and a Template test workflow that creates and checks a project
weekly.

## Change a template

Change the template repository, then run its checks:

- Python: Run `just check package-check`, `just test-init`, and
  `just test-generated <variant>`. For changes to `scripts/init` or marker
  blocks, run `just test-generated <variant>` for each affected variant:
  `cli`, `library`, `no-publish`, and `custom-names`.
- Bash: Run `just check`, `just test-init`, and `just test-generated`.

Projects do not track their template after creation.

## Out of scope

Migrating or updating existing repositories is out of scope for this skill.
If the user asks for it, treat it as a manual change that uses the template's
files as the reference. Do not run `scripts/init` over an existing project.
