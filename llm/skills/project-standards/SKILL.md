---
name: project-standards
description: Applies the user's repository conventions for task runners, uv-based Python tooling, quality checks, hooks, GitHub Actions, releases, and repository documentation. Use when scaffolding a repository or changing its tooling, CI, hooks, release flow, or standards compliance.
compatibility: Requires bash for the audit script. The conventions assume uv, just, and GitHub Actions where applicable.
metadata:
  updated: "2026-10-15"
---

# Project Standards

Use one task-runner recipe for every quality check. Developers, hooks, and CI
call that recipe; they do not repeat the underlying commands. This prevents
local, hook, and CI behavior from drifting.

`$SKILL_DIR` is the absolute directory containing this skill's `SKILL.md`.
Run bundled scripts from the repository being created or assessed. Read
`policy.toml` before changing generated defaults; the scaffold and audit share
that source.

## Choose the repository archetype

Identify the repository before changing its tooling. Read the matching
reference before implementation.

| Archetype | Signals | Runner | Reference |
| --- | --- | --- | --- |
| Python package | `pyproject.toml`, `src/`, uv | `just` | `references/python-package.md` |
| Script collection | Loose scripts without a package or test suite | `just` | This skill |
| Jekyll site | `_config.yml`, `Gemfile`, Docker | `make` | `references/jekyll-site.md` |
| Shell or infrastructure | Shell scripts, Bats tests, playbooks | `just` | `references/shell-repo.md` |
| Google Apps Script | `src/appsscript.json`, bound Apps Script | None by default | `references/apps-script.md` |
| Single file | One script with no dependencies | None | Ruff configuration only; no CI required |

Script collections provide `sync`, `lint`, `format`, `check`, and
`hooks-install`. Their `check` recipe is `lint`; CI is one lint job. They do
not need `type-check`, `test`, coverage, versioning, or release recipes
without a package or test suite. Document that shape in `AGENTS.md` so audit
warnings about missing mypy and coverage settings are understood as deliberate.

Google Apps Script projects start without local tooling or CI. Add `clasp`, a
task runner, and CI only after a real script project and credentials exist.
Run runtime tests from the Apps Script editor until then. An unexecutable
recipe is worse than no recipe.

## Task-runner contract

Use `just` unless the archetype requires `make`. A recipe may be absent when
it does not apply. When present, use these names and meanings.

| Recipe | Meaning | Caller |
| --- | --- | --- |
| `default` | List available recipes | Developer |
| `lock` | Create or deliberately update `uv.lock` | Developer, never CI |
| `sync` | Consume the committed lock with `uv sync --locked --dev` | Developer and CI |
| `deps-update` | Deliberately upgrade dependencies, optionally by package | Developer |
| `lint` | Run every read-only static check | Hook and CI |
| `format` | Run mutating formatters and fixers | Developer |
| `type-check` | Run mypy | CI |
| `test` | Run the test suite | CI |
| `check` | Run `lint`, `type-check`, and `test` | Pre-push and release |
| `hooks-install` | Install the pre-commit hook | Once per clone |
| `build` / `clean` | Build artifacts or remove generated output | When applicable |
| `package-check` | Validate wheel/sdist metadata and an isolated install | Python packages |
| `release` | Validate checks and create a local tag; never push or publish | Python packages |

`lint` is complete and read-only. For Python, it includes both `ruff check`
and `ruff format --check`. Add every applicable static checker, such as
yamllint, shellcheck, or hadolint. `format` is the mutating counterpart:
`ruff format`, then `ruff check --fix`.

Do not create aliases such as `fmt`, `lint-fix`, or `format-check`. Keep
project-specific recipes alongside this contract. Standard recipes are a
floor, not a limit on recipes such as `just decode` or `just test-fast`.
`check` must cover at least what CI runs. It may run more, but never less. A
green local `check` covers the applicable checks for the current environment;
CI additionally validates the declared interpreter matrix and hosted workflow
services. Use `syntax-check` rather than `check` for a narrower operation.

For Jekyll sites, use `lint-scripts`, `format-scripts`, and `test-scripts`
where Ruby owns the base recipe names.

## Python tooling policy

Use uv-managed environments for every Python invocation.

| Situation | Required approach |
| --- | --- |
| Repository with `pyproject.toml` | `just sync`, then `uv run --locked <tool>` |
| Repository without a project environment | `uvx <tool>@<pinned-version>` |
| Standalone script | PEP 723 metadata and `uv run script.py` |
| Long-lived command-line tool | `uv tool install` |
| CI | `astral-sh/setup-uv`, `uv python install`, and `uv sync` |

