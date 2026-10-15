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
├── AGENTS.md                      # canonical agent instructions
├── README.md
└── LICENSE.md
```

## Dependencies

uv manages everything. Dev tools go in `[dependency-groups] dev`, not in
`[project.optional-dependencies]` — the dependency group is uv's native
mechanism and `uv sync --locked --dev` installs it without touching the
package's public extras. Use `just lock` for deliberate resolution and never
let ordinary lint, tests, or CI repair `uv.lock`.

The project lock does not pin isolated build-system resolution. `uv build` and
the sdist-to-wheel package check may resolve Hatchling or another backend in a
temporary build environment, so that network/cache boundary must be validated
separately from runtime and development dependency locking.

**Commit `uv.lock`.** A gitignored lockfile means CI resolves fresh on every
run, so a new release of a linter can fail a build that touched nothing.
That has happened here: `wayback-machine-archiver` silently moved to a new
ruff minor version in CI while the developer's environment stayed behind.

## Versioning

One home for the version: `src/package_name/__init__.py`, read by hatchling
via `[tool.hatch.version]`. No `bump-my-version` config, no version string
duplicated into `pyproject.toml`, no hand-rolled bump script — each of those
is a second place that can disagree.

Hatchling's default pattern does not match an annotated assignment, so
`__version__: str = "1.2.3"` needs an explicit one:

```toml
[tool.hatch.version]
path = "src/package_name/__init__.py"
pattern = "^__version__(?::\\s*str)?\\s*=\\s*['\"](?P<version>[^'\"]+)['\"]"
```

**Why hatchling and not `uv_build`**, given the always-uv rule: `uv_build`
rejects `dynamic = ["version"]` at build time and supports pure Python only.
Adopting it would mean either duplicating the version string or moving
`--version` onto `importlib.metadata`, which fails from a source checkout.
Astral's own docs point at hatchling when you need more than the basics.
Revisit if uv#14946 lands.

Releasing: bump `__version__`, commit, run `just release --dry-run`, then run
`just release` to create the local `vX.Y.Z` tag. Push the tag explicitly when
ready. The tag workflow builds and validates distributions once, transfers
those exact artifacts, and gives OIDC permission only to the publish job. A
tag/version mismatch fails before publication.

### Swapping the build backend

Changing backends alters how artifacts are assembled, so prove it rather
than assume it. Build before the change, keep the file lists, build after,
diff them:

```bash
uv build && unzip -Z1 dist/*.whl | sort > /tmp/before-wheel.txt
uv build && tar tzf dist/*.tar.gz | sed 's|^[^/]*/||' | sort > /tmp/after-sdist.txt
```

setuptools → hatchling is safe in practice: the wheel loses only
`top_level.txt`, which is legacy setuptools metadata. The sdist changes
more — hatchling ships everything not gitignored, so it picks up `.github/`
and drops `*.egg-info`. Confirm the sdist still carries every test file, and
exclude the agent docs, which are noise for anyone installing from source.
New scaffolds create only `AGENTS.md`; add `CLAUDE.md` here only when a legacy
repository still contains it:

```toml
[tool.hatch.build.targets.sdist]
exclude = ["AGENTS.md"]
```

A backend swap does not need a version bump: it changes neither the code nor
the declared metadata a consumer resolves against. Land it before a release,
not as one.

## Python versions

- `requires-python` floor = the CI matrix floor = the oldest CPython that
  still receives security fixes.
- The matrix runs floor through latest CPython. Add another interpreter only
  after running the full suite on it and recording the support decision.
- `.python-version` pins the latest supported version for local work.

**`.python-version` and the CI matrix fight each other.** uv honours the pin
wherever it finds one, including on the runner, so a matrix that installs
3.10 through 3.14 will still run every leg on the pinned interpreter — green
across the board, testing one version, names in the UI implying otherwise.
Override it per job:

```yaml
env:
  UV_PYTHON: ${{ matrix.python-version }}
