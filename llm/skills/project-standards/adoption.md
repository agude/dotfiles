# Adoption and maintenance record

Updated 2026-10-15. This record separates local implementation readiness from
hosted account setup and fleet rollout.

## Local pilots

| Pilot | Scope | Evidence | Result |
|---|---|---|---|
| Generated Python library | Offline library scaffold, audit, package fixture | `bats llm/skills/project-standards/tests/` (25 cases) | Passes generation, audit, and isolated package fixture |
| Generated Python CLI | Separate import, distribution, and command names | Bats CLI scaffold case | Passes rendering and placeholder checks |
| Apps Script | Offline source and manual test entry point | Bats Apps Script case | Passes structural generation; runtime remains bound-project work |
| Existing shell repository | `/home/agude/.dotfiles` audit and root lint | `bash llm/skills/project-standards/scripts/audit.sh . --porcelain`; `just lint` | Passes applicable local checks |
| Copier update pilot | Scaffold-derived Python template with one committed customization | `COPIER_PILOT_CHECK=1 just test-project-standards-copier` using Copier 9.19.1, CPython 3.13.6, actionlint 1.7.7, and zizmor 1.14.2 | Custom README and project-owned file survive one template update; repeated update is clean; defer fleet adoption |

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
reviewable update preset for GitHub Actions and Python dependencies. The
scheduled support recipe reports candidates but never raises support floors or
rewrites project files automatically.