Do not use `pip install`, activate a virtual environment, depend on globally
installed tools, or use `uv pip install --system`. Put development tools in
`[dependency-groups] dev`, commit `uv.lock`, and use `uv python install` for
the interpreter. A bare tool can work on one machine but fail in a hook or CI;
`uv pip install --system` also makes CI differ from `just sync` locally.

## Default policy

Apply these defaults unless a documented exception requires a different
choice.

| Area | Standard |
| --- | --- |
| Dependencies | uv only. Commit `uv.lock`; never ignore it. |
| Build backend | Hatchling. Read the package version from `__init__.py`. |
| Versioning | Keep the version in `__init__.py` only. `just release` creates the tag. |
| Python support | `requires-python`, the CI floor, and the oldest supported non-EOL CPython match. The policy currently tests 3.11 through 3.15 and pins `.python-version` to 3.15. |
| Linting | Ruff configuration in `pyproject.toml`, or `ruff.toml` without a project file. Use `assets/pyproject-tooling.toml`. |
| Types | `mypy --strict` for `src/` packages. Script collections are exempt. |
| Tests | Pytest. Packages use `--cov-fail-under=90`; script collections have no coverage gate. |
| Hook | A local pre-commit framework hook calls `just lint` with filenames disabled; install it with `just hooks-install`. The fallback wrapper also calls the runner. |
| CI | Workflows call runner recipes and contain no tool-specific commands. Use `ci.yml` as a reusable workflow, with `tests.yml` and `release.yml` as callers. |
| Documentation | Include canonical `AGENTS.md` instructions and a `README.md`. |
| License | New repositories use CC0. Do not add, remove, or relicense an existing repository without owner direction. |

Use these action versions together and propagate the change to every affected
repository. The shared policy stores immutable commit SHAs and this table
retains the corresponding readable release labels. This table is the
authoritative release-label set.

| Action | Version |
| --- | --- |
| `actions/checkout` | `v7` |
| `astral-sh/setup-uv` | `v9.0.0` |
| `extractions/setup-just` | `v4` |
| `actions/setup-python` | `v6`, only when uv does not manage Python |
| `actions/upload-artifact` | `v4` |
| `actions/download-artifact` | `v4` |
| `pypa/gh-action-pypi-publish` | `release/v1` |

Prefer `uv python install ${{ matrix.python-version }}` to
`actions/setup-python`. uv already manages the interpreter, so this removes a
pin to maintain.

## Update an existing repository

1. Run the audit:
   `bash "$SKILL_DIR/scripts/audit.sh" <repo-path>`.
2. Read the archetype reference.
3. Validate the shared policy:
   `bash "$SKILL_DIR/scripts/policy-check.sh"`.
4. Establish the task-runner contract first. Add `lock`, locked `sync`, and
   `package-check` where the archetype requires them.
5. Update the pre-commit hook to call `just lint` through the local framework.
6. Update CI to call runner recipes and validate the declared matrix.
7. Align pins and the remaining policy items.
8. Run `git status` and `git check-ignore -v` for newly added dotfiles, hook
   files, and agent docs. Update `.gitignore` rather than
   force-adding ignored files.
9. Re-run the audit. Fix each failure, document a permanent exception, or
   record a migration deferral as described under **Exceptions**.
10. Run `just check` before committing. For a generated Python project this
    includes an isolated wheel/sdist package check; CI additionally runs the
    workflow linters and every supported Python version.

For a Google Apps Script repository, use the documented bound-project test
entry point until `clasp` is configured.

Rename recipes and all their call sites in the same change. Search code and
documentation for the old recipe name before completing the migration. Make a
line-length reflow its own commit when widening an older repository from 88 to
100 columns. Keep the old width only when reflow would collide with in-flight
work, and record the reason in a comment.

Older `.gitignore` files can hide `.python-version`, `bin/pre-commit.sh`, or
`AGENTS.md` through rules such as `.*`, `bin`, or `AGENTS.md`.
`git add` may not report a file hidden by a directory rule. Check the expected
files explicitly:

```bash
git check-ignore -v .python-version bin/pre-commit.sh AGENTS.md
```

Un-ignore the file rather than force-adding it. The audit detects only files
that already exist, so it cannot report an omitted file.

Treat unexplained commands in the previous CI as suspect. Confirm that the CI
being replaced actually worked. After copying an asset, search it for
`PACKAGE`; replace every placeholder. `PACKAGE` is the distribution name,
which may differ from the console-script name used in a smoke test. For
example, `photo-org` can provide an `organize-photos` command.

## Scaffold a new repository

Create a Python package with:

```bash
bash "$SKILL_DIR/scripts/scaffold.sh" <dest-dir> <package-name>
```

`package-name` is the Python import name. Generation is offline and defaults to
a library without publishing configuration. Select other supported shapes
explicitly:

