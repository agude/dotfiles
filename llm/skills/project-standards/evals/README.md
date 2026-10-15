# Project-standards evaluation cases

These cases define the representative behavior review for the revised skill.
Run them in fresh equivalent contexts and store traces outside the shipped
skill. Structural validation and repository tests are separate evidence.

| Case | Input | Required evidence |
|---|---|---|
| New library | Generate a default Python library | Offline generation, locked bootstrap instructions, `just check`, package-check |
| New CLI | Generate a CLI with distinct names | Working entry point and isolated console-command check |
| Script collection | Audit a shell/script repository | No package/type/coverage/release migration without applicable evidence |
| Constrained package | Audit and migrate a package with a documented exception | Exception survives, failures remain visible, no unrelated source churn |
| Audit-only | Request an audit without implementation | Reports evidence and changes no files |
| Nearby request | Ask for a documentation-only change | Does not trigger unsolicited tooling migration |

The comparison baseline is the parent revision before the project-standards
implementation. Grade generated execution, preserved constraints, runner use,
actual validation output, and remaining external limitations.
