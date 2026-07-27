# Shell / Infra Repo

Applies to repos whose product is shell scripts, playbooks, or container
orchestration: `coat-tree`, `pi-cron-automation`, `ansible`. The runner is
`just` where one exists.

## The verb contract, mapped

`lint` is still read-only and total — it just contains different tools:

| Repo kind | `lint` runs |
|---|---|
| Bash | `shellcheck` over every tracked `*.sh` |
| Ansible | `yamllint -s .` then `ansible-lint` |
| Docker | `hadolint` over each Dockerfile |

`format` may legitimately not exist: shell has no house formatter here. Omit
the recipe rather than aliasing it to something that does not format.

`check` still means the full gate. `ansible` currently uses `check` for
`ansible-playbook --syntax-check`; that is a different thing and should be
renamed `syntax-check`, with `check` reserved for `lint` + `test`.

## Tests

`bats` for Bash, with the suite in `tests/`. `coat-tree` has the pattern
worth copying — three jobs:

1. `shellcheck` on Ubuntu.
2. `bats` across a `[ubuntu-latest, macos-latest]` matrix.
3. `bats` again inside a `bash:3.2` container.

The third job is the one people forget and the one that catches real bugs.
macOS runners execute `#!/usr/bin/env bash`, which resolves to Homebrew's
modern Bash — so the macOS job does *not* test the Bash 3.2 that ships as
`/bin/bash` on macOS. Only the container does.

Scripts that must run on macOS's system Bash cannot use associative arrays,
`${var^^}`, or `mapfile`. If a repo does not care about Bash 3.2, drop the
job and say so in the workflow comment.

## Hooks

Same rule as everywhere: the hook calls `just lint`. `ansible/bin/pre-commit.sh`
is the reference — it filters to staged YAML, calls the runner, and prints a
clear pass/fail line.

## CI

Shell repos are cheap to test, so a single `ci.yml` on push and pull request
is enough; the callable `ci.yml` + `tests.yml` split exists to keep releases
honest, and these repos do not publish artifacts. Use `concurrency` with
`cancel-in-progress` so pushes to the same branch do not queue up.
