---
name: project-standards
description: Tooling conventions for this user's repos — task-runner verbs (just/make), ruff lint and format, mypy, pytest and coverage, pre-commit hooks, GitHub Actions CI, release flow, and repo docs. Use when scaffolding a new repo, adding or changing a linter/formatter/type-checker/test setup, wiring or editing CI workflows or pre-commit hooks, pinning or bumping tool and action versions, or bringing an existing repo in line with the standard.
compatibility: Requires bash for the audit script. The conventions themselves assume uv, just, and GitHub Actions.
metadata:
  updated: "2026-07-27"
---

# Project Standards

**Skill base directory:** `${CLAUDE_SKILL_DIR}`

House conventions for how repos are linted, tested, gated, and released.
The point is that every repo answers the same questions the same way, so a
change to one repo's tooling is legible in all the others.

## The core rule

**Every check has exactly one definition — a task-runner recipe. The
developer, the pre-commit hook, and CI all call that recipe. None of them
restate the commands.**

```
just lint  ←──┬── developer types it
              ├── .git/hooks/pre-commit calls it
              └── CI calls it
```

When this rule is broken, tooling drifts silently: a hook can call a binary
that isn't installed, or CI can check something the developer never runs.
Both have happened here.

## Always uv, always isolated

**Every Python invocation goes through uv, and every dependency lives in an
environment uv owns.** No exceptions in these repos.

| Situation | Do this | Never this |
|---|---|---|
| Repo with a `pyproject.toml` | `uv sync`, then `uv run <tool>` | `pip install`, `source .venv/bin/activate`, bare `ruff`/`pytest` |
| Repo without one | `uvx <tool>@<pinned-version>` | a globally installed tool |
| Standalone script | PEP 723 inline metadata + `uv run script.py` | `pip install` into system Python |
| Long-lived CLI you use by hand | `uv tool install` | `pip install --user` |
| CI | `astral-sh/setup-uv`, `uv python install`, `uv sync` | `pip install`, `uv pip install --system` |
| Interpreter itself | `uv python install` | system Python, pyenv, homebrew Python |

Two consequences that are easy to get wrong:

- **Never assume a tool is on `PATH`.** Nothing is installed globally, so a
  script that calls bare `ruff` works on the machine that wrote it and
  nowhere else. This has already broken a hook here: it called `ruff`,
  exited 127, and blocked every commit touching a `.py` file. Recipes and
  hooks call `uv run <tool>`; the hook calls the recipe.
- **`uv pip install --system` is not isolation.** It installs into the
  runner's interpreter, which is fine for a throwaway container and wrong
  as a habit — it diverges from what `just sync` gives the developer, so CI
  stops being reproducible locally. Use `uv sync` in CI too.

Dev tools go in `[dependency-groups] dev`, not
`[project.optional-dependencies]`. The dependency group is uv's native
mechanism and does not pollute the package's public extras.

## Archetypes

Pick the archetype first; it determines the runner and the reference doc.

| Archetype | Looks like | Runner | Reference |
|---|---|---|---|
| Python package | `pyproject.toml`, `src/`, uv | `just` | `references/python-package.md` |
| Script collection | loose `*.py`, no `src/`, no suite | `just` | this table's note below |
| Jekyll site | `_config.yml`, `Gemfile`, Docker | `make` | `references/jekyll-site.md` |
| Shell / infra | `*.sh`, `tests/*.bats`, playbooks | `just` | `references/shell-repo.md` |
| Single file | one script, no deps | none | ruff config only, no CI needed |

**Script collections** get `sync`, `lint`, `format`, `check`, and
`hooks-install` — and deliberately no `type-check`, `test`, coverage gate, or
version, because there is no package or suite for them to describe. `check`
is just `lint`. CI is a single lint job. Say so in `AGENTS.md`, so the
audit's warnings about the missing mypy and coverage settings read as a shape
decision rather than neglect.

## The verb contract

Both runners expose the same verbs. Recipes may be absent when they don't
apply (a repo with no types has no `type-check`), but a verb that exists
means what it means here.

| Verb | Does | Called by |
|---|---|---|
| `default` | list recipes (`@just --list`) | human |
| `sync` | install/lock dependencies | human, CI |
| `lint` | **all read-only static checks** | hook, CI |
| `format` | all mutating fixers | human |
| `type-check` | mypy | CI |
| `test` | test suite | CI |
| `check` | `lint` + `type-check` + `test` | pre-push, release |
| `hooks-install` | install the pre-commit hook | once per clone |
| `build` / `clean` | package build, artifact cleanup | as applicable |