```bash
bash "$SKILL_DIR/scripts/scaffold.sh" <dest-dir> <package-name> \
  --kind cli --distribution-name <distribution> --command-name <command> \
  --publish --bootstrap
```

`--bootstrap` is the only scaffold option that resolves dependencies or
installs hooks. It runs `just lock`, `just sync`, and `just hooks-install`.
Without it, the generated directory is inspectable and the printed resume
command is the next step. Nonempty and symbolic-link destinations are refused
without changes; bootstrap failures leave generated files in place for
recovery.

Create a Google Apps Script repository with:

```bash
bash "$SKILL_DIR/scripts/scaffold-apps-script.sh" <dest-dir> <project-name>
```

The scaffold includes a source layout for a future `clasp` workflow,
anonymized-fixture guidance, and CC0 licensing. It does not install Node.js,
configure a script ID, or create CI. In the target Google Sheet, select
**Extensions → Apps Script**, then copy the JavaScript files from `src/` into
the bound project before adding runtime behavior.

The opt-in Copier pilot is available from the dotfiles repository as
`just test-project-standards-copier`. It derives its temporary template from
the tested offline scaffold, requires a separately installed Copier, and
records a project-owned customization through one template update. Set
`COPIER_PILOT_CHECK=1` to bootstrap the temporary project and run its full
`just check` when uv, just, actionlint, zizmor, and the declared Python
interpreter are available. It is a pilot only; do not infer fleet-wide
adoption from it.

## Package and release validation

`package-check` accepts an existing artifact directory or builds a fresh
temporary set. It verifies wheel and sdist metadata, package content, the
declared license file, and the typed marker for generated libraries, then
installs the exact wheel into a clean temporary
environment outside the checkout, and verifies the imported module location
and version. CLI projects pass their console command separately; libraries do
not assume a command exists.

The reusable CI workflow builds once, runs `package-check`, and uploads that
validated artifact set. The publish-only job downloads the set and has
`id-token: write` only at the publication boundary. `just release` validates a
clean worktree and creates a local `v<version>` tag after `just check`; it does
not push tags, create hosted releases, or publish to PyPI.

## Bump a tool or action version

Update the pin in this skill first. Apply the change repository by repository
and run `just check` in each. For Ruff, run
`uv lock --upgrade-package ruff` in a uv repository. In a repository without
a lockfile, update the `uvx ruff@X.Y.Z` pin.

## Exceptions

Record an external constraint in the file that deviates from the standard.
For example, comment a nonstandard Python floor next to `requires-python`.
Add a reason to every Ruff ignore entry.

```toml
# Calibre ships its own interpreter; 3.8 is externally imposed, not a choice.
requires-python = ">=3.8"
```

Use a permanent inline waiver only when a rule will never apply. The marker
must name a known rule and include a nonempty reason after an em dash:

```yaml
# project-standards: allow ci-inline — minimal Alpine container
```

The audit reports a documented permanent waiver as an exception rather than a
failure. Use waivers only for permanent constraints; unexplained standing
failures make later audit results less credible. Bare markers, unknown rules,
unrelated prose, and migration deferrals do not suppress findings.

For a migration blocked by code work, leave the audit failure visible and
record the reason in `AGENTS.md`. Do not weaken the rule or add an unworkable
recipe merely to make the audit pass. For example, `shapez_2_tools` omits
`type-check` because `mypy --strict` reports 195 errors;
`wayback-machine-archiver` limits its type check to the package because tests
produce 26 additional errors.

Known standing exceptions:

- `calibre-blog-rating-sync` uses `requires-python = ">=3.8"` because Calibre
  provides the interpreter.
- Jekyll sites exclude `*.md` from Ruff. Ruff 0.16 and later formats Python
  code fences in published prose that the repository does not own.

## Scripts and references

`scripts/audit.sh` is read-only. It reports PASS, WARN, or FAIL and exits 1
when any check fails. Use `--porcelain` for tab-separated output.

```bash
bash "$SKILL_DIR/scripts/audit.sh" /path/to/repo
bash "$SKILL_DIR/scripts/audit.sh" /path/to/repo --porcelain
```

Porcelain output is `STATUS<TAB>CHECK<TAB>DETAIL`; it can gate a loop over
repositories.

- `references/python-package.md`: package layout, dependencies, versions,
  mypy, pytest, CI, and releases.
- `references/apps-script.md`: Apps Script layout, fixtures, validation, and
  optional clasp workflow.
- `references/jekyll-site.md`: Make targets, Docker, Ruff scoping, hooks, and
  CI.
- `references/shell-repo.md`: shellcheck, Bats, Bash 3.2, hadolint, hooks,
  and CI.
