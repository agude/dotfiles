#!/bin/bash
#
# Audit one repo against the project-standards conventions.
#
# Read-only: inspects files and git metadata, changes nothing. Exits 1 if any
# check FAILs so it can gate a loop over repos.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
POLICY="$SKILL_DIR/policy.toml"
# shellcheck source=policy.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/policy.sh"

PORCELAIN="false"
REPO=""
FAILURES=0
ARCHETYPE_OVERRIDE=""

usage() {
    cat <<'EOF'
Usage: audit.sh <repo-path> [--porcelain]

Checks a repo against the project-standards conventions and reports
PASS/WARN/FAIL per rule. Changes nothing.

Options:
  --porcelain   Tab-separated STATUS<TAB>CHECK<TAB>DETAIL, no colour
  --archetype N  Override conservative archetype detection.
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
        --archetype) [ $# -ge 2 ] || { usage >&2; exit 2; }; ARCHETYPE_OVERRIDE="$2"; shift 2 ;;
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
    local status="$1" check="$2" detail="$3" colour="" clean_detail
    clean_detail=$(printf '%s' "$detail" | tr '\t\n' '  ')
    [ "$status" = "FAIL" ] && FAILURES=$((FAILURES + 1))
    if [ "$PORCELAIN" = "true" ]; then
        printf '%s\t%s\t%s\n' "$status" "$check" "$clean_detail"
        return
    fi
    case "$status" in
        PASS) colour="$C_PASS" ;;
        WARN) colour="$C_WARN" ;;
        FAIL) colour="$C_FAIL" ;;
    esac
    printf '%s%-4s%s  %-22s  %s\n' "$colour" "$status" "$C_OFF" "$check" "$clean_detail"
}

has() { [ -e "$REPO/$1" ]; }

# A file that exists but is gitignored is invisible to everyone else.
is_ignored() { (cd "$REPO" && git check-ignore -q "$1" 2>/dev/null); }

is_tracked() { (cd "$REPO" && git ls-files --error-unmatch -- "$1" >/dev/null 2>&1); }

git_hooks_path() {
    (cd "$REPO" && git rev-parse --git-path hooks/pre-commit 2>/dev/null)
}

