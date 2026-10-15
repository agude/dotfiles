# Adoption and maintenance record

Updated 2026-10-15. This record separates local implementation readiness from
hosted account setup and fleet rollout.

## Local pilots

| Pilot | Scope | Evidence | Result |
|---|---|---|---|
| Generated Python library | Offline library scaffold, audit, package fixture | `bats llm/skills/project-standards/tests/` (26 cases) | Passes generation, audit, and isolated package fixture |
| Generated Python CLI | Separate import, distribution, and command names | Bats CLI scaffold case | Passes rendering and placeholder checks |
| Apps Script | Offline source and manual test entry point | Bats Apps Script case | Passes structural generation; runtime remains bound-project work |
| Existing shell repository | `/home/agude/.dotfiles` audit and root lint | `bash llm/skills/project-standards/scripts/audit.sh . --porcelain`; `just lint` | Passes applicable local checks |
| Existing Python package | `/home/agude/Projects/ccrs-to-sqlite` | Baseline audit failed only the runner contract because `check` did not reach `package-check`; bounded pilot committed as `6108fc4` | Post-change audit passes; `just check` passes on CPython 3.15 with 469 tests, 99.27% coverage, isolated wheel/sdist validation, and the installed pre-commit hook |
| Copier update pilot | Scaffold-derived Python template with one committed customization | `COPIER_PILOT_CHECK=1 just test-project-standards-copier` using Copier 9.19.1, CPython 3.13.6, actionlint 1.7.7, and zizmor 1.14.2 | Custom README and project-owned file survive one template update; repeated update is clean; defer fleet adoption |

The dependency-backed generated-project integration now passes locally on
CPython 3.15 with Hatchling and the declared workflow linters, using temporary
cache and interpreter paths. CI remains responsible for the full declared
interpreter matrix.

The existing-package pilot used the clean `ccrs-to-sqlite` main branch. It
added the locked runner contract, distribution checks, staged-content hook,
SHA-pinned workflows, and publish-only artifact transfer in one atomic commit.
The local audit and full gate pass after the change; GitHub environment,
Trusted Publisher, TestPyPI, and hosted Renovate setup remain untouched.

## Hosted release setup

No GitHub environment, PyPI Trusted Publisher, production release, or TestPyPI
upload was changed or verified by this implementation. The generated workflow
uses the `pypi` environment and OIDC only in its publish job; an owner must
verify that the external publisher registration names the same repository,
workflow, and environment before enabling a production tag.

The direct hosted check on 2026-10-15 found zero GitHub environments for
`agude/CCRS-to-SQLite`, repository Actions permissions with SHA pinning
disabled, the old release workflow still deployed on `main` at `17fb113`, and
no registered PyPI project (`https://pypi.org/pypi/ccrs-to-sqlite/json`
returned 404). The local pilot commit has not been pushed, so no hosted release
run was created.

## Copier pilot status

Completed as an isolated generated-project pilot. The harness derives its
temporary template from the tested offline scaffold, records provenance in
`.copier-answers.yml`, preserves a project-owned README customization and
project-owned file through one template update, and verifies that repeating the
update produces no diff. The full generated-project gate passed on CPython
3.13.6 with the policy-pinned workflow linters.

Fleet adoption is deferred. This pilot proves update mechanics but does not
demonstrate lower maintenance cost against an existing customized package.
Revisit with one authorized project and compare the Copier update diff with
the current generator's manual maintenance before adopting it broadly.

## Maintenance authority

`policy.toml` is authoritative for generated Python versions, action refs,
workflow-linter versions, and required Python recipes. `renovate.json5` is a
reviewable update preset for GitHub Actions and Python dependencies. Renovate
44.164.5 validates the preset; its `pep621` manager owns both `pyproject.toml`
dependencies and `uv.lock` maintenance. A local-platform extract dry run with
Renovate 42.99.0 found 14 GitHub Actions and 7 PEP 621 dependencies in a
committed generated fixture. The scheduled support recipe reports candidates
but never raises support floors or rewrites project files automatically.
The candidate repository has no hosted `renovate.json5` and no reviewable
Renovate PR; hosted activation remains pending.

## Root-gate environment boundary

The local OpenCode 1.18.23 binary cannot start the disposable server used by
`tests/opencode-plugin.bats`: it exits with `ServeError` before `/session`
becomes available. The plugin test, config test, and plugin implementation are
byte-identical to `main`, so this failure is outside the project-standards
change. OpenCode tracks the generic `ServeError` output for server bind
failures in [issue #38738](https://github.com/anomalyco/opencode/issues/38738).
The project-standards work does not weaken or skip those existing tests.

## Agent evaluation

On 2026-10-15, six representative prompts were run in fresh paired Codex CLI
contexts against the baseline skill at `main` and the revised skill at
`4abbe64`: new library, new CLI, script collection, constrained package,
audit-only, and nearby documentation request. The revised skill passed 18 of
18 objective assertions; the baseline passed 13 of 18. The revised traces
confirmed offline generation, distinct CLI naming, preserved package
constraints, read-only auditing, and scope restraint. The detailed traces,
grading, and feedback are stored outside the shipped skill for this
evaluation run. Dependency resolution was DNS-blocked in the generation cases;
hosted CI and account integrations were not part of the local comparison.
