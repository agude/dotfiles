# Implementation status

Updated 2026-10-15 against `/tmp/plan.md`.

| Plan area | Status | Evidence or dependency |
|---|---|---|
| 0 Baseline | Complete | Review findings are covered by isolated fixtures and adoption records. |
| 1 Generated-project tests | Complete locally; integration required in CI | 14 offline Bats cases pass; `test-project-standards-integration` bootstraps library and CLI projects in CI. |
| 2 Locked dependencies | Complete | Generated `lock`, locked `sync`, locked tool recipes, and explicit update recipe. |
| 3 Distribution validation | Complete locally | Wheel/sdist metadata, package-content, isolated import, version, typed-marker, and optional CLI checks are implemented; deterministic fixture passes. |
| 4 Publishing | Local implementation complete; external setup pending | Artifact transfer, tag validation, named `pypi` environment, and publish-only OIDC job are rendered. GitHub/PyPI configuration was not changed or verified. |
| 5 Audit | Complete for implemented rules | Runner graph, workflow, lock tracking, policy, waiver, hook, and single-file fixtures pass. Workflow linters are required prerequisites for generated projects. |
| 6 Maintenance | Local implementation complete; hosted adoption pending | Policy, Renovate preset, scheduled support review, and pilot inventory are present. No hosted bot was activated. |
| 7 Hooks | Complete locally | Framework config, effective hooks path, foreign-hook backup, and custom-path fixture pass. |
| 8 Offline/bootstrap generation | Complete locally | Library, CLI, Apps Script, placeholder, refusal, and offline tests pass. |
| 9 Copier pilot | Deferred | Copier is not installed and no customized project was authorized; criteria are recorded in `adoption.md`. |
| 10 Skill/evaluations | Structural and fixture validation complete; agent traces pending | Skill validator and repository fixtures pass; representative prompt cases are recorded, but no hosted agent evaluation trace was generated. |
| 11 Final verification | Partial by environment | `just lint`, project-standards Bats, ShellCheck, skill validation, policy validation, and audit pass. Root `just check` was stopped after existing OpenCode server tests repeatedly failed with `ServeError`. |

The remaining items are external or environment-dependent. They are not
represented as green local checks.
