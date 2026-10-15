# Implementation status

Updated 2026-10-15 against `/tmp/plan.md`.

| Plan area | Status | Evidence or dependency |
|---|---|---|
| 0 Baseline | Complete | Review findings are covered by isolated fixtures and adoption records. |
| 1 Generated-project tests | Complete locally; integration required in CI | 26 offline Bats cases and the dependency-backed `test-project-standards-integration` pass on CPython 3.15 with policy-pinned workflow linters; CI still exercises the declared matrix. |
| 2 Locked dependencies | Complete | Generated `lock`, locked `sync`, locked tool recipes, and explicit update recipe. |
| 3 Distribution validation | Complete locally | Wheel/sdist metadata, package-content, sdist-to-wheel rebuild, isolated import, version, typed-marker, and optional CLI checks are implemented; deterministic fixture and Copier gate pass through uv-managed helper execution. |
| 4 Publishing | Local implementation complete; external setup pending | Artifact transfer, tag validation, named `pypi` environment, and publish-only OIDC job are rendered. GitHub/PyPI configuration was not changed or verified. |
| 5 Audit | Complete for implemented rules | Runner graph, workflow syntax, lock tracking, policy, waiver, hook, single-file, action-SHA, and release-comment fixtures pass. Rendered publishing and non-publishing workflows pass actionlint 1.7.7 and zizmor 1.14.2. |
| 6 Maintenance | Local implementation complete; hosted adoption pending | Policy, Renovate preset, scheduled support review, policy/template consistency gate, and candidate-version regression are present. No hosted bot was activated. |
| 7 Hooks | Complete locally; staged-content integration required in CI | Framework config, effective hooks path, foreign-hook backup, custom-path fixture, and the disposable staged-content integration case are implemented. |
| 8 Offline/bootstrap generation | Complete locally | Library, CLI, Apps Script, placeholder, refusal, and offline tests pass. |
| 9 Copier pilot | Pilot complete; fleet adoption deferred | Copier 9.19.1 rendered a scaffold-derived template, preserved a committed project customization through a template update, repeated cleanly, and passed the generated project's full `just check` on CPython 3.13.6. Broad adoption is deferred until an existing customized package demonstrates lower maintenance cost. |
| 10 Skill/evaluations | Structural and fixture validation complete; fresh-context agent traces pending | Skill validator and repository fixtures pass; representative prompt cases are recorded, but this environment exposes no fresh-context agent evaluation runner. |
| 11 Final verification | Partial by unrelated repository tests | `just lint`, project-standards Bats, ShellCheck, skill validation, policy validation, workflow linters, audit, and CPython 3.15 generated integration pass. Root `just check` was stopped after existing OpenCode server tests repeatedly failed with `ServeError`. |

## Step-level disposition

