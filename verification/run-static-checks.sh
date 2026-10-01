#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
bash -n bootstrap
while IFS= read -r -d '' file; do bash -n "$file"; done < <(find lib verification assets/global -name '*.sh' -type f -print0)
python3 verification/check-assets.py
cmp assets/native/process-supervisor.py assets/packs/falcon/scaffold/.agents/skills/falcon/scripts/process-supervisor.py
cmp assets/native/process-supervisor.py assets/packs/web-design/scaffold/.agents/skills/impeccable/scripts/process-supervisor.py
# Syntax-check every vendored helper, including files invisible to non-hidden rg.
while IFS= read -r -d '' file; do node --check "$file" >/dev/null; done < <(find assets -type f \( -name '*.mjs' -o -name '*.js' \) -print0)
python3 -c 'from pathlib import Path; [compile(p.read_bytes(),str(p),"exec") for base in ("lib","verification","assets/native","assets/global","assets/packs","tools") for p in Path(base).rglob("*.py")]'
printf 'Static verification passed.\n'
