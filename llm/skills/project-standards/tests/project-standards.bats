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

@test "scaffold refuses a nonempty destination without changing it" {
    mkdir "$TEST_ROOT/existing"
    printf 'keep\n' > "$TEST_ROOT/existing/owned.txt"
    run bash "$SCAFFOLD" "$TEST_ROOT/existing" package_name
    [ "$status" -ne 0 ]
    [ "$(cat "$TEST_ROOT/existing/owned.txt")" = keep ]
    [ ! -e "$TEST_ROOT/existing/pyproject.toml" ]
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
    f"{dist_info}/METADATA": metadata,
    f"{dist_info}/WHEEL": wheel_text,
    f"{dist_info}/RECORD": "",
}
with zipfile.ZipFile(wheel, "w") as opened:
    for name, content in files.items():
        opened.writestr(name, content)

sdist = root / "demo-pkg-1.0.0.tar.gz"
with tarfile.open(sdist, "w:gz") as opened:
    for name, content in {
        "demo-pkg-1.0.0/PKG-INFO": metadata,
        "demo-pkg-1.0.0/demo_pkg/__init__.py": files["demo_pkg/__init__.py"],
    }.items():
        data = content.encode()
        info = tarfile.TarInfo(name)
        info.size = len(data)
        opened.addfile(info, BytesIO(data))
PY
    run env UV_CACHE_DIR="$TEST_ROOT/cache" bash "$SKILL_ROOT/assets/package-check.sh" \
        --artifacts "$TEST_ROOT/artifacts" --import demo_pkg --distribution demo-pkg \
        --version 1.0.0 --typed
    [ "$status" -eq 0 ]
    [[ "$output" == *"imported demo_pkg"* ]]
}

@test "hook installation preserves a foreign hook and honors Git hooksPath" {
    run bash "$SCAFFOLD" "$TEST_ROOT/project" sample_package
    [ "$status" -eq 0 ]
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
