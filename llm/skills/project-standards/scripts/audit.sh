#!/bin/bash
#
# Audit one repo against the project-standards conventions.
#
# Read-only: inspects files and git metadata, changes nothing. Exits 1 if any
# check FAILs so it can gate a loop over repos.

set -uo pipefail

PORCELAIN="false"
REPO=""
FAILURES=0

usage() {
    cat <<'EOF'
Usage: audit.sh <repo-path> [--porcelain]

Checks a repo against the project-standards conventions and reports
PASS/WARN/FAIL per rule. Changes nothing.

Options:
  --porcelain   Tab-separated STATUS<TAB>CHECK<TAB>DETAIL, no colour
  -h, --help    Show this help

Exit status:
  0  no FAILs (WARNs are allowed)
  1  at least one FAIL
  2  usage error
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --porcelain) PORCELAIN="true"; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
        *) REPO="$1"; shift ;;
    esac
done

[ -n "$REPO" ] || { usage >&2; exit 2; }
[ -d "$REPO" ] || { echo "Not a directory: $REPO" >&2; exit 2; }
REPO=$(cd "$REPO" && pwd)

if [ "$PORCELAIN" = "true" ] || [ ! -t 1 ]; then
    C_PASS=""; C_WARN=""; C_FAIL=""; C_OFF=""
else
    C_PASS=$'\033[32m'; C_WARN=$'\033[33m'; C_FAIL=$'\033[31m'; C_OFF=$'\033[0m'
fi

report() {  # report STATUS CHECK DETAIL
    local status="$1" check="$2" detail="$3" colour=""
    [ "$status" = "FAIL" ] && FAILURES=$((FAILURES + 1))
    if [ "$PORCELAIN" = "true" ]; then
        printf '%s\t%s\t%s\n' "$status" "$check" "$detail"
        return
    fi
    case "$status" in
        PASS) colour="$C_PASS" ;;
        WARN) colour="$C_WARN" ;;
        FAIL) colour="$C_FAIL" ;;
    esac
    printf '%s%-4s%s  %-22s  %s\n' "$colour" "$status" "$C_OFF" "$check" "$detail"
}

has() { [ -e "$REPO/$1" ]; }

# A file that exists but is gitignored is invisible to everyone else.
is_ignored() { (cd "$REPO" && git check-ignore -q "$1" 2>/dev/null); }

# A file may opt out of one check with an inline marker plus a reason:
#   # project-standards: allow ci-inline — running in a minimal container
# Permanent, justified exceptions belong here; a rule you merely have not got
# to yet should stay failing instead.
allows() {  # allows FILE CHECK
    grep -q "project-standards: allow $2" "$1" 2>/dev/null
}

# Grep a file in the repo, quietly.
greps() {  # greps FILE PATTERN
    [ -f "$REPO/$1" ] && grep -qE "$2" "$REPO/$1" 2>/dev/null
}

runner_file() {
    for f in justfile Justfile Makefile; do
        [ -f "$REPO/$f" ] && { echo "$f"; return; }
    done
    echo ""
}

# --- archetype detection --------------------------------------------------