# A file may opt out of one check with an inline marker plus a reason:
#   # project-standards: allow ci-inline — running in a minimal container
# Permanent, justified exceptions belong here; a rule you merely have not got
# to yet should stay failing instead.
allows() {  # allows FILE CHECK
    local file="$1" check="$2"
    case "$check" in
        ci-inline|workflow-security|runner-contract) ;;
        *) return 1 ;;
    esac
    grep -Eq "^[[:space:]]*(#|<!--)?[[:space:]]*project-standards:[[:space:]]+allow[[:space:]]+${check}[[:space:]]+[—-][[:space:]]+[^[:space:]]" "$file" 2>/dev/null
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
    elif [ -f "$REPO/appsscript.json" ] || [ -f "$REPO/src/appsscript.json" ]; then
        echo "apps-script"
    elif [ -f "$REPO/pyproject.toml" ] && grep -q '^\[project\]' "$REPO/pyproject.toml" 2>/dev/null; then
        # No package and no suite means a script collection: it legitimately
        # has nothing for type-check, test, or a coverage gate to describe.
        if [ -d "$REPO/src" ] || [ -d "$REPO/tests" ]; then
            echo "python"
        else
            echo "scripts"
        fi
    elif [ -z "$RUNNER" ] && [ "$(find "$REPO" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.bash' -o -name '*.py' \) | wc -l | tr -d ' ')" = "1" ]; then
        echo "single-file"
    elif ls "$REPO"/*.sh >/dev/null 2>&1 || [ -d "$REPO/scripts" ]; then
        echo "shell"
    else
        echo "other"
    fi
}

RUNNER=$(runner_file)
if [ -n "$ARCHETYPE_OVERRIDE" ]; then
    case "$ARCHETYPE_OVERRIDE" in
        python|scripts|jekyll|shell|apps-script|single-file|other) ARCHETYPE="$ARCHETYPE_OVERRIDE" ;;
        *) echo "Unknown archetype: $ARCHETYPE_OVERRIDE" >&2; exit 2 ;;
    esac
else
    ARCHETYPE=$(detect_archetype)
fi

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
        report PASS docs.agents "AGENTS.md present"
    else
        report WARN docs.agents "no AGENTS.md"
    fi
}

recipe_exists() {
    local recipe="$1"
    if [ "$RUNNER" = "justfile" ] || [ "$RUNNER" = "Justfile" ]; then
        (cd "$REPO" && just --dump --dump-format json 2>/dev/null | jq -e --arg recipe "$recipe" '.recipes[$recipe] != null' >/dev/null)
    elif [ "$RUNNER" = "Makefile" ]; then
        grep -qE "^[[:alnum:]_.-]+[[:space:]]*:" "$REPO/$RUNNER" && grep -qE "^${recipe}[[:space:]]*:" "$REPO/$RUNNER"
    else
        return 1
    fi
}

recipe_dependencies() {
    local recipe="$1"
    (cd "$REPO" && just --dump --dump-format json 2>/dev/null |
        jq -r --arg recipe "$recipe" '.recipes[$recipe].dependencies[]?.recipe')
}

recipe_reaches() {
    local recipe="$1" wanted="$2" visited="$3" dependency
    [ "$recipe" = "$wanted" ] && return 0
    case " $visited " in
        *" $recipe "*) return 1 ;;
    esac
    visited="$visited $recipe"
    while IFS= read -r dependency; do
        [ -n "$dependency" ] || continue
        recipe_reaches "$dependency" "$wanted" "$visited" && return 0
    done <<EOF
$(recipe_dependencies "$recipe")
EOF
    return 1
}

check_runner_contract() {
    local category="$1" missing="" requirement
    case "$category" in
        python) requirement="lint type-check test package-check" ;;
        scripts|shell) requirement="lint" ;;
        *) return ;;
    esac
    for requirement in $requirement; do
        if ! recipe_reaches check "$requirement" ""; then
            missing="$missing $requirement"
        fi
    done
    if [ -n "$missing" ]; then
        report FAIL runner.contract "check does not reach:$missing"
    else
        report PASS runner.contract "check reaches required categories"
    fi
}

check_runner_verbs() {
    local file="$1" prefix="$2" required="$3" forbidden="$4"
    [ -n "$file" ] || { report FAIL runner.present "no justfile or Makefile"; return; }

    local missing="" verb
    for verb in $required; do
        recipe_exists "$verb" || missing="$missing $verb"
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
    local config=""
    for candidate in .pre-commit-config.yaml .pre-commit-config.yml; do
        [ -f "$REPO/$candidate" ] && { config="$candidate"; break; }
    done
    if [ -n "$config" ] && grep -qE 'entry:[[:space:]]*just[[:space:]]+(lint|check)' "$REPO/$config"; then
        report PASS hook.script "$config delegates to the runner"
    elif [ -z "$script" ]; then
        report WARN hook.script "no hook script or framework config ($*)"
        return
    elif grep -qE "$expected_call" "$REPO/$script"; then
        report PASS hook.script "$script calls the runner"
    else
        report FAIL hook.script "$script inlines commands instead of calling the runner"
    fi

    if is_ignored "$script"; then
        report FAIL hook.tracked "$script is gitignored — nobody else can ever get this hook"
    fi

    local installed
    installed=$(git_hooks_path || true)
    if [ -n "$installed" ] && [ -e "$installed" ]; then
        report PASS hook.installed "installed at $installed"
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
    local leaked="" waived="" f line found_inline workflow_name
    for f in "$dir"/*.y*ml; do
        [ -f "$f" ] || continue
        found_inline="false"
        workflow_name="${f#"$dir/"}"
        local workflow_code
        workflow_code=$(sed 's/[[:space:]]*#.*//' "$f")
        while IFS= read -r line; do
            case "$line" in
                *apt-get\ install*|*apk\ add*|*brew\ install*) continue ;;
            esac
            if printf '%s\n' "$line" | grep -qE '(^|[[:space:];|&])(ruff|mypy|pytest|yamllint|shellcheck|bats)([[:space:]]|$)'; then
                leaked="$leaked $workflow_name"
                found_inline="true"
                break
            fi
        done <<EOF
