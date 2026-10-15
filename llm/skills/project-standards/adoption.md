# Adoption and maintenance record

Updated 2026-10-15. This record separates local implementation readiness from
hosted account setup and fleet rollout.

## Local pilots

| Pilot | Scope | Evidence | Result |
|---|---|---|---|
| Generated Python library | Offline library scaffold, audit, package fixture | `bats llm/skills/project-standards/tests/` (22 cases) | Passes generation, audit, and isolated package fixture |
| Generated Python CLI | Separate import, distribution, and command names | Bats CLI scaffold case | Passes rendering and placeholder checks |
| Apps Script | Offline source and manual test entry point | Bats Apps Script case | Passes structural generation; runtime remains bound-project work |
| Existing shell repository | `/home/agude/.dotfiles` audit and root lint | `bash llm/skills/project-standards/scripts/audit.sh . --porcelain`; `just lint` | Passes applicable local checks |

The generated-project build and full interpreter matrix require Python 3.15,
Hatchling, and the declared workflow linters. The sandbox has no Python 3.15
interpreter and no network access, so those checks remain CI requirements and
are not claimed as locally complete.

## Hosted release setup

No GitHub environment, PyPI Trusted Publisher, production release, or TestPyPI
upload was changed or verified by this implementation. The generated workflow
uses the `pypi` environment and OIDC only in its publish job; an owner must
verify that the external publisher registration names the same repository,
workflow, and environment before enabling a production tag.

## Copier pilot status

Pending. Copier is not installed in this checkout and no existing customized
Python repository was authorized as a template pilot. The tested generator,
shared policy, and explicit update record are the current maintenance boundary.
Run the pilot only with one selected project, a real customization to
preserve, and a measured update diff; do not infer fleet-wide adoption from
this implementation.

## Maintenance authority

`policy.toml` is authoritative for generated Python versions, action refs,
workflow-linter versions, and required Python recipes. `renovate.json5` is a
reviewable update preset for GitHub Actions and Python dependencies. The
scheduled support recipe reports candidates but never raises support floors or
rewrites project files automatically.
