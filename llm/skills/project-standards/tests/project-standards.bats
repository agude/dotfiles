#!/usr/bin/env bats

setup() {
    TEST_ROOT="$(mktemp -d)"
    SKILL_ROOT="${BATS_TEST_DIRNAME%/tests}"
    SCAFFOLD="$SKILL_ROOT/scripts/scaffold.sh"
    AUDIT="$SKILL_ROOT/scripts/audit.sh"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

init_git() {
    (cd "$1" && git init -q)
}

@test "library scaffolding is offline and omits the publish workflow" {
    mkdir "$TEST_ROOT/bin"
    cat > "$TEST_ROOT/bin/uv" <<'EOF'
#!/bin/sh
echo "uv must not run during offline generation" >&2
exit 99
EOF
    chmod +x "$TEST_ROOT/bin/uv"

    run env PATH="$TEST_ROOT/bin:$PATH" bash "$SCAFFOLD" "$TEST_ROOT/library" sample_package
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_ROOT/library/uv.lock" ]
    [ ! -e "$TEST_ROOT/library/.github/workflows/release.yml" ]
    ! grep -R -E 'PACKAGE|REPO|PYTHON_|ACTION' "$TEST_ROOT/library"
}

@test "policy check rejects stale documented consumers" {
    cp -R "$SKILL_ROOT" "$TEST_ROOT/policy-skill"
    sed 's/3\.11 through 3\.15/3.10 through 3.15/' \
        "$TEST_ROOT/policy-skill/SKILL.md" > "$TEST_ROOT/policy-skill/SKILL.md.new"
    mv "$TEST_ROOT/policy-skill/SKILL.md.new" "$TEST_ROOT/policy-skill/SKILL.md"
    run bash "$TEST_ROOT/policy-skill/scripts/policy-check.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"SKILL.md is stale for the Python support range"* ]]
}

@test "CLI scaffolding preserves separate import, distribution, and command names" {
    run bash "$SCAFFOLD" "$TEST_ROOT/cli" import_name \
        --kind cli --distribution-name distribution-name --command-name run-tool --publish
    [ "$status" -eq 0 ]
    grep -q 'name = "distribution-name"' "$TEST_ROOT/cli/pyproject.toml"
    grep -q 'run-tool = "import_name.cli:main"' "$TEST_ROOT/cli/pyproject.toml"
    grep -q 'name: Release' "$TEST_ROOT/cli/.github/workflows/release.yml"
    grep -q 'def main' "$TEST_ROOT/cli/src/import_name/cli.py"
    ! grep -R -E 'PACKAGE|REPO|PYTHON_|ACTION' "$TEST_ROOT/cli"
}

@test "generated package checks preserve their command option variable" {
    run bash "$SCAFFOLD" "$TEST_ROOT/library" sample_package
    [ "$status" -eq 0 ]
    grep -q '^COMMAND_NAME=""$' "$TEST_ROOT/library/scripts/package-check.sh"
    grep -q 'if \[\[ -n "" \]\]; then' "$TEST_ROOT/library/justfile"

    run bash "$SCAFFOLD" "$TEST_ROOT/cli" sample_cli --kind cli --command-name run-tool
    [ "$status" -eq 0 ]
    grep -q '^COMMAND_NAME=""$' "$TEST_ROOT/cli/scripts/package-check.sh"
    grep -q 'package_args+=(--command "run-tool")' "$TEST_ROOT/cli/justfile"
}

@test "CI matrix consumes the single validated artifact set" {
    run bash "$SCAFFOLD" "$TEST_ROOT/published" sample_package --publish
    [ "$status" -eq 0 ]
    grep -q 'needs: lint$' "$TEST_ROOT/published/.github/workflows/ci.yml"
    grep -q 'needs: \[lint, build\]' "$TEST_ROOT/published/.github/workflows/ci.yml"
    grep -q 'name: sample-package-distributions' "$TEST_ROOT/published/.github/workflows/ci.yml"
    [ "$(grep -c 'name: sample-package-distributions' "$TEST_ROOT/published/.github/workflows/ci.yml")" -eq 2 ]
    grep -q 'run: just package-check dist' "$TEST_ROOT/published/.github/workflows/ci.yml"
    [ -f "$TEST_ROOT/published/scripts/validate-release.sh" ]
    grep -q 'scripts/validate-release.sh' "$TEST_ROOT/published/.github/workflows/ci.yml"
    grep -Fq 'uv tool dir --bin >> "$GITHUB_PATH"' \
        "$TEST_ROOT/published/.github/workflows/ci.yml"
    grep -q 'actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093 # v4' \
        "$TEST_ROOT/published/.github/workflows/ci.yml"
    grep -q 'path: dist' "$TEST_ROOT/published/.github/workflows/ci.yml"
}

@test "scaffold refuses a nonempty destination without changing it" {
    mkdir "$TEST_ROOT/existing"
    printf 'keep\n' > "$TEST_ROOT/existing/owned.txt"
    run bash "$SCAFFOLD" "$TEST_ROOT/existing" package_name
    [ "$status" -ne 0 ]
    [ "$(cat "$TEST_ROOT/existing/owned.txt")" = keep ]
    [ ! -e "$TEST_ROOT/existing/pyproject.toml" ]
}

@test "scaffolders refuse symbolic-link destinations" {
    mkdir "$TEST_ROOT/python-target" "$TEST_ROOT/apps-target"
    ln -s "$TEST_ROOT/python-target" "$TEST_ROOT/python-link"
    ln -s "$TEST_ROOT/apps-target" "$TEST_ROOT/apps-link"

    run bash "$SCAFFOLD" "$TEST_ROOT/python-link" sample_package
    [ "$status" -ne 0 ]
    [[ "$output" == *"must not be a symbolic link"* ]]
    [ ! -e "$TEST_ROOT/python-target/pyproject.toml" ]

    run bash "$SKILL_ROOT/scripts/scaffold-apps-script.sh" "$TEST_ROOT/apps-link" Example
    [ "$status" -ne 0 ]
    [[ "$output" == *"must not be a symbolic link"* ]]
    [ ! -e "$TEST_ROOT/apps-target/src" ]
}

@test "scaffold rejects invalid usage before creating output" {
    run bash "$SCAFFOLD" "$TEST_ROOT/unknown" package_name --unknown
    [ "$status" -ne 0 ]
    [ ! -e "$TEST_ROOT/unknown" ]
    run bash "$SCAFFOLD" "$TEST_ROOT/invalid" 'not-a-package'
    [ "$status" -ne 0 ]
    [ ! -e "$TEST_ROOT/invalid" ]
}

@test "bootstrap failure leaves generated files for recovery" {
    mkdir "$TEST_ROOT/bin"
    cat > "$TEST_ROOT/bin/uv" <<'EOF'
#!/bin/sh
echo "simulated bootstrap failure" >&2
exit 42
EOF
    chmod +x "$TEST_ROOT/bin/uv"
    run env PATH="$TEST_ROOT/bin:$PATH" bash "$SCAFFOLD" "$TEST_ROOT/project" sample_package --bootstrap
    [ "$status" -ne 0 ]
    [ -f "$TEST_ROOT/project/pyproject.toml" ]
    [ -f "$TEST_ROOT/project/justfile" ]
    [ -f "$TEST_ROOT/project/src/sample_package/__init__.py" ]
}

@test "audit accepts a generated library's runner contract" {
    run bash "$SCAFFOLD" "$TEST_ROOT/library" sample_package
    [ "$status" -eq 0 ]
    run bash "$AUDIT" "$TEST_ROOT/library" --porcelain
    [ "$status" -eq 0 ]
    [[ "$output" == *$'PASS\trunner.contract'* ]]
    [[ "$output" == *$'PASS\tci.callsrunner'* ]]
}

@test "audit rejects a no-op check recipe" {
    run bash "$SCAFFOLD" "$TEST_ROOT/library" sample_package
    [ "$status" -eq 0 ]
    sed 's/^check:.*/check:/' "$TEST_ROOT/library/justfile" > "$TEST_ROOT/library/justfile.new"
    mv "$TEST_ROOT/library/justfile.new" "$TEST_ROOT/library/justfile"
    run bash "$AUDIT" "$TEST_ROOT/library" --porcelain
    [ "$status" -ne 0 ]
    [[ "$output" == *$'FAIL\trunner.contract'* ]]
}

@test "audit rejects an unreasoned workflow waiver" {
    run bash "$SCAFFOLD" "$TEST_ROOT/library" sample_package
    [ "$status" -eq 0 ]
    cat >> "$TEST_ROOT/library/.github/workflows/tests.yml" <<'EOF'

# project-standards: allow ci-inline
run: pytest -q
EOF
    run bash "$AUDIT" "$TEST_ROOT/library" --porcelain
    [ "$status" -ne 0 ]
    [[ "$output" == *$'FAIL\tci.callsrunner'* ]]
}

@test "audit detects direct checker execution inside a multiline step" {
    run bash "$SCAFFOLD" "$TEST_ROOT/library" sample_package
    [ "$status" -eq 0 ]
    cat >> "$TEST_ROOT/library/.github/workflows/tests.yml" <<'EOF'

jobs:
  invalid:
    steps:
      - run: |
          echo before
          pytest -q
EOF
    run bash "$AUDIT" "$TEST_ROOT/library" --porcelain
    [ "$status" -ne 0 ]
    [[ "$output" == *$'FAIL\tci.callsrunner'* ]]
}

@test "audit reports malformed workflow syntax when actionlint is available" {
    run bash "$SCAFFOLD" "$TEST_ROOT/library" sample_package
    [ "$status" -eq 0 ]
    mkdir "$TEST_ROOT/bin"
    cat > "$TEST_ROOT/bin/actionlint" <<'EOF'
#!/bin/sh
if grep -q 'invalid-workflow-fixture' "$1"; then
    echo "invalid workflow fixture" >&2
    exit 1
fi
exit 0
EOF
    chmod +x "$TEST_ROOT/bin/actionlint"
    cat >> "$TEST_ROOT/library/.github/workflows/tests.yml" <<'EOF'

# invalid-workflow-fixture
jobs:
  invalid: [
EOF
    run env PATH="$TEST_ROOT/bin:$PATH" bash "$AUDIT" "$TEST_ROOT/library" --porcelain
    [ "$status" -ne 0 ]
    [[ "$output" == *$'FAIL\tci.syntax'* ]]
}

@test "audit scopes a named workflow waiver to its declared rule" {
    run bash "$SCAFFOLD" "$TEST_ROOT/library" sample_package
    [ "$status" -eq 0 ]
    cat >> "$TEST_ROOT/library/.github/workflows/tests.yml" <<'EOF'

# project-standards: allow ci-inline — fixture intentionally invokes pytest
run: pytest -q
EOF
    run bash "$AUDIT" "$TEST_ROOT/library" --porcelain
    [ "$status" -ne 0 ]
    [[ "$output" == *$'FAIL\tdeps.isolation'* ]]
    [[ "$output" == *$'PASS\tci.waived'* ]]
    [[ "$output" == *$'PASS\tci.callsrunner'* ]]
}

@test "audit reports missing action release comments" {
    run bash "$SCAFFOLD" "$TEST_ROOT/library" sample_package
    [ "$status" -eq 0 ]
    sed 's/ # v7$//' "$TEST_ROOT/library/.github/workflows/ci.yml" > \
        "$TEST_ROOT/library/.github/workflows/ci.yml.new"
    mv "$TEST_ROOT/library/.github/workflows/ci.yml.new" \
        "$TEST_ROOT/library/.github/workflows/ci.yml"
    run bash "$AUDIT" "$TEST_ROOT/library" --porcelain
    [ "$status" -eq 0 ]
    [[ "$output" == *$'WARN\tci.pin-comments'* ]]
}

@test "audit does not flag a checker named in a package install step" {
    mkdir -p "$TEST_ROOT/shell/bin" "$TEST_ROOT/shell/.github/workflows"
    cat > "$TEST_ROOT/shell/justfile" <<'EOF'
default:
    @echo default
lint:
    @echo lint
EOF
    cat > "$TEST_ROOT/shell/bin/pre-commit.sh" <<'EOF'
#!/bin/sh
just lint
EOF
    chmod +x "$TEST_ROOT/shell/bin/pre-commit.sh"
    cat > "$TEST_ROOT/shell/.github/workflows/test.yml" <<'EOF'
jobs:
  test:
    steps:
      - run: apk add --no-cache bats shellcheck
      - run: just lint
EOF
    init_git "$TEST_ROOT/shell"
    run bash "$AUDIT" "$TEST_ROOT/shell" --porcelain
    [ "$status" -eq 0 ]
    [[ "$output" != *$'FAIL\tci.callsrunner'* ]]
}

@test "audit exempts one standalone script" {
    mkdir "$TEST_ROOT/single"
    printf '#!/bin/sh\necho hello\n' > "$TEST_ROOT/single/hello.sh"
    chmod +x "$TEST_ROOT/single/hello.sh"
    init_git "$TEST_ROOT/single"
    run bash "$AUDIT" "$TEST_ROOT/single" --porcelain
    [ "$status" -eq 0 ]
    [[ "$output" == *$'PASS\tarchetype.single-file'* ]]
}

@test "audit rejects an ignored or untracked lockfile" {
    run bash "$SCAFFOLD" "$TEST_ROOT/library" sample_package
    [ "$status" -eq 0 ]
    printf 'lock-version = 1\n' > "$TEST_ROOT/library/uv.lock"
    printf 'uv.lock\n' >> "$TEST_ROOT/library/.gitignore"
    run bash "$AUDIT" "$TEST_ROOT/library" --porcelain
    [ "$status" -ne 0 ]
    [[ "$output" == *$'FAIL\tdeps.lock'* ]]
}

@test "Apps Script scaffolding remains offline and documents manual tests" {
    run bash "$SKILL_ROOT/scripts/scaffold-apps-script.sh" "$TEST_ROOT/apps" Example
    [ "$status" -eq 0 ]
    [ -f "$TEST_ROOT/apps/src/appsscript.json" ]
    grep -q 'runProjectTests' "$TEST_ROOT/apps/AGENTS.md"
    [ ! -e "$TEST_ROOT/apps/justfile" ]
}

@test "package-check installs the exact wheel outside the source tree" {
    mkdir "$TEST_ROOT/artifacts"
    python3 - "$TEST_ROOT/artifacts" <<'PY'
import sys
import tarfile
import zipfile
from io import BytesIO
from pathlib import Path

root = Path(sys.argv[1])
wheel = root / "demo_pkg-1.0.0-py3-none-any.whl"
dist_info = "demo_pkg-1.0.0.dist-info"
metadata = "Metadata-Version: 2.1\nName: demo-pkg\nVersion: 1.0.0\n"
wheel_text = "Wheel-Version: 1.0\nGenerator: fixture\nRoot-Is-Purelib: true\nTag: py3-none-any\n"
files = {
    "demo_pkg/__init__.py": "__version__ = '1.0.0'\n",
    "demo_pkg/py.typed": "",
    "LICENSE.md": "public domain\n",
    f"{dist_info}/METADATA": metadata,
    f"{dist_info}/WHEEL": wheel_text,
    f"{dist_info}/RECORD": "",
}
with zipfile.ZipFile(wheel, "w") as opened:
    for name, content in files.items():
        opened.writestr(name, content)

sdist = root / "demo-pkg-1.0.0.tar.gz"
backend = '''
from pathlib import Path
import zipfile

NAME = "demo_pkg"
VERSION = "1.0.0"


def _metadata(root: Path) -> Path:
    dist_info = root / f"{NAME}-{VERSION}.dist-info"
    dist_info.mkdir()
    (dist_info / "METADATA").write_text(
        "Metadata-Version: 2.1\\nName: demo-pkg\\nVersion: 1.0.0\\n"
    )
    (dist_info / "WHEEL").write_text(
        "Wheel-Version: 1.0\\nGenerator: fixture\\n"
        "Root-Is-Purelib: true\\nTag: py3-none-any\\n"
    )
    return dist_info


def prepare_metadata_for_build_wheel(metadata_directory, config_settings=None):
    root = Path(metadata_directory)
    return _metadata(root).name


def build_wheel(wheel_directory, config_settings=None, metadata_directory=None):
    filename = f"{NAME}-{VERSION}-py3-none-any.whl"
    dist_info = f"{NAME}-{VERSION}.dist-info"
    files = {
        "demo_pkg/__init__.py": "__version__ = '1.0.0'\\n",
        "demo_pkg/py.typed": "",
        "LICENSE.md": "public domain\\n",
        f"{dist_info}/METADATA":
            "Metadata-Version: 2.1\\nName: demo-pkg\\nVersion: 1.0.0\\n",
        f"{dist_info}/WHEEL":
            "Wheel-Version: 1.0\\nGenerator: fixture\\n"
            "Root-Is-Purelib: true\\nTag: py3-none-any\\n",
        f"{dist_info}/RECORD": "",
    }
    with zipfile.ZipFile(Path(wheel_directory) / filename, "w") as opened:
        for name, content in files.items():
            opened.writestr(name, content)
    return filename
'''
with tarfile.open(sdist, "w:gz") as opened:
    for name, content in {
        "demo-pkg-1.0.0/pyproject.toml":
            "[build-system]\nrequires = []\nbuild-backend = \"backend\"\n"
            "backend-path = [\".\"]\n",
        "demo-pkg-1.0.0/backend.py": backend,
        "demo-pkg-1.0.0/PKG-INFO": metadata,
        "demo-pkg-1.0.0/demo_pkg/__init__.py": files["demo_pkg/__init__.py"],
        "demo-pkg-1.0.0/LICENSE.md": files["LICENSE.md"],
    }.items():
        data = content.encode()
        info = tarfile.TarInfo(name)
        info.size = len(data)
        opened.addfile(info, BytesIO(data))
PY
    run env UV_CACHE_DIR="$TEST_ROOT/cache" bash "$SKILL_ROOT/assets/package-check.sh" \
        --artifacts "$TEST_ROOT/artifacts" --import demo_pkg --distribution demo-pkg \
        --version 1.0.0 --license LICENSE.md --typed
    [ "$status" -eq 0 ]
    [[ "$output" == *"imported demo_pkg"* ]]
}

@test "hook installation preserves a foreign hook and honors Git hooksPath" {
    run bash "$SCAFFOLD" "$TEST_ROOT/project" sample_package
    [ "$status" -eq 0 ]
    ! grep -q -- '--no-verify' "$TEST_ROOT/project/bin/pre-commit.sh"
    mkdir "$TEST_ROOT/project/custom-hooks"
    (cd "$TEST_ROOT/project" && git config core.hooksPath custom-hooks)
    cat > "$TEST_ROOT/project/custom-hooks/pre-commit" <<'EOF'
#!/bin/sh
echo foreign
EOF
    chmod +x "$TEST_ROOT/project/custom-hooks/pre-commit"
    mkdir "$TEST_ROOT/bin"
    cat > "$TEST_ROOT/bin/uv" <<'EOF'
#!/bin/sh
set -eu
hook_path="$(git rev-parse --git-path hooks/pre-commit)"
cat > "$hook_path" <<'HOOK'
#!/bin/sh
# pre-commit framework
HOOK
chmod +x "$hook_path"
EOF
    chmod +x "$TEST_ROOT/bin/uv"
    run env PATH="$TEST_ROOT/bin:$PATH" bash -c "cd '$TEST_ROOT/project' && bash scripts/hooks-install.sh"
    [ "$status" -eq 0 ]
    [ -f "$TEST_ROOT/project/custom-hooks/pre-commit.project-standards-backup" ]
    grep -q 'pre-commit framework' "$TEST_ROOT/project/custom-hooks/pre-commit"
}

@test "locked uv execution rejects stale metadata without changing the lock" {
    mkdir -p "$TEST_ROOT/lock-fixture/src/lock_fixture"
    python3 - "$TEST_ROOT/lock-fixture" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
(root / "pyproject.toml").write_text(
    "[project]\n"
    'name = "lock-fixture"\n'
    'version = "0.1.0"\n'
    'requires-python = ">=3.12"\n'
    "dependencies = []\n"
)
(root / "src/lock_fixture/__init__.py").write_text('__version__ = "0.1.0"\n')
PY
    run bash -c "cd '$TEST_ROOT/lock-fixture' && UV_CACHE_DIR='$TEST_ROOT/uv-cache' uv lock"
    [ "$status" -eq 0 ]
    cp "$TEST_ROOT/lock-fixture/uv.lock" "$TEST_ROOT/uv.lock.before"
    sed 's/>=3.12/>=3.13/' "$TEST_ROOT/lock-fixture/pyproject.toml" > "$TEST_ROOT/lock-fixture/pyproject.new"
    mv "$TEST_ROOT/lock-fixture/pyproject.new" "$TEST_ROOT/lock-fixture/pyproject.toml"
    run bash -c "cd '$TEST_ROOT/lock-fixture' && UV_CACHE_DIR='$TEST_ROOT/uv-cache' uv run --locked python -c 'print(\"unexpected success\")'"
    [ "$status" -ne 0 ]
    [[ "$output" == *"needs to be updated"* ]]
    cmp "$TEST_ROOT/uv.lock.before" "$TEST_ROOT/lock-fixture/uv.lock"
}

@test "support review keeps new interpreter claims explicit" {
    cp "$SKILL_ROOT/policy.toml" "$TEST_ROOT/policy.before"
    run bash "$SKILL_ROOT/scripts/check-support.sh" --candidate 3.16
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires a reviewed policy change and matrix validation"* ]]
    run bash "$SKILL_ROOT/scripts/check-support.sh" --candidate 3.15
    [ "$status" -eq 0 ]
    [[ "$output" == *"already declared"* ]]
    cmp "$TEST_ROOT/policy.before" "$SKILL_ROOT/policy.toml"
}

@test "release validation compares the tag with the source version" {
    mkdir -p "$TEST_ROOT/release/src/release_fixture"
    printf '__version__: str = "1.2.3rc1"\n' > "$TEST_ROOT/release/src/release_fixture/__init__.py"
    cp "$SKILL_ROOT/assets/validate-release.sh" "$TEST_ROOT/release/validate-release.sh"
    chmod +x "$TEST_ROOT/release/validate-release.sh"
    run env GITHUB_REF_NAME=v1.2.3rc1 bash -c "cd '$TEST_ROOT/release' && ./validate-release.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"matches package version"* ]]
    run env GITHUB_REF_NAME=v1.2.4 bash -c "cd '$TEST_ROOT/release' && ./validate-release.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not match package version"* ]]
}