$workflow_code
EOF
        if [ "$found_inline" = "true" ] && allows "$f" "ci-inline"; then
            workflow_suffix=" $workflow_name"
            leaked="${leaked%"$workflow_suffix"}"
            waived="$waived $workflow_name"
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

    if command -v actionlint >/dev/null 2>&1; then
        local syntax_fail="" syntax_output
        for f in "$dir"/*.yml "$dir"/*.yaml; do
            [ -f "$f" ] || continue
            syntax_output="$(actionlint "$f" 2>&1)" || {
                syntax_fail="$syntax_fail ${f#"$dir/"}: $syntax_output"
            }
        done
        if [ -n "$syntax_fail" ]; then
            report FAIL ci.syntax "actionlint findings:$syntax_fail"
        else
            report PASS ci.syntax "actionlint accepted workflow syntax"
        fi
    else
        report WARN ci.syntax "actionlint unavailable; workflow syntax not established"
    fi

    # Pinned action versions (the table in SKILL.md is authoritative).
    local drift="" comment_missing="" action expected version
    while IFS='|' read -r action _ref expected version; do
        [ -n "$action" ] || continue
        while IFS= read -r actual; do
            [ -n "$actual" ] || continue
            [ "$actual" = "$expected" ] || drift="$drift $action@$actual"
        done < <(grep -rhoE "$action@[^[:space:]]+" "$dir" 2>/dev/null | sed "s|^$action@||" | sort -u)
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            case "$line" in
                *"# $version"*) ;;
                *) comment_missing="$comment_missing $action" ;;
            esac
        done < <(grep -rhE "$action@$expected([[:space:]]|$)" "$dir" 2>/dev/null | sort -u)
    done <<EOF
actions/checkout|$(policy_action "$POLICY" checkout)|$(policy_action "$POLICY" checkout)|$(policy_action_version "$POLICY" checkout)
astral-sh/setup-uv|$(policy_action "$POLICY" setup_uv)|$(policy_action "$POLICY" setup_uv)|$(policy_action_version "$POLICY" setup_uv)
extractions/setup-just|$(policy_action "$POLICY" setup_just)|$(policy_action "$POLICY" setup_just)|$(policy_action_version "$POLICY" setup_just)
actions/setup-python|$(policy_action "$POLICY" setup_python)|$(policy_action "$POLICY" setup_python)|$(policy_action_version "$POLICY" setup_python)
actions/upload-artifact|$(policy_action "$POLICY" upload_artifact)|$(policy_action "$POLICY" upload_artifact)|$(policy_action_version "$POLICY" upload_artifact)
actions/download-artifact|$(policy_action "$POLICY" download_artifact)|$(policy_action "$POLICY" download_artifact)|$(policy_action_version "$POLICY" download_artifact)
pypa/gh-action-pypi-publish|$(policy_action "$POLICY" pypi_publish)|$(policy_action "$POLICY" pypi_publish)|$(policy_action_version "$POLICY" pypi_publish)
EOF
    if [ -n "$drift" ]; then
        report WARN ci.pins "off-standard pins: $drift"
    else
        report PASS ci.pins "action versions match the pinned set"
    fi
    if [ -n "$comment_missing" ]; then
        report WARN ci.pin-comments "missing readable release comments:$comment_missing"
    else
        report PASS ci.pin-comments "action release comments match the pinned set"
    fi
}

# --- archetype checks -----------------------------------------------------

check_python() {
    check_runner_verbs "$RUNNER" "" "default sync lint format test check hooks-install" \
        "fmt lint-fix format-check"
    check_runner_contract python
    check_hook "just (lint|check)" "bin/pre-commit.sh"

    if has uv.lock; then
        if is_tracked uv.lock; then
            report PASS deps.lock "uv.lock tracked"
        elif is_ignored uv.lock; then
            report FAIL deps.lock "uv.lock exists but is gitignored"
        else
            report FAIL deps.lock "uv.lock exists but is untracked"
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

    local policy_floor policy_target policy_mypy
    policy_floor=$(policy_value "$POLICY" python floor)
    policy_target=$(policy_value "$POLICY" python ruff_target)
    policy_mypy=$(policy_value "$POLICY" python mypy_target)
    if greps pyproject.toml "requires-python[[:space:]]*=[[:space:]]*\">=$policy_floor"; then
        report PASS policy.python-floor "requires-python matches policy floor $policy_floor"
    else
        report FAIL policy.python-floor "requires-python does not match policy floor $policy_floor"
    fi
    if greps pyproject.toml "target-version[[:space:]]*=[[:space:]]*\"$policy_target\"" &&
       greps pyproject.toml "python_version[[:space:]]*=[[:space:]]*\"$policy_mypy\""; then
        report PASS policy.tool-targets "Ruff and mypy targets match policy"
    else
        report FAIL policy.tool-targets "Ruff or mypy target differs from policy"
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
    check_runner_contract scripts
    check_hook "just (lint|check)" "bin/pre-commit.sh"

    if greps pyproject.toml '^\[tool\.ruff\]'; then
        report PASS lint.config "ruff configured in pyproject.toml"
    else
        report FAIL lint.config "no [tool.ruff] in pyproject.toml"
    fi

    if has uv.lock && is_tracked uv.lock; then
        report PASS deps.lock "uv.lock tracked"
    elif has uv.lock && is_ignored uv.lock; then
        report FAIL deps.lock "uv.lock exists but is gitignored"
    elif has uv.lock; then
        report FAIL deps.lock "uv.lock exists but is untracked"
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

check_single_file() {
    report PASS archetype.single-file "single standalone file is exempt from runner requirements"
}

check_apps_script() {
    local manifest=""
    for candidate in src/appsscript.json appsscript.json; do
        if has "$candidate"; then
            manifest="$candidate"
            break
        fi
    done

    if [ -n "$manifest" ]; then
        report PASS apps-script.manifest "$manifest"
        if greps "$manifest" '"runtimeVersion"[[:space:]]*:[[:space:]]*"V8"'; then
            report PASS apps-script.runtime "V8 configured"
        else
            report WARN apps-script.runtime "no V8 runtime declaration"
        fi
    else
        report FAIL apps-script.manifest "no appsscript.json"
    fi

    local source_dir="."
    [ -d "$REPO/src" ] && source_dir="src"
    if find "$REPO/$source_dir" -maxdepth 1 -type f \( -name '*.js' -o -name '*.gs' \) | grep -q .; then
        report PASS apps-script.source "$source_dir contains Apps Script source"
    else
        report WARN apps-script.source "no .js or .gs source in $source_dir"
    fi

    if [ -d "$REPO/fixtures" ]; then
        report PASS apps-script.fixtures "fixtures directory present"
    else
        report WARN apps-script.fixtures "no fixtures directory; use anonymized examples when needed"
    fi

    if greps .gitignore '^\.clasp\.json$' && greps .gitignore '^\.clasprc\.json$'; then
        report PASS apps-script.credentials "clasp credentials are ignored"
    else
        report WARN apps-script.credentials "ignore .clasp.json and .clasprc.json before configuring clasp"
    fi

    local tracked_credentials=""
    if [ -d "$REPO/.git" ]; then
        tracked_credentials=$(cd "$REPO" && git ls-files -- .clasp.json .clasprc.json 2>/dev/null)
    fi
    if [ -n "$tracked_credentials" ]; then
        report FAIL apps-script.credentials "tracked credential files: $(tr '\n' ' ' <<<"$tracked_credentials")"
    fi

    if greps AGENTS.md 'run[A-Za-z0-9]*Tests'; then
        report PASS apps-script.tests "AGENTS.md documents an Apps Script test entry point"
    else
        report WARN apps-script.tests "document the Apps Script test entry point in AGENTS.md"
    fi
}

# --- run ------------------------------------------------------------------

case "$ARCHETYPE" in
    python) check_python; check_isolation; check_ci ;;
    scripts) check_scripts; check_isolation; check_ci ;;
    jekyll) check_jekyll; check_isolation; check_ci ;;
    shell)  check_shell; check_isolation; check_ci ;;
    single-file) check_single_file ;;
    apps-script) check_apps_script ;;
    *)      report WARN archetype "unrecognised repo shape; only doc checks run" ;;
esac
check_docs

[ "$PORCELAIN" = "true" ] || echo
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