```

`uv python install ${{ matrix.python-version }}` alone does not fix this: it
makes the interpreter available without selecting it.

When a CPython version goes EOL, raise the floor and drop it from the
matrix in the same commit — a floor that disagrees with the matrix is how
you end up testing a version you claim not to support.

**Never add a version to the matrix without running the suite on it.** A
matrix entry is a support claim, and adding one during a tooling migration
is exactly when it goes unverified. Run it first:

```bash
uv run --locked --python 3.14 pytest -q
```

This is not hypothetical: adding 3.14 to `shapez_2_tools` alongside its
migration broke two routing tests that pass on 3.11–3.13. The dependency
resolved and installed cleanly, so nothing failed until the tests ran.
Heavy native dependencies (ortools, scipy, numpy) are the usual cause — they
lag new CPython releases even when a wheel exists.

`.python-version` should name a version the matrix actually covers, latest
by default. The shared generated-project policy currently covers CPython
3.11–3.15; existing repositories may retain a documented lower range when
their dependencies require it.

## Types

mypy `strict` for the package.

**The `tests.*` override does not fire by default.** With a `src/` layout and
no `tests/__init__.py`, mypy resolves `tests/test_cli.py` as top-level module
`test_cli`, so a `module = "tests.*"` override matches nothing and every test
function reports `no-untyped-def`. Three settings are needed together:

```toml
[tool.mypy]
strict = true
namespace_packages = true
explicit_package_bases = true
mypy_path = "src"       # or the package is found twice and mypy refuses to run
```

Pair `disallow_untyped_calls = false` with `disallow_untyped_defs = false` in
the override, or typed tests calling untyped helpers re-report the same noise
under a different code.

**Scope `type-check` to the package when migrating.** Widening it to `tests/`
on an existing repo usually surfaces real type errors — 26 in
`wayback-machine-archiver`, mostly fixtures building plain dicts where a
TypedDict is expected. Fixing those is worthwhile but is its own change, not
part of a tooling migration. Note the gap in `AGENTS.md` and move on; new
repos should type-check tests from the start.

## Tests

pytest with coverage gated at 90% for packages.

**When migrating a repo below 90%, set the gate at the current floor**, with a
comment saying 90 is the target. Writing tests to reach 90 is not part of a
tooling migration, and setting an unreachable gate just means the first
commit after the migration is the one that turns it off. A floor ratchets:
coverage can only go up from there.

```toml
# The standard is 90; this repo sits at ~84 today. The gate is the current
# floor so coverage can only ratchet upward, not a blessing of 84.
addopts = "--cov=package_name --cov-fail-under=83"
```

Set the number a point or two below the measured value so ordinary variation
does not fail the build.

Keep `just package-check` in the gate. It validates both wheel and sdist
metadata and required package/license content, installs the exact wheel into a
clean environment outside the source tree, verifies the import location and
version, and invokes a console command only when the project declares one.

## CI

Three files, because release must run the *same* pipeline as CI rather than
a copy of it:

| File | Trigger | Contents |
|---|---|---|
| `ci.yml` | `workflow_call` | the `lint`, `build`, and `test` jobs |
| `tests.yml` | `on: [push, pull_request]` — all branches, not just main | one job that calls `ci.yml` |
| `release.yml` | `v*` tag push | calls `ci.yml`, then publishes its validated artifact |

Every quality step calls a runner verb. If a CI step contains `ruff`, `mypy`,
or `pytest` directly, that step is a bug: the developer can no longer
reproduce CI by running `just check`. System package installation and
workflow-linter provisioning are exceptions because uv cannot provide those
host tools.

The exception is system packages, which uv cannot install. A Python
dependency binding to a C library needs its runtime installed on the runner
before `just sync` — `music-tagger` needs `libdiscid0`, or the `discid`
import fails at collection time. Keep that as an explicit `apt-get` step and
say which dependency needs it.
