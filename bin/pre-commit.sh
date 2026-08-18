#!/usr/bin/env bash
# pre-commit hook: run the repository lint gate.

set -euo pipefail

exec just lint
