#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python_bin="${PYTHON:-python3}"
"$python_bin" "$root/verification/pack-validator/test_pack_validate.py"
"$python_bin" "$root/verification/pack-validator/test_pack_update.py"
# Real web-design rejection is expected: migration integrity is not evidence.
set +e
output="$($python_bin "$root/verification/pack-validator/pack_validate.py" "$root/assets/packs/web-design" 2>&1)"
rc=$?
set -e
[[ "$rc" == 1 && "$output" == *evidence-null* ]] || { printf '%s\n' "$output"; exit 1; }
[[ ! -e "$root/assets/packs/web-design/pack.stamp" ]] || exit 1
printf 'PASS: web-design remains release-invalid with visible absent evidence.\n'
