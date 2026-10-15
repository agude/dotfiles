#!/usr/bin/env bash
# Exercise one updateable Copier project without changing repository state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PILOT_ROOT="$SCRIPT_DIR/copier-pilot"
COPIER_COMMAND="${COPIER_COMMAND:-copier}"

command -v "$COPIER_COMMAND" >/dev/null 2>&1 || {
    echo "project-standards Copier pilot: '$COPIER_COMMAND' is required" >&2
    echo "Install Copier, then set COPIER_COMMAND if it is not on PATH." >&2
    exit 2
}

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
TEMPLATE="$ROOT/template"
PROJECT="$ROOT/project"

bash "$SKILL_ROOT/scripts/scaffold.sh" "$TEMPLATE" copier_pilot >/dev/null
cp "$PILOT_ROOT/copier.yml" "$TEMPLATE/copier.yml"
cp "$PILOT_ROOT/.copier-answers.yml.jinja" "$TEMPLATE/.copier-answers.yml.jinja"
(
    cd "$TEMPLATE"
    git add -A
    git -c user.name=project-standards-pilot \
        -c user.email=project-standards-pilot@example.invalid \
        commit -qm "baseline template"
)

"$COPIER_COMMAND" copy "$TEMPLATE" "$PROJECT" \
    --defaults --trust --vcs-ref HEAD --quiet
[ -f "$PROJECT/.copier-answers.yml" ]

(
    cd "$PROJECT"
    git init -q
    git add -A
    git -c user.name=project-standards-pilot \
        -c user.email=project-standards-pilot@example.invalid \
        commit -qm "initial Copier render"
)

printf '\nThis project-owned note must survive template updates.\n' >> "$PROJECT/README.md"
printf 'project-owned pilot note\n' > "$PROJECT/PILOT-NOTES.md"
(
    cd "$PROJECT"
    git add README.md PILOT-NOTES.md
    git -c user.name=project-standards-pilot \
        -c user.email=project-standards-pilot@example.invalid \
        commit -qm "customize pilot project"
)

printf '\n- Copier updates are reviewed through the project gate.\n' >> "$TEMPLATE/AGENTS.md"
(
    cd "$TEMPLATE"
    git add AGENTS.md
    git -c user.name=project-standards-pilot \
        -c user.email=project-standards-pilot@example.invalid \
        commit -qm "update template guidance"
)

"$COPIER_COMMAND" update "$PROJECT" \
    --defaults --trust --vcs-ref HEAD --quiet
grep -q 'This project-owned note must survive template updates.' "$PROJECT/README.md"
[ "$(cat "$PROJECT/PILOT-NOTES.md")" = "project-owned pilot note" ]
grep -q 'Copier updates are reviewed through the project gate.' "$PROJECT/AGENTS.md"
if grep -R -n -E '<<<<<<<|=======|>>>>>>>' "$PROJECT" >/dev/null; then
    echo "project-standards Copier pilot: unresolved conflict marker" >&2
    exit 1
fi

(
    cd "$PROJECT"
    git add -A
    git -c user.name=project-standards-pilot \
        -c user.email=project-standards-pilot@example.invalid \
        commit -qm "apply template update"
)
"$COPIER_COMMAND" update "$PROJECT" \
    --defaults --trust --vcs-ref HEAD --quiet
[ -z "$(cd "$PROJECT" && git status --short)" ]

if [ "${COPIER_PILOT_CHECK:-0}" = "1" ]; then
    command -v uv >/dev/null 2>&1 || {
        echo "project-standards Copier pilot: COPIER_PILOT_CHECK=1 requires uv" >&2
        exit 2
    }
    command -v just >/dev/null 2>&1 || {
        echo "project-standards Copier pilot: COPIER_PILOT_CHECK=1 requires just" >&2
        exit 2
    }
    command -v actionlint >/dev/null 2>&1 || {
        echo "project-standards Copier pilot: COPIER_PILOT_CHECK=1 requires actionlint" >&2
        exit 2
    }
    command -v zizmor >/dev/null 2>&1 || {
        echo "project-standards Copier pilot: COPIER_PILOT_CHECK=1 requires zizmor" >&2
        exit 2
    }
    (
        cd "$PROJECT"
        just lock
        just sync
        just check
    )
fi

echo "project-standards Copier pilot: customization survived update"
