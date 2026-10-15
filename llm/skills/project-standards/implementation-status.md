# Implementation status

Updated 2026-10-15 against `/tmp/plan.md`.

| Plan area | Status | Evidence or dependency |
|---|---|---|
| 0 Baseline | Complete | Review findings are covered by isolated fixtures and adoption records. |
| 1 Generated-project tests | Complete locally; integration required in CI | 25 offline Bats cases pass; `test-project-standards-integration` bootstraps library and CLI projects, consumes one validated artifact set across the matrix, and verifies staged-content hook behavior in CI. |
| 2 Locked dependencies | Complete | Generated `lock`, locked `sync`, locked tool recipes, and explicit update recipe. |
| 3 Distribution validation | Complete locally | Wheel/sdist metadata, package-content, sdist-to-wheel rebuild, isolated import, version, typed-marker, and optional CLI checks are implemented; deterministic fixture and Copier gate pass through uv-managed helper execution. |
| 4 Publishing | Local implementation complete; external setup pending | Artifact transfer, tag validation, named `pypi` environment, and publish-only OIDC job are rendered. GitHub/PyPI configuration was not changed or verified. |
| 5 Audit | Complete for implemented rules | Runner graph, workflow syntax, lock tracking, policy, waiver, hook, and single-file fixtures pass. Rendered publishing and non-publishing workflows pass actionlint 1.7.7 and zizmor 1.14.2. |
| 6 Maintenance | Local implementation complete; hosted adoption pending | Policy, Renovate preset, scheduled support review, policy/template consistency gate, and candidate-version regression are present. No hosted bot was activated. |
| 7 Hooks | Complete locally; staged-content integration required in CI | Framework config, effective hooks path, foreign-hook backup, custom-path fixture, and the disposable staged-content integration case are implemented. |
| 8 Offline/bootstrap generation | Complete locally | Library, CLI, Apps Script, placeholder, refusal, and offline tests pass. |
| 9 Copier pilot | Pilot complete; fleet adoption deferred | Copier 9.19.1 rendered a scaffold-derived template, preserved a committed project customization through a template update, repeated cleanly, and passed the generated project's full `just check` on CPython 3.13.6. Broad adoption is deferred until an existing customized package demonstrates lower maintenance cost. |
| 10 Skill/evaluations | Structural and fixture validation complete; agent traces pending | Skill validator and repository fixtures pass; representative prompt cases are recorded, but no hosted agent evaluation trace was generated. |
| 11 Final verification | Partial by environment | `just lint`, project-standards Bats, ShellCheck, skill validation, policy validation, workflow linters, and audit pass. Root `just check` was stopped after existing OpenCode server tests repeatedly failed with `ServeError`. |

The remaining items are external or environment-dependent. They are not
represented as green local checks.