| Step | Disposition | Evidence or dependency |
|---|---|---|
| 0.1 | Complete | Review inventory covers the skill files, callers, supported hosts, licensing, and repository constraints. |
| 0.2 | Complete | Temporary Bats fixtures reproduce the reviewed scaffold, lock, audit, package, hook, and staged-content defects. |
| 0.3 | Complete | `SKILL.md`, policy, runner contracts, and adoption notes define offline, locked, read-only, and matrix boundaries. |
| 1.1 | Complete locally | Bats owns temporary directories and controlled fixtures; missing required tools fail with diagnostics. |
| 1.2 | Complete locally | 26 Bats cases cover runner, workflow, waiver, lock, package, hook, and single-file rules. |
| 1.3 | Complete locally | Library, CLI, publishing, non-publishing, Apps Script, naming, destination, and placeholder cases pass. |
| 1.4 | Complete locally; required in CI | Dependency-backed generated library and CLI integration passes on CPython 3.15 with staged-content hook validation; CI remains responsible for the declared interpreter matrix. |
| 1.5 | Complete | Root CI calls the offline and dependency-backed project-standards recipes without duplicating their test commands. |
| 2.1 | Complete | Generated `lock`, locked `sync`, and explicit `deps-update` recipes are documented and tested. |
| 2.2 | Complete | Generated lint, format, type, and test recipes use locked uv execution. |
| 2.3 | Complete locally | Stale metadata fails without changing `uv.lock`; the fixture executes real locked uv behavior. |
| 2.4 | Complete | Bootstrap, CI, references, and generated recipes use the same lock/sync contract. |
| 3.1 | Complete locally | `package-check` accepts existing artifacts or owns temporary builds and distinguishes import, distribution, and command names. |
| 3.2 | Complete locally | Wheel/sdist metadata, license, typed marker, package content, and sdist-to-wheel rebuild checks pass. |
| 3.3 | Complete locally | Exact wheels install outside the checkout and verify import location, version, and optional CLI behavior. |
| 3.4 | Complete | Generated `check` and reusable CI invoke the shared package-check implementation. |
| 4.1 | Complete in rendered workflow | Reusable CI builds once, validates, uploads one artifact set, and matrix jobs download it. |
| 4.2 | Complete locally | Release fixtures validate stable/prerelease tag matching and reject mismatches before publication. |
| 4.3 | Complete in rendered workflow | Publish is a separate named `pypi` environment job with OIDC permission only at publication. |
| 4.4 | Complete locally | `just release --dry-run` is non-mutating; normal release creates only a local tag after checks. |
| 4.5 | Pending external setup | GitHub environment, PyPI Trusted Publisher, and TestPyPI settings were not changed or verified. |
| 5.1 | Complete for implemented rules | Bash audit retains human/porcelain output and performs read-only structured runner/workflow/lock inspection. |
| 5.2 | Complete locally | Archetype, recipe graph, transitive contract, and single-file fixtures pass. |
| 5.3 | Complete locally | Multiline runs, package-install exceptions, policy action SHAs/comments, PyPI action, Git state, and workflow syntax are covered. |
| 5.4 | Complete | Root and generated lint gates run actionlint and zizmor with policy-pinned provisioning. |
| 5.5 | Complete locally | Waiver identity, scope, reason, and machine-readable reporting cases pass. |
| 6.1 | Complete | `policy.toml` is validated and consumed by scaffold, audit, documentation, and maintenance checks. |
| 6.2 | Complete locally | Policy check detects stale docs/templates and verifies generated Python/action/linter values. |
| 6.3 | Complete locally; hosted activation pending | Renovate’s official validator 44.164.5 accepts the preset. A local-platform extract dry run with Renovate 42.99.0 found 14 GitHub Actions and 7 PEP 621 dependencies in a committed generated fixture; no hosted bot or PR was configured. |
| 6.4 | Complete locally | Scheduled support review runs policy consistency and explicit candidate-version checks without raising floors automatically. |
| 6.5 | Pending hosted adoption | No hosted bot was activated and no reviewable hosted update PR was created. |
| 7.1 | Complete locally; required in CI | Framework hook, unconditional lint trigger, staged-content fixture, and restore behavior are implemented. |
| 7.2 | Complete locally | Git effective hook paths, worktree paths, foreign-hook backups, and repeatable installation are tested. |
| 7.3 | Complete locally | Audit recognizes configured versus installed hooks and missing/foreign wiring. |
| 7.4 | Complete | Clone/bootstrap instructions and fail-closed prerequisite behavior are documented. |
| 8.1 | Complete locally | Positional scaffold use, explicit kind/publish/bootstrap options, validation, and help are implemented. |
| 8.2 | Complete locally | Offline deterministic library, CLI, publishing, and Apps Script rendering passes placeholder checks. |
| 8.3 | Complete locally | Nonempty/symlink refusal, path handling, partial-output preservation, and bootstrap recovery pass. |
| 8.4 | Complete locally on CPython 3.13.6 | Copier full gate exercises lock, locked sync, hooks, lint, type-check, tests, and package validation. |
| 9.1 | Complete | Isolated scaffold-derived Copier pilot records managed/project-owned content and a real customization. |
| 9.2 | Complete | Copier answers record provenance while reusing rendered generator output. |
| 9.3 | Complete | Template update preserves customization, applies the maintenance change, and repeats cleanly. |
| 9.4 | Complete with defer decision | Fleet adoption is deferred until an existing customized package demonstrates lower maintenance cost. |
| 10.1 | Complete locally | Entrypoint documents archetype selection, policy use, helper interfaces, and verification workflow. |
| 10.2 | Complete locally | Runner, lock, package, hook, release, Jekyll, matrix, coverage, and licensing guidance is aligned. |
| 10.3 | Complete locally | Skill validator, placeholder checks, resource checks, and policy validation pass. |
| 10.4 | Pending evaluation trace | Representative cases are recorded in `evals/`; no supported fresh-context agent runner is available here for previous-versus-revised traces. |
| 11.1 | Partial by unrelated repository tests | Local affected gates, CPython 3.15 generated integration, and portability checks pass; root `just check` remains limited by unrelated OpenCode `ServeError` tests. |
| 11.2 | Complete | Reviewable atomic commits use the repository imperative message format; no push, merge, or publication was performed. |
| 11.3 | Complete as a local record | This table separates local readiness, external publishing, hosted adoption, and evaluation dependencies. |

The remaining items are external or environment-dependent. They are not
represented as green local checks.