Rules that keep the contract honest:

- **`lint` is read-only and total.** It runs *every* static check the repo
  has — `ruff check` **and** `ruff format --check`, plus yamllint,
  shellcheck, hadolint where they apply. Never a subset.
- **`format` is the mutating twin**: `ruff format` then `ruff check --fix`.
- **No `fmt`, `lint-fix`, or `format-check` recipes.** They fold into the
  two verbs above.
- **`check` is the full gate** and must cover at least what CI runs, so a
  green `just check` means a green CI. It may run *more* — a repo whose full
  suite takes minutes per interpreter can have CI run a fast subset while
  `check` runs everything locally. It must never run *less*. Never use the
  name for anything else (a syntax check is `syntax-check`).
- **Standard verbs are a floor, not a replacement.** Keep the repo's own
  recipes — `just decode`, `just organize`, `just test-fast` — alongside
  them. The contract says what `lint` must mean, not that a justfile may
  contain nothing else.
- Jekyll sites suffix only where Ruby owns the base name:
  `lint-scripts`, `format-scripts`, `test-scripts`.

## Policy

Defaults. Deviating is allowed; deviating silently is not — see
*Recording an exception*.

| Area | Standard |
|---|---|
| Dependencies | uv only (see above); `uv.lock` **committed**, never gitignored |
| Build backend | `hatchling` with `[tool.hatch.version]` reading `__init__.py` |
| Versioning | version lives in `__init__.py` only; `just release` tags |
| Python support | `requires-python` floor = CI matrix floor = oldest non-EOL CPython; matrix runs floor→latest; `.python-version` present and set to latest supported |
| Lint | ruff, config in `pyproject.toml` (`ruff.toml` if no pyproject); see `assets/pyproject-tooling.toml` |
| Types | mypy `strict` wherever there is a `src/` package; script collections exempt |
| Tests | pytest; `--cov-fail-under=90` for packages, no gate for script collections |
| Hook | calls `just lint`; installed by `just hooks-install`; **never inlines commands** |
| CI | jobs call runner verbs; workflow YAML contains no tool knowledge |
| CI layout | `ci.yml` (`on: workflow_call`) + `tests.yml` (thin caller) + `release.yml` |
| Docs | `AGENTS.md` canonical, `CLAUDE.md` and `GEMINI.md` symlinked to it; `README.md` |
| Licence | **New repos: CC0.** Never relicense an existing repo, and never add a licence to one that has none — both are the owner's call, not a tooling decision |

### Pinned action versions

Bump these together, here, then propagate to every repo. This table is the
single source of truth.