detect_archetype() {
    # Order matters: an Ansible repo may carry a pyproject.toml purely to let
    # uv manage ansible-lint, which does not make it a Python package.
    if [ -f "$REPO/_config.yml" ] && [ -f "$REPO/Gemfile" ]; then
        echo "jekyll"
    elif [ -f "$REPO/ansible.cfg" ] || [ -f "$REPO/site.yaml" ]; then
        echo "shell"
    elif [ -f "$REPO/pyproject.toml" ] && grep -q '^\[project\]' "$REPO/pyproject.toml" 2>/dev/null; then
        # No package and no suite means a script collection: it legitimately
        # has nothing for type-check, test, or a coverage gate to describe.
        if [ -d "$REPO/src" ] || [ -d "$REPO/tests" ]; then
            echo "python"
        else
            echo "scripts"
        fi
    elif ls "$REPO"/*.sh >/dev/null 2>&1 || [ -d "$REPO/scripts" ]; then
        echo "shell"
    else
        echo "other"
    fi
}

ARCHETYPE=$(detect_archetype)
RUNNER=$(runner_file)

if [ "$PORCELAIN" = "true" ]; then
    printf 'INFO\tarchetype\t%s\n' "$ARCHETYPE"
    printf 'INFO\trunner\t%s\n' "${RUNNER:-none}"
else
    printf '\n%s  [%s, runner: %s]\n\n' "$REPO" "$ARCHETYPE" "${RUNNER:-none}"
fi

# --- shared checks --------------------------------------------------------

check_docs() {
    if has README.md; then
        report PASS docs.readme "README.md present"
    else
        report WARN docs.readme "no README.md"
    fi

    # Licensing is the owner's decision, not a tooling one: the audit reports
    # what is there and never pushes toward a particular choice, spelling, or
    # adding one where none exists.
    local licence=""
    for candidate in "$REPO"/[Ll][Ii][Cc][Ee][Nn][SsCc]E*; do
        [ -f "$candidate" ] && { licence=$(basename "$candidate"); break; }
    done
    if [ -n "$licence" ]; then
        report PASS docs.license "$licence"
    else
        report PASS docs.license "none — the owner's call"
    fi

    if has AGENTS.md; then
        local detail="AGENTS.md canonical"
        for f in CLAUDE.md GEMINI.md; do
            if has "$f" && [ ! -L "$REPO/$f" ]; then
                detail="$detail; $f is a real file, not a symlink"
            fi
        done
        case "$detail" in
            *symlink*) report WARN docs.agents "$detail" ;;
            *) report PASS docs.agents "$detail" ;;
        esac
    elif has CLAUDE.md; then
        report WARN docs.agents "bare CLAUDE.md — rename to AGENTS.md and symlink"
    else
        report WARN docs.agents "no AGENTS.md"
    fi
}

check_runner_verbs() {
    local file="$1" prefix="$2" required="$3" forbidden="$4"
    [ -n "$file" ] || { report FAIL runner.present "no justfile or Makefile"; return; }

    local missing="" verb
    for verb in $required; do
        grep -qE "^${prefix}${verb}( |:)" "$REPO/$file" || missing="$missing $verb"
    done
    if [ -n "$missing" ]; then
        report FAIL runner.verbs "missing:$missing"
    else
        report PASS runner.verbs "all required recipes present"
    fi

    local stale="" bad
    for bad in $forbidden; do
        grep -qE "^${bad}( |:)" "$REPO/$file" && stale="$stale $bad"
    done
    [ -n "$stale" ] && report FAIL runner.legacy "retired verb names:$stale"

    # Where ruff is the linter, lint must be total: check AND format --check.
    # Repos linting only shell or YAML have no formatter, so the rule is moot.
    if grep -qE "^${prefix}lint( |:)" "$REPO/$file"; then
        local body
        body=$(awk "/^${prefix}lint( |:)/{flag=1;next}/^[a-zA-Z]/{flag=0}flag" "$REPO/$file")
        if printf '%s' "$body" | grep -q "ruff"; then
            if printf '%s' "$body" | grep -q "format --check"; then
                report PASS runner.lint "lint includes the format check"
            else
                report FAIL runner.lint "lint omits 'ruff format --check' — it must be total"
            fi
        fi
    fi
}

# check_hook CALL_PATTERN SCRIPT...   — reports on the first script that exists
check_hook() {
    local expected_call="$1"; shift
    local script=""
    for candidate in "$@"; do
        [ -f "$REPO/$candidate" ] && { script="$candidate"; break; }
    done
    if [ -z "$script" ]; then
        report WARN hook.script "no hook script ($*)"
        return
    fi
    if grep -qE "$expected_call" "$REPO/$script"; then
        report PASS hook.script "$script calls the runner"
    else
        report FAIL hook.script "$script inlines commands instead of calling the runner"
    fi

    if is_ignored "$script"; then
        report FAIL hook.tracked "$script is gitignored — nobody else can ever get this hook"
    fi

    if [ -e "$REPO/.git/hooks/pre-commit" ]; then
        report PASS hook.installed "installed in this clone"
    else
        report WARN hook.installed "not installed here — run the hooks-install recipe"
    fi
}

# Everything Python must run through uv. Bare interpreters and pip installs
# depend on whatever happens to be on PATH, which is how a hook here came to
# call a `ruff` that did not exist.
check_isolation() {
    local files=() f
    for f in justfile Justfile Makefile bin/pre-commit.sh _bin/pre-commit.sh \
             _scripts/pre-commit-hook.sh; do
        [ -f "$REPO/$f" ] && files+=("$REPO/$f")
    done
    [ -d "$REPO/.github/workflows" ] && while IFS= read -r f; do files+=("$f"); done \
        < <(find "$REPO/.github/workflows" -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \))
    [ ${#files[@]} -gt 0 ] || return

    local pips="" bare="" f
    for f in "${files[@]}"; do
        # Strip comments first: prose about pip or python is not an invocation.
        local code
        code=$(sed 's/#.*//' "$f")
        if grep -qE '(^|[^v] )pip install|uv pip install --system' <<<"$code"; then
            pips="$pips ${f#"$REPO/"}"
        fi
        # A Python tool invoked at the start of a recipe or step, no uv in front.
        if grep -qE '^[[:space:]]*(run: )?(python3?|ruff|mypy|pytest) ' <<<"$code"; then
            bare="$bare ${f#"$REPO/"}"
        fi
    done

    if [ -n "$pips" ]; then
        report FAIL deps.isolation "pip install / --system in:$pips"
    elif [ -n "$bare" ]; then
        report FAIL deps.isolation "bare interpreter or tool (no uv run/uvx) in:$bare"
    else
        report PASS deps.isolation "everything Python runs through uv"
    fi
}

