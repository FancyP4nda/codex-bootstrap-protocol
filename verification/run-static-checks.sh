#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
cd "$repo_root"

failures=0

run_check() {
    local name="$1"
    shift

    printf '==> %s\n' "$name"
    if "$@"; then
        printf 'PASS: %s\n\n' "$name"
    else
        printf 'FAIL: %s\n\n' "$name" >&2
        failures=1
    fi
}

require_rg() {
    command -v rg >/dev/null 2>&1
}

check_shell_syntax() {
    local files=(bootstrap)
    local file

    shopt -s nullglob
    files+=(verification/*.sh)
    shopt -u nullglob

    for file in "${files[@]}"; do
        bash -n "$file"
        printf 'checked: %s\n' "$file"
    done
}

check_no_live_claude_runtime_refs() {
    local pattern='\.claude(/|$)'
    local paths=(bootstrap assets/scaffold .agents .codex)
    local existing=()
    local path output

    for path in "${paths[@]}"; do
        [[ -e "$path" ]] && existing+=("$path")
    done

    if output="$(rg -n --hidden --glob '!**/.git/**' --glob '!**/.beads/**' --glob '!**/__pycache__/**' "$pattern" "${existing[@]}")"; then
        printf 'Unexpected live .claude runtime reference(s):\n%s\n' "$output" >&2
        return 1
    fi

    printf 'scanned installed/runtime roots: %s\n' "${existing[*]}"
}

check_claude_reference_allowlist() {
    local pattern='\.claude(/|$)'
    local output

    if output="$(rg -n --hidden "$pattern" . \
        --glob '!**/.git/**' \
        --glob '!**/.beads/**' \
        --glob '!docs/**' \
        --glob '!.archive/**' \
        --glob '!README.md' \
        --glob '!verification/README.md' \
        --glob '!verification/run-static-checks.sh')"; then
        printf 'Unexpected .claude reference outside documented migration allowlists:\n%s\n' "$output" >&2
        return 1
    fi

    printf 'allowlisted .claude reference paths: docs/**, .archive/**, README.md, verification docs/scripts\n'
}

check_no_hardcoded_acc_runtime_refs() {
    local forbidden_root="/home/echo/"'ACC'
    local output

    if output="$(rg -n --hidden -F "$forbidden_root" . \
        --glob '!**/.git/**' \
        --glob '!**/.beads/**' \
        --glob '!docs/**' \
        --glob '!.archive/**' \
        --glob '!README.md' \
        --glob '!verification/README.md' \
        --glob '!verification/run-static-checks.sh')"; then
        printf 'Unexpected hardcoded /home/echo/ACC runtime reference(s):\n%s\n' "$output" >&2
        return 1
    fi

    printf 'allowlisted /home/echo/ACC paths: docs/**, .archive/**, README.md, verification docs/scripts\n'
}

run_check "rg is available" require_rg
run_check "shell syntax for bootstrap and verification helpers" check_shell_syntax
run_check "no live .claude runtime references in installed Codex assets" check_no_live_claude_runtime_refs
run_check "only allowlisted migration/source .claude references remain" check_claude_reference_allowlist
run_check "no hardcoded /home/echo/ACC runtime dependencies" check_no_hardcoded_acc_runtime_refs

if ((failures)); then
    printf 'Static verification failed.\n' >&2
    exit 1
fi

printf 'Static verification passed.\n'
