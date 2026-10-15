#!/usr/bin/env bash
# Validate built distributions without importing from the source checkout.

set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: package-check.sh --import PACKAGE [options]

Options:
  --artifacts DIR       Validate artifacts already in DIR.
  --import NAME         Import this package from the installed wheel.
  --distribution NAME   Expected distribution name.
  --command NAME        Console command to invoke after installation.
  --version VERSION     Expected package version.
  --license PATH        Require PATH in both distributions.
  --typed               Require PACKAGE/py.typed in the wheel.
EOF
    exit 2
}

ARTIFACTS=""
IMPORT_NAME=""
DISTRIBUTION_NAME=""
COMMAND_NAME=""
EXPECTED_VERSION=""
LICENSE_FILE=""
REQUIRE_TYPED="false"

while [ $# -gt 0 ]; do
    case "$1" in
        --artifacts) [ $# -ge 2 ] || usage; ARTIFACTS="$2"; shift 2 ;;
        --import) [ $# -ge 2 ] || usage; IMPORT_NAME="$2"; shift 2 ;;
        --distribution) [ $# -ge 2 ] || usage; DISTRIBUTION_NAME="$2"; shift 2 ;;
        --command) [ $# -ge 2 ] || usage; COMMAND_NAME="$2"; shift 2 ;;
        --version) [ $# -ge 2 ] || usage; EXPECTED_VERSION="$2"; shift 2 ;;
        --license) [ $# -ge 2 ] || usage; LICENSE_FILE="$2"; shift 2 ;;
        --typed) REQUIRE_TYPED="true"; shift ;;
        -h|--help) usage ;;
        *) echo "package-check.sh: unknown option: $1" >&2; usage ;;
    esac
done