| Action | Version |
|---|---|
| `actions/checkout` | `v7` |
| `astral-sh/setup-uv` | `v9.0.0` |
| `extractions/setup-just` | `v2` |
| `actions/setup-python` | `v6` (only when uv isn't managing the interpreter) |
| `pypa/gh-action-pypi-publish` | `release/v1` |

Prefer `uv python install ${{ matrix.python-version }}` over
`actions/setup-python`; uv already manages interpreters, and dropping the
action removes a version to track.

## Workflows

### Bringing an existing repo in line

1. Run the audit: `bash ${CLAUDE_SKILL_DIR}/scripts/audit.sh <repo>`.
2. Read the archetype reference before editing anything.
3. Fix in this order — **runner first**, because the hook and CI call it:
   rename recipes to the verb contract → point the hook at `just lint` →
   point CI at the runner → align pins and policy items.
4. **Run `git status` and confirm every new file is actually visible.** See
   the gitignore trap below.
5. Re-run the audit; every FAIL should be gone or documented as an exception.
6. Run `just check` and confirm it passes before committing.

### The gitignore trap

Older repos carry GitHub-template `.gitignore` files with rules like `.*`,
`bin`, or a bare `CLAUDE.md` from a pre-`AGENTS.md` era. Those silently
swallow exactly the files a migration adds: `.python-version`,
`bin/pre-commit.sh`, and the agent-doc symlinks. Everything looks right
locally and nobody else ever receives the hook.

`git add` warns only for explicitly named paths, so a directory add hides
it. Check directly, and un-ignore rather than force-add:

```bash
git check-ignore -v .python-version bin/pre-commit.sh CLAUDE.md
```

The audit reports this as `hook.tracked` and `python.version`, but only for
files that already exist — it cannot warn about a file you have not written
yet.

### Adopting the line length

Repos predating the standard may sit at 88. Widen to 100 and reflow in a
**separate commit** that touches nothing else, so the formatting churn stays
reviewable apart from the tooling change. Keep the old width only when the
reflow would collide with in-flight work; say so in a comment if you do.

Rename recipes with their call sites in the same commit. A justfile whose
`fmt` became `format` while a hook still calls `just fmt` is worse than the
inconsistency it replaced. Call sites include prose: `AGENTS.md`, the
README, and design docs all quote recipe names. `grep -rn "just <oldname>"`
before you finish.

**Check that the CI you are replacing actually worked.** A migration is when
anyone looks at these files closely, so treat unexplained commands as
suspect. `calibre-blog-rating-sync` had two jobs running `make build` in a
repo with no Makefile.

**Replace every placeholder in a copied asset.** The templates use
`PACKAGE`, which is the distribution name — but a smoke test needs the
*console script* name, and the two often differ (`photo-org` ships
`organize-photos`). Grep the copied file for `PACKAGE` before moving on.

### Starting a new repo

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/scaffold.sh <dest-dir> <package-name>
```

`package-name` is the Python import name (e.g. `my_package`); the distribution
name (`my-package`) is derived from it automatically. The script creates the
full directory tree, copies and substitutes all assets, initializes git, and
runs `just sync && just hooks-install`.

After scaffolding: fill in `AGENTS.md` and `README.md`, then run `just check`.

### Bumping a tool or action version

Update the pin here first, then apply it repo by repo, running `just check`
in each. For ruff specifically: `uv lock --upgrade-package ruff` in uv
repos, and the `uvx ruff@X.Y.Z` pin in repos without a lockfile.

## Recording an exception

Deviations are fine when the reason is external. Write the reason **in the
file that deviates**, as a comment, naming the constraint:

```toml
# Calibre ships its own interpreter; 3.8 is externally imposed, not a choice.
requires-python = ">=3.8"
```

Every `ignore` entry in a ruff config carries a comment saying why. An
undocumented deviation is a bug, and the audit script reports it as one.

### Waiving a rule permanently

A rule that will *never* apply to a file — as opposed to one you have not
got to yet — gets an inline waiver naming the check and the reason:

```yaml
# project-standards: allow ci-inline — minimal Alpine container
```

The audit then reports it as a documented exception instead of a failure.
Use this sparingly and only for permanent constraints; a standing FAIL that
nobody intends to fix trains people to ignore the audit entirely, which is
worse than either outcome.

### Deferring a rule during migration

Some rules cannot be satisfied by tooling work alone. Adding mypy to a
package that never had it, or reaching a coverage target, means changing
code — that is a separate project, and bundling it into a migration makes
both harder to review.

When that happens: **leave the audit failing, and record why in
`AGENTS.md`.** Do not add a recipe that fails, do not weaken the rule, and
do not silently drop it. A standing FAIL with a written reason is honest;
a passing audit that hides the gap is not.

Real examples: `shapez_2_tools` has no `type-check` recipe because
`mypy --strict` reports 195 errors; `wayback-machine-archiver` scopes
`type-check` to the package because widening it to tests surfaces 26.

Known standing exceptions:

- `calibre-blog-rating-sync` — `requires-python = ">=3.8"`, set by Calibre.
- Jekyll sites — ruff excludes `*.md`; ruff 0.16+ formats Python code
  fences inside Markdown, and published prose is not ours to reformat.

## Scripts

### `scripts/audit.sh`

Read-only conformance check for one repo. Detects the archetype, then
reports PASS/WARN/FAIL per rule. Changes nothing.

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/audit.sh /path/to/repo
bash ${CLAUDE_SKILL_DIR}/scripts/audit.sh /path/to/repo --porcelain
```

`--porcelain` emits tab-separated `STATUS<TAB>CHECK<TAB>DETAIL` for parsing.
Exits 1 if any check FAILs, 0 otherwise, so it can gate a loop over repos.

## References

Read the one matching the archetype before making changes:

- `references/python-package.md` — uv, hatchling, mypy, pytest, matrix,
  release flow.
- `references/jekyll-site.md` — make targets, Docker patterns, ruff scoping
  for `_scripts/`, why these hooks auto-fix.
- `references/shell-repo.md` — shellcheck, bats, Bash 3.2 coverage,
  hadolint.
