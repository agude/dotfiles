# Python Package

Applies to repos with a `pyproject.toml` and a `src/` layout, managed by uv.
Reference implementation: `switrs-to-sqlite`.

## Layout

```
repo/
├── src/package_name/__init__.py   # __version__ lives here, and only here
├── tests/
├── bin/pre-commit.sh
├── .github/workflows/{ci,tests,release}.yml
├── justfile
├── pyproject.toml
├── uv.lock                        # committed
├── .python-version                # latest supported
├── AGENTS.md                      # CLAUDE.md, GEMINI.md symlink to it
├── README.md
└── LICENSE
```

## Dependencies

uv manages everything. Dev tools go in `[dependency-groups] dev`, not in
`[project.optional-dependencies]` — the dependency group is uv's native
mechanism and `uv sync --dev` installs it without touching the package's
public extras.

**Commit `uv.lock`.** A gitignored lockfile means CI resolves fresh on every
run, so a new release of a linter can fail a build that touched nothing.
That has happened here: `wayback-machine-archiver` silently moved to a new
ruff minor version in CI while the developer's environment stayed behind.

## Versioning

One home for the version: `src/package_name/__init__.py`, read by hatchling
via `[tool.hatch.version]`. No `bump-my-version` config, no version string
duplicated into `pyproject.toml`, no hand-rolled bump script — each of those
is a second place that can disagree.

Releasing: bump `__version__`, commit, tag `vX.Y.Z`, push the tag, publish a
GitHub release. `release.yml` runs CI, then publishes to PyPI via trusted
publishing.

## Python versions

- `requires-python` floor = the CI matrix floor = the oldest CPython that
  still receives security fixes.
- The matrix runs floor through latest, plus PyPy where the package is pure
  Python and cheap to test there.
- `.python-version` pins the latest supported version for local work.

When a CPython version goes EOL, raise the floor and drop it from the
matrix in the same commit — a floor that disagrees with the matrix is how
you end up testing a version you claim not to support.

## Types

mypy `strict` for the package. Tests get one override:

```toml
[[tool.mypy.overrides]]
module = "tests.*"
disallow_untyped_defs = false
```

Requiring annotations on every test function buys nothing; the test bodies
are the assertion.

## Tests

pytest with coverage gated at 90% for packages. If a package legitimately
cannot reach 90%, lower the number *and* write the reason next to it rather
than deleting the gate.

Keep the CI smoke test (`uv pip install . && <console-script> --help`). It
catches packaging errors — a missing `[project.scripts]` entry, a module
that imports only from the source tree — that the unit tests never see.

## CI

Three files, because release must run the *same* pipeline as CI rather than
a copy of it:

| File | Trigger | Contents |
|---|---|---|
| `ci.yml` | `workflow_call` | the `lint` and `test` jobs |
| `tests.yml` | push, PR | one job that calls `ci.yml` |
| `release.yml` | release published | calls `ci.yml`, then publishes |

Every step calls a runner verb. If a CI step contains `ruff`, `mypy`, or
`pytest` directly, that step is a bug: the developer can no longer reproduce
CI by running `just check`.