[ -n "$IMPORT_NAME" ] || { echo "package-check.sh: --import is required" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMP_ROOT=""
HELPER_CACHE="$(mktemp -d)"

cleanup() {
    [ -z "$TEMP_ROOT" ] || rm -rf "$TEMP_ROOT"
    rm -rf "$HELPER_CACHE"
}
trap cleanup EXIT

run_helper() {
    UV_CACHE_DIR="$HELPER_CACHE" uv run --no-project python "$@"
}

if [ -z "$ARTIFACTS" ]; then
    TEMP_ROOT="$(mktemp -d)"
    ARTIFACTS="$TEMP_ROOT/dist"
    mkdir -p "$ARTIFACTS"
    uv build --out-dir "$ARTIFACTS" >/dev/null
fi

wheel=""
sdist=""
for artifact in "$ARTIFACTS"/*; do
    [ -f "$artifact" ] || continue
    case "$artifact" in
        *.whl) [ -z "$wheel" ] || { echo "package-check: multiple wheels in $ARTIFACTS" >&2; exit 1; }; wheel="$artifact" ;;
        *.tar.gz) [ -z "$sdist" ] || { echo "package-check: multiple sdists in $ARTIFACTS" >&2; exit 1; }; sdist="$artifact" ;;
        *) echo "package-check: unexpected artifact: $(basename "$artifact")" >&2; exit 1 ;;
    esac
done
[ -n "$wheel" ] || { echo "package-check: no wheel found in $ARTIFACTS" >&2; exit 1; }
[ -n "$sdist" ] || { echo "package-check: no sdist found in $ARTIFACTS" >&2; exit 1; }

metadata="$(mktemp)"
sdist_metadata="$(mktemp)"
sdist_root=""
sdist_dist=""
sdist_wheel=""
venv=""
check_root=""
cleanup_all() {
    rm -f "$metadata" "$sdist_metadata"
    [ -z "$sdist_root" ] || rm -rf "$sdist_root"
    [ -z "$sdist_dist" ] || rm -rf "$sdist_dist"
    [ -z "$venv" ] || rm -rf "$venv"
    [ -z "$check_root" ] || rm -rf "$check_root"
    cleanup
}
trap cleanup_all EXIT

run_helper "$SCRIPT_DIR/read-distribution-metadata.py" "$wheel" "$sdist" > "$metadata"
normalize_name() { printf '%s' "$1" | tr '[:upper:]_' '[:lower:]-'; }

distribution="$(awk -F= '$1 == "Name" {print $2; exit}' "$metadata")"
version="$(awk -F= '$1 == "Version" {print $2; exit}' "$metadata")"
wheel_distribution="$(awk -F= '$1 == "Wheel-Name" {print $2; exit}' "$metadata")"
wheel_version="$(awk -F= '$1 == "Wheel-Version" {print $2; exit}' "$metadata")"

if [ -n "$DISTRIBUTION_NAME" ] && [ "$(normalize_name "$distribution")" != "$(normalize_name "$DISTRIBUTION_NAME")" ]; then
    echo "package-check: metadata distribution '$distribution' != '$DISTRIBUTION_NAME'" >&2
    exit 1
fi
if [ -n "$EXPECTED_VERSION" ] && [ "$version" != "$EXPECTED_VERSION" ]; then
    echo "package-check: metadata version '$version' != '$EXPECTED_VERSION'" >&2
    exit 1
fi
[ "$wheel_distribution" = "$distribution" ] || { echo "package-check: wheel and sdist names disagree" >&2; exit 1; }
[ "$wheel_version" = "$version" ] || { echo "package-check: wheel and sdist versions disagree" >&2; exit 1; }

sdist_root="$(mktemp -d)"
sdist_dist="$(mktemp -d)"
tar -xzf "$sdist" -C "$sdist_root" --strip-components=1
[ -f "$sdist_root/pyproject.toml" ] || {
    echo "package-check: sdist has no pyproject.toml for a rebuild" >&2
    exit 1
}
(
    cd "$sdist_root"
    UV_CACHE_DIR="$HELPER_CACHE" uv build --wheel --out-dir "$sdist_dist" >/dev/null
)
for artifact in "$sdist_dist"/*.whl; do
    [ -f "$artifact" ] || continue
    [ -z "$sdist_wheel" ] || { echo "package-check: multiple wheels built from $sdist" >&2; exit 1; }
    sdist_wheel="$artifact"
done
[ -n "$sdist_wheel" ] || { echo "package-check: sdist rebuild produced no wheel" >&2; exit 1; }
run_helper "$SCRIPT_DIR/read-distribution-metadata.py" "$sdist_wheel" "$sdist" > "$sdist_metadata"
sdist_wheel_distribution="$(awk -F= '$1 == "Wheel-Name" {print $2; exit}' "$sdist_metadata")"
sdist_wheel_version="$(awk -F= '$1 == "Wheel-Version" {print $2; exit}' "$sdist_metadata")"
[ "$sdist_wheel_distribution" = "$distribution" ] || {
    echo "package-check: sdist-built wheel name '$sdist_wheel_distribution' != '$distribution'" >&2
    exit 1
}
[ "$sdist_wheel_version" = "$version" ] || {
    echo "package-check: sdist-built wheel version '$sdist_wheel_version' != '$version'" >&2
    exit 1
}

check_wheel_contents() {
    local candidate="$1" label="$2"
    if [ "$REQUIRE_TYPED" = "true" ]; then
        run_helper "$SCRIPT_DIR/check-wheel-path.py" "$candidate" "$IMPORT_NAME/py.typed" || {
            echo "package-check: $label is missing the typed marker" >&2
            return 1
        }
    fi
    run_helper "$SCRIPT_DIR/check-archive-path.py" "$candidate" "$IMPORT_NAME/__init__.py"
    if [ -n "$LICENSE_FILE" ]; then
        run_helper "$SCRIPT_DIR/check-archive-path.py" "$candidate" "$LICENSE_FILE"
    fi
}

check_wheel_contents "$wheel" "source wheel"
check_wheel_contents "$sdist_wheel" "sdist-built wheel"
run_helper "$SCRIPT_DIR/check-archive-path.py" "$sdist" "$IMPORT_NAME/__init__.py"
if [ -n "$LICENSE_FILE" ]; then
    run_helper "$SCRIPT_DIR/check-archive-path.py" "$sdist" "$LICENSE_FILE"
fi

check_root="$(mktemp -d)"
validate_install() {
    local candidate="$1" label="$2"
    venv="$(mktemp -d)"
    uv venv --quiet "$venv"
    uv pip install --quiet --python "$venv/bin/python" "$candidate"
    (
        cd "$check_root"
        PYTHONPATH="" "$venv/bin/python" - "$IMPORT_NAME" "$version" <<'PY'
import importlib
import sys

module = importlib.import_module(sys.argv[1])
location = getattr(module, "__file__", "") or ""
if not location.startswith(sys.prefix):
    raise SystemExit(f"package-check: imported {sys.argv[1]} from {location!r}, not {sys.prefix!r}")
if getattr(module, "__version__", None) != sys.argv[2]:
    raise SystemExit("package-check: installed __version__ does not match metadata")
print(f"package-check: imported {sys.argv[1]} from {location}")
PY
        if [ -n "$COMMAND_NAME" ]; then
            "$venv/bin/$COMMAND_NAME" --help >/dev/null
        fi
    )
    rm -rf "$venv"
    venv=""
    echo "package-check: installed $label successfully"
}

validate_install "$wheel" "$(basename "$wheel")"
validate_install "$sdist_wheel" "$(basename "$sdist_wheel")"

echo "package-check: validated $(basename "$wheel"), $(basename "$sdist"), and the sdist-built wheel"
