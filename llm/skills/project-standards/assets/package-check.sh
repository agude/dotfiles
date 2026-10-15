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
  --typed               Require PACKAGE/py.typed in the wheel.
EOF
    exit 2
}

ARTIFACTS=""
IMPORT_NAME=""
DISTRIBUTION_NAME=""
COMMAND_NAME=""
EXPECTED_VERSION=""
REQUIRE_TYPED="false"

while [ $# -gt 0 ]; do
    case "$1" in
        --artifacts) [ $# -ge 2 ] || usage; ARTIFACTS="$2"; shift 2 ;;
        --import) [ $# -ge 2 ] || usage; IMPORT_NAME="$2"; shift 2 ;;
        --distribution) [ $# -ge 2 ] || usage; DISTRIBUTION_NAME="$2"; shift 2 ;;
        --command) [ $# -ge 2 ] || usage; COMMAND_NAME="$2"; shift 2 ;;
        --version) [ $# -ge 2 ] || usage; EXPECTED_VERSION="$2"; shift 2 ;;
        --typed) REQUIRE_TYPED="true"; shift ;;
        -h|--help) usage ;;
        *) echo "package-check.sh: unknown option: $1" >&2; usage ;;
    esac
done

[ -n "$IMPORT_NAME" ] || { echo "package-check.sh: --import is required" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMP_ROOT=""
if [ -z "$ARTIFACTS" ]; then
    TEMP_ROOT="$(mktemp -d)"
    ARTIFACTS="$TEMP_ROOT/dist"
    mkdir -p "$ARTIFACTS"
    uv build --out-dir "$ARTIFACTS" >/dev/null
fi

cleanup() {
    [ -z "$TEMP_ROOT" ] || rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

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
python3 "$SCRIPT_DIR/read-distribution-metadata.py" "$wheel" "$sdist" > "$metadata"
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

if [ "$REQUIRE_TYPED" = "true" ]; then
    python3 "$SCRIPT_DIR/check-wheel-path.py" "$wheel" "$IMPORT_NAME/py.typed"
fi
python3 "$SCRIPT_DIR/check-archive-path.py" "$wheel" "$IMPORT_NAME/__init__.py"
python3 "$SCRIPT_DIR/check-archive-path.py" "$sdist" "$IMPORT_NAME/__init__.py"

venv="$(mktemp -d)"
check_root="$(mktemp -d)"
cleanup_all() { rm -f "$metadata"; rm -rf "$venv" "$check_root"; cleanup; }
trap cleanup_all EXIT
uv venv --quiet "$venv"
uv pip install --quiet --python "$venv/bin/python" "$wheel"

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

echo "package-check: validated $(basename "$wheel") and $(basename "$sdist")"