@test "release dry-run creates no tag and normal release creates only the local tag" {
    mkdir -p "$TEST_ROOT/release/src/release_fixture" "$TEST_ROOT/release/scripts" "$TEST_ROOT/bin"
    printf '__version__: str = "2.0.0"\n' > "$TEST_ROOT/release/src/release_fixture/__init__.py"
    cp "$SKILL_ROOT/assets/release.sh" "$TEST_ROOT/release/scripts/release.sh"
    chmod +x "$TEST_ROOT/release/scripts/release.sh"
    cat > "$TEST_ROOT/bin/just" <<'EOF'
#!/bin/sh
[ "$1" = check ]
EOF
    chmod +x "$TEST_ROOT/bin/just"
    (cd "$TEST_ROOT/release" && git init -q && git add . && git -c user.name=fixture -c user.email=fixture@example.invalid commit -qm initial)
    run env PATH="$TEST_ROOT/bin:$PATH" bash -c "cd '$TEST_ROOT/release' && bash scripts/release.sh --dry-run"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would create local tag 'v2.0.0'"* ]]
    [ -z "$(cd "$TEST_ROOT/release" && git tag --list)" ]
    run env PATH="$TEST_ROOT/bin:$PATH" bash -c "cd '$TEST_ROOT/release' && bash scripts/release.sh"
    [ "$status" -eq 0 ]
    [ "$(cd "$TEST_ROOT/release" && git tag --list)" = "v2.0.0" ]
}
