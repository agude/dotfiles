#!/usr/bin/env bash
# scaffold.sh — Create a new Agent Skills directory structure.
#
# Usage: scaffold.sh <name> [--scripts] [--references] [--assets]
#
# Creates a skill directory with a SKILL.md stub and optional subdirectories.
# The directory is created relative to the current working directory.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: scaffold.sh <name> [--scripts] [--references] [--assets] [--dir <path>]

Create a new Agent Skills directory with a SKILL.md stub.

Arguments:
  name          Skill name (lowercase alphanumeric and hyphens, 1-64 chars)

Options:
  --scripts     Create a scripts/ subdirectory
  --references  Create a references/ subdirectory
  --assets      Create an assets/ subdirectory
  --dir <path>  Parent directory to create the skill in (default: $PWD)
  --help        Show this help message
EOF
}

validate_name() {
    local name="$1"

    if [[ ${#name} -lt 1 || ${#name} -gt 64 ]]; then
        echo "Error: name must be 1-64 characters (got ${#name})." >&2
        return 1
    fi

    if ! [[ "$name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
        echo "Error: name must contain only lowercase letters, numbers, and hyphens." >&2
        echo "       Must not start or end with a hyphen." >&2
        return 1
    fi

    if [[ "$name" == *--* ]]; then
        echo "Error: name must not contain consecutive hyphens (--)." >&2
        return 1
    fi
}

# --- Parse arguments ---

if [[ $# -lt 1 ]]; then
    usage >&2
    exit 1
fi

NAME=""
MAKE_SCRIPTS=false
MAKE_REFERENCES=false
MAKE_ASSETS=false
PARENT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scripts)    MAKE_SCRIPTS=true;    shift ;;
        --references) MAKE_REFERENCES=true; shift ;;
        --assets)     MAKE_ASSETS=true;     shift ;;
        --dir)
            if [[ $# -lt 2 ]]; then
                echo "Error: --dir requires a path argument." >&2
                exit 1
            fi
            PARENT_DIR="$2"
            shift 2
            ;;
        --help)       usage; exit 0 ;;
        -*)           echo "Error: unknown option: $1" >&2; exit 1 ;;
        *)
            if [[ -n "$NAME" ]]; then
                echo "Error: unexpected argument: $1" >&2
                exit 1
            fi
            NAME="$1"
            shift
            ;;
    esac
done

if [[ -z "$NAME" ]]; then
    echo "Error: name is required." >&2
    exit 1
fi

validate_name "$NAME"

# Convert name to title case for the heading: "my-skill" -> "My Skill"
TITLE=$(echo "$NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

# --- Create structure ---

if [[ -n "$PARENT_DIR" ]]; then
    if [[ ! -d "$PARENT_DIR" ]]; then
        echo "Error: directory '$PARENT_DIR' does not exist." >&2
        exit 1
    fi
    SKILL_DIR="${PARENT_DIR}/${NAME}"
else
    SKILL_DIR="$NAME"
fi

if [[ -d "$SKILL_DIR" ]]; then
    echo "Error: directory '$SKILL_DIR' already exists." >&2
    exit 1
fi

mkdir -p "$SKILL_DIR"

if $MAKE_SCRIPTS; then
    BASEDIR_LINE=$'\n**Skill base directory:** `{baseDir}`\n'
else
    BASEDIR_LINE=""
fi

cat > "${SKILL_DIR}/SKILL.md" <<STUB
---
name: ${NAME}
description: TODO — describe what this skill does and when to use it.
---

# ${TITLE}
${BASEDIR_LINE}
TODO: Write skill instructions here.
STUB

$MAKE_SCRIPTS    && mkdir -p "${SKILL_DIR}/scripts"
$MAKE_REFERENCES && mkdir -p "${SKILL_DIR}/references"
$MAKE_ASSETS     && mkdir -p "${SKILL_DIR}/assets"

echo "Created skill: $(cd "$SKILL_DIR" && pwd)"
