# /// script
# requires-python = ">=3.12"
# dependencies = ["pytest==9.1.1", "hypothesis==6.170.14"]
# ///
"""Run mutation targets in scratch copies and gate survivors on dispositions.

Usage:
    uv run --python 3.12 tests/mutation/runner.py TARGET [TARGET ...]
    uv run --python 3.12 tests/mutation/runner.py guard --only KEY --verbose
    uv run --python 3.12 tests/mutation/runner.py guard --report-only

A mutant is killed only when the target's test command exits with one of its
``kill_codes`` (pytest and bats report test failures as 1). A timeout or any
other exit code is not a kill; it is reported as ``timeout`` or
``inconclusive`` and needs a recorded disposition like a survivor.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import queue
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import tomllib

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.dont_write_bytecode = True

from mutants import Mutant, disambiguate  # noqa: E402
import py_mutate  # noqa: E402
import sh_mutate  # noqa: E402

REPOSITORY = HERE.parents[1]
TARGETS = HERE / "targets.toml"
DISPOSITIONS = HERE / "dispositions.toml"
REASONS = {"equivalent", "message-only", "unreachable-on-supported-input",
           "accepted-risk", "hangs"}
OUTCOMES_NEEDING_REASON = {"survived", "timeout", "inconclusive"}


def load_targets() -> dict[str, dict]:
    return tomllib.loads(TARGETS.read_text(encoding="utf-8"))["target"]


def load_dispositions() -> dict[tuple[str, str], dict]:
    if not DISPOSITIONS.exists():
        return {}
    entries = tomllib.loads(DISPOSITIONS.read_text(encoding="utf-8")).get("survivor", [])
    result = {}
    for entry in entries:
        if entry.get("reason") not in REASONS:
            raise SystemExit(f"Invalid disposition reason: {entry}")
        if not entry.get("note"):
            raise SystemExit(f"Disposition needs a note: {entry}")
        result[(entry["target"], entry["key"])] = entry
    return result


def enumerate_target(config: dict) -> list[Mutant]:
    mutants: list[Mutant] = []
    for relative in config["files"]:
        path = REPOSITORY / relative
        if config["kind"] == "python":
            mutants.extend(py_mutate.enumerate_mutants(
                path, relative, config.get("functions"), config.get("exclude")))
        else:
            mutants.extend(sh_mutate.enumerate_mutants(
                path, relative, config.get("functions"), config.get("ranges")))
    return disambiguate(mutants)


def copy_tree(destination: Path) -> None:
    """Copy tracked and untracked-but-not-ignored files, never .git."""
    listing = subprocess.run(
        ["git", "ls-files", "-co", "--exclude-standard", "-z"],
        cwd=REPOSITORY, check=True, capture_output=True).stdout.split(b"\0")
    for raw in listing:
        if not raw:
            continue
        relative = raw.decode("utf-8")
        source = REPOSITORY / relative
        if not source.exists() and not source.is_symlink():
            continue
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.is_symlink():
            os.symlink(os.readlink(source), target)
        elif source.is_file():
            shutil.copy2(source, target)


def clear_caches(root: Path) -> None:
    for cache in root.rglob("__pycache__"):
        shutil.rmtree(cache, ignore_errors=True)
    for cache in root.rglob(".pytest_cache"):
        shutil.rmtree(cache, ignore_errors=True)
    shutil.rmtree(root / ".hypothesis", ignore_errors=True)


def run_tests(root: Path, config: dict, timeout: float) -> tuple[str, int | None, str]:
    command = config["test"].replace("{python}", sys.executable)
    environment = dict(os.environ, PYTHONDONTWRITEBYTECODE="1",
                       HYPOTHESIS_PROFILE=os.environ.get("HYPOTHESIS_PROFILE", "ci"))
    clear_caches(root)
    process = subprocess.Popen(["bash", "-c", command], cwd=root, env=environment,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               start_new_session=True)
    try:
        output, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        output, _ = process.communicate()
        return "timeout", None, output.decode("utf-8", "replace")
    code = process.returncode
    text = output.decode("utf-8", "replace")
    if code == 0:
        return "survived", code, text
    if code in config.get("kill_codes", [1]):
        return "killed", code, text
    return "inconclusive", code, text


def run_target(name: str, config: dict, mutants: list[Mutant], jobs: int,
               verbose: bool) -> list[dict]:
    timeout = float(config.get("timeout", 120))
    scratch = Path(tempfile.mkdtemp(prefix=f"mutation-{name}-"))
    workers = []
    try:
        for index in range(jobs):
            root = scratch / f"worker-{index}"
            root.mkdir()
            copy_tree(root)
            workers.append(root)

        started = time.monotonic()
        status, code, output = run_tests(workers[0], config, timeout * 3)
        baseline = time.monotonic() - started
        if status != "survived":
            print(output[-4000:])
            raise SystemExit(f"{name}: baseline tests fail ({status}, exit {code})")
        print(f"{name}: {len(mutants)} mutants, baseline {baseline:.1f}s, {jobs} workers",
              flush=True)

        free: queue.Queue[Path] = queue.Queue()
        for root in workers:
            free.put(root)
        results: list[dict] = []
        lock = threading.Lock()

        def execute(mutant: Mutant) -> None:
            root = free.get()
            path = root / mutant.file
            original = path.read_bytes()
            try:
                path.write_bytes(mutant.content)
                outcome, exit_code, text = run_tests(root, config, timeout)
            finally:
                path.write_bytes(original)
                free.put(root)
            record = dict(target=name, key=mutant.key, file=mutant.file,
                          function=mutant.function, operator=mutant.operator,
                          line=mutant.line, line_text=mutant.line_text.strip(),
                          description=mutant.description, outcome=outcome,
                          exit_code=exit_code)
            with lock:
                results.append(record)
                done = len(results)
                if verbose:
                    print(text[-6000:])
                if verbose or outcome != "killed":
                    print(f"  [{done}/{len(mutants)}] {outcome}: {mutant.file}:{mutant.line} "
                          f"{mutant.function} {mutant.description}", flush=True)
                elif done % 50 == 0:
                    print(f"  [{done}/{len(mutants)}]", flush=True)

        with ThreadPoolExecutor(max_workers=jobs) as pool:
            list(pool.map(execute, mutants))
        return sorted(results, key=lambda record: (record["file"], record["line"], record["key"]))
    finally:
        shutil.rmtree(scratch, ignore_errors=True)


def summarize(results: list[dict]) -> str:
    by_function: dict[tuple[str, str], dict[str, int]] = {}
    for record in results:
        counts = by_function.setdefault((record["target"], record["function"]), {})
        counts[record["outcome"]] = counts.get(record["outcome"], 0) + 1
    lines = ["| Target | Function | Killed | Survived | Timeout | Inconclusive |",
             "|---|---|---|---|---|---|"]
    totals = {"killed": 0, "survived": 0, "timeout": 0, "inconclusive": 0}
    for (target, function), counts in sorted(by_function.items()):
        for outcome in totals:
            totals[outcome] += counts.get(outcome, 0)
        lines.append(f"| {target} | `{function}` | {counts.get('killed', 0)} | "
                     f"{counts.get('survived', 0)} | {counts.get('timeout', 0)} | "
                     f"{counts.get('inconclusive', 0)} |")
    lines.append(f"| **all** | | {totals['killed']} | {totals['survived']} | "
                 f"{totals['timeout']} | {totals['inconclusive']} |")
    return "\n".join(lines)


def gate(results: list[dict], targets: list[str], dispositions: dict) -> int:
    failures = 0
    seen = set()
    for record in results:
        key = (record["target"], record["key"])
        seen.add(key)
        if record["outcome"] not in OUTCOMES_NEEDING_REASON:
            if key in dispositions:
                print(f"STALE (now killed): {record['target']} {record['key']}")
                failures += 1
            continue
        if key in dispositions:
            continue
        failures += 1
        print("UNRECORDED " + record["outcome"].upper() + ":")
        print(f"  {record['file']}:{record['line']}: {record['line_text']}")
        print("[[survivor]]")
        print(f"target = {json.dumps(record['target'])}")
        print(f"key = {json.dumps(record['key'])}")
        print('reason = ""')
        print('note = ""')
        print()
    for (target, key) in dispositions:
        if target in targets and (target, key) not in seen:
            print(f"STALE (mutant no longer exists): {target} {key}")
            failures += 1
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("targets", nargs="+")
    parser.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    parser.add_argument("--only", action="append", default=[],
                        help="run only the mutant with this key (repeatable)")
    parser.add_argument("--function", action="append", default=[],
                        help="run only mutants in this function (repeatable)")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--report-only", action="store_true",
                        help="print the summary without gating on dispositions")
    parser.add_argument("--json", type=Path, help="write all results to this file")
    parser.add_argument("--list", action="store_true", help="list mutants and exit")
    args = parser.parse_args()

    configs = load_targets()
    names = list(configs) if args.targets == ["all"] else args.targets
    unknown = [name for name in names if name not in configs]
    if unknown:
        raise SystemExit(f"Unknown targets: {', '.join(unknown)}")
    dispositions = load_dispositions()

    results: list[dict] = []
    for name in names:
        mutants = enumerate_target(configs[name])
        if args.only:
            mutants = [mutant for mutant in mutants if mutant.key in args.only]
        if args.function:
            mutants = [mutant for mutant in mutants
                       if mutant.function.split(".")[0] in args.function]
        if args.list:
            for mutant in mutants:
                print(f"{mutant.file}:{mutant.line} {mutant.key}")
            continue
        if not mutants:
            continue
        results.extend(run_target(name, configs[name], mutants, args.jobs, args.verbose))
    if args.list:
        return 0

    print(summarize(results))
    if args.json:
        args.json.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    if args.report_only or args.only or args.function:
        return 0
    failures = gate(results, names, dispositions)
    if failures:
        print(f"{failures} mutation gate failure(s)")
        return 1
    print("Mutation gate passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