check_ci() {
    local dir="$REPO/.github/workflows"
    if [ ! -d "$dir" ]; then
        report WARN ci.present "no workflows"
        return
    fi
    local workflows
    workflows=$(find "$dir" -maxdepth 1 -name '*.yml' -o -maxdepth 1 -name '*.yaml' | sed "s|$dir/||" | sort | tr '\n' ' ')
    report PASS ci.present "$workflows"

    # CI must call runner verbs, not tools directly. With no runner there is
    # nothing to call, so say that rather than passing the repo by default.
    local leaked="" waived="" f
    for f in "$dir"/*.y*ml; do
        [ -f "$f" ] || continue
        grep -qE "run:.*(ruff|mypy|pytest|yamllint|shellcheck|bats)" "$f" || continue
        if allows "$f" "ci-inline"; then
            waived="$waived ${f#"$dir/"}"
        else
            leaked="$leaked ${f#"$dir/"}"
        fi
    done
    [ -n "$waived" ] && report PASS ci.waived "documented ci-inline exception:$waived"
    if [ -z "$RUNNER" ]; then
        report WARN ci.callsrunner "no runner for CI to call"
    elif [ -n "$leaked" ]; then
        report FAIL ci.callsrunner "tool commands inlined in:$leaked"
    else
        report PASS ci.callsrunner "steps call runner verbs"
    fi

    # Pinned action versions (the table in SKILL.md is authoritative).
    local drift
    drift=$( {
        grep -rhoE "actions/checkout@v[0-9]+" "$dir" 2>/dev/null | grep -v "@v7$"
        grep -rhoE "astral-sh/setup-uv@v?[0-9.]+" "$dir" 2>/dev/null | grep -vE "@v9\.0\.0$"
        grep -rhoE "actions/setup-python@v[0-9]+" "$dir" 2>/dev/null | grep -v "@v6$"
    } | sort -u | tr '\n' ' ')
    if [ -n "$drift" ]; then
        report WARN ci.pins "off-standard pins: $drift"
    else
        report PASS ci.pins "action versions match the pinned set"
    fi
}

# --- archetype checks -----------------------------------------------------

check_python() {
    check_runner_verbs "$RUNNER" "" "default sync lint format test check hooks-install" \
        "fmt lint-fix format-check"
    check_hook "just (lint|check)" "bin/pre-commit.sh"

    if has uv.lock; then
        if greps .gitignore '^uv\.lock'; then
            report FAIL deps.lock "uv.lock is gitignored — CI resolves fresh every run"
        else
            report PASS deps.lock "uv.lock committed"
        fi
    else
        report WARN deps.lock "no uv.lock"
    fi

    if greps pyproject.toml '^\[tool\.ruff\]'; then
        report PASS lint.config "ruff configured in pyproject.toml"
    else
        report FAIL lint.config "no [tool.ruff] in pyproject.toml"
    fi

    if [ -d "$REPO/src" ]; then
        if greps pyproject.toml '^\[tool\.mypy\]'; then
            report PASS types.mypy "mypy configured"
        else
            report FAIL types.mypy "src/ package without a [tool.mypy] section"
        fi
        if greps pyproject.toml 'cov-fail-under'; then
            report PASS test.coverage "coverage gate set"
        else
            report WARN test.coverage "no --cov-fail-under gate"
        fi
    fi

    if has .python-version && is_ignored .python-version; then
        report FAIL python.version ".python-version exists but is gitignored"
    elif has .python-version; then
        report PASS python.version "$(tr -d '\n' < "$REPO/.python-version")"
    else
        report WARN python.version "no .python-version"
    fi

    # Version should have exactly one home.
    if greps pyproject.toml '^\[tool\.bumpversion\]'; then
        report WARN version.source "bump-my-version config — standard is hatch dynamic version"
    elif greps pyproject.toml '^dynamic = \[.*version'; then
        report PASS version.source "dynamic from __init__.py"
    elif greps pyproject.toml '^version = '; then
        report WARN version.source "static version string in pyproject.toml"
    fi
}

check_scripts() {
    check_runner_verbs "$RUNNER" "" "default sync lint format check hooks-install" \
        "fmt lint-fix format-check"
    check_hook "just (lint|check)" "bin/pre-commit.sh"

    if greps pyproject.toml '^\[tool\.ruff\]'; then
        report PASS lint.config "ruff configured in pyproject.toml"
    else
        report FAIL lint.config "no [tool.ruff] in pyproject.toml"
    fi

    if has uv.lock && greps .gitignore '^uv\.lock'; then
        report FAIL deps.lock "uv.lock is gitignored"
    elif has uv.lock; then
        report PASS deps.lock "uv.lock committed"
    fi
}

check_jekyll() {
    check_runner_verbs "$RUNNER" "" "lint-scripts format-scripts" ""
    check_hook "(uv run|make|just)" "_bin/pre-commit.sh" "_scripts/pre-commit-hook.sh"

    local cfg=""
    [ -f "$REPO/ruff.toml" ] && cfg="ruff.toml"
    [ -f "$REPO/_scripts/pyproject.toml" ] && grep -q '\[tool\.ruff\]' "$REPO/_scripts/pyproject.toml" 2>/dev/null && cfg="_scripts/pyproject.toml"
    if [ -z "$cfg" ]; then
        report FAIL lint.config "no ruff config"
    elif grep -q '"\*\.md"' "$REPO/$cfg"; then
        report PASS lint.config "$cfg excludes *.md"
    else
        report FAIL lint.config "$cfg does not exclude *.md — ruff will reformat published prose"
    fi
}

check_shell() {
    check_runner_verbs "$RUNNER" "" "default lint" "fmt lint-fix format-check"
    check_hook "just (lint|check)" "bin/pre-commit.sh"
}

# --- run ------------------------------------------------------------------

case "$ARCHETYPE" in
    python) check_python; check_isolation; check_ci ;;
    scripts) check_scripts; check_isolation; check_ci ;;
    jekyll) check_jekyll; check_isolation; check_ci ;;
    shell)  check_shell; check_isolation; check_ci ;;
    *)      report WARN archetype "unrecognised repo shape; only doc checks run" ;;
esac
check_docs

[ "$PORCELAIN" = "true" ] || echo
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
