#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
python_bin="${PYTHON:-python3}"
./verification/run-static-checks.sh
"$python_bin" -m unittest discover -s verification -p 'test_*.py' -v
./verification/run-validator-checks.sh
python3 verification/cli-integration.py
git diff --check
