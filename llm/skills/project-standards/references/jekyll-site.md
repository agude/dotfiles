# Jekyll Site

Applies to Docker-based Jekyll sites: `agude.github.io`, `hfgude-art`,
`minifate`. The runner is `make`, not `just` — these repos have an
established Makefile idiom and two runners in one repo is worse than the
inconsistency it would fix.

For the Docker mechanics (user-ID forwarding, the `DOCKER_RUN` variable,
image build targets), read the knowledge-base article **Docker Makefile
Patterns** — it is canonical for that layer and is not repeated here.

## Target names

The verb contract applies, with a suffix only where Ruby already owns the
base name:

| Target | Does |
|---|---|
| `lint` | RuboCop over the Ruby plugins |
| `lint-scripts` | `ruff check` + `ruff format --check` over Python |
| `format-scripts` | `ruff format` + `ruff check --fix` |
| `test` | Minitest, in Docker |
| `test-scripts` | pytest for the Python scripts |
| `hooks-install` | install the pre-commit hook |

## Ruff scoping

Python here is a script collection, not a package: no `src/` layout, no
version, often no tests. So mypy strict and the coverage gate do not apply.

Where the config lives depends on whether the scripts have their own
project:

- `agude.github.io/_scripts` has a `pyproject.toml` — config goes in it, and
  everything runs `uv run --project _scripts ruff ...`.
- `hfgude-art` and `minifate` have no pyproject — a root `ruff.toml`, run
  via a pinned `uvx ruff@X.Y.Z` held in one Makefile variable.

**Always exclude `*.md`.** Ruff 0.16+ formats Python code fences inside
Markdown. Pointed at a Jekyll root it will happily re-indent code samples
inside published posts, which are prose, not source.

Exclude build output and vendored artifacts too — `_site`, `.jekyll-cache`,
and any directory of notebooks published alongside old posts. On
`agude.github.io` those notebooks under `files/` produce hundreds of
findings that nobody will ever act on.

## Hooks auto-fix here

Tier A hooks are read-only, but these are not: the Jekyll hooks already
auto-fix and re-stage for RuboCop and Prettier, and a read-only ruff stage
inside the same script would be an inconsistency a reader has to explain.
Match the file you are in.

The hook must still call the runner rather than a bare binary. A bare `ruff`
is not on `PATH` on this machine — ruff lives in per-project uv
environments — so the hook has to go through `uv run --project _scripts` or
a make target. A hook that calls a missing binary exits 127 and blocks every
commit touching that file type.

## CI

These repos build and deploy, so lint runs inside the existing test job
rather than in a separate workflow. Add the Python lint step immediately
before the Python test step, and have it call the make target.
