# Verification

Verification assets for the scaffold live here. T010 owns the static command
suite; T012 owns the final behavioral pass/fail run after installer integration.

## T010 Static Checks

Run from the repo root:

```bash
./verification/run-static-checks.sh
```

The script performs checks that are valid before the full installer exists:

- `bash -n bootstrap verification/*.sh`
- no live `.claude/*` runtime references in installed Codex asset roots:
  `bootstrap`, `assets/scaffold/`, `.agents/`, and `.codex/`
- no `.claude/*` references outside documented migration/source allowlists
- no hardcoded `/home/echo/ACC` runtime dependency outside documented allowlists

Expected result:

```text
PASS: rg is available
PASS: shell syntax for bootstrap and verification helpers
PASS: no live .claude runtime references in installed Codex assets
PASS: only allowlisted migration/source .claude references remain
PASS: no hardcoded /home/echo/ACC runtime dependencies
Static verification passed.
```

## Reference Scan Allowlists

`.claude/*` references are allowed only when they are migration/source context,
not live runtime dependencies. The static scan allowlists these paths:

- `docs/**`
- `.archive/**`
- `README.md`
- `verification/README.md`
- `verification/run-static-checks.sh`

`/home/echo/ACC` references are allowed only as examples, migration notes, or
verification patterns. The static scan uses the same allowlist and excludes
`.git/**` and `.beads/**` generated state.

Any match in runtime/install logic, installed Codex assets, or scaffold payload
files outside those allowlists should be treated as a failure.

## T010 Disposable Dry-Run Check

The T002 skeleton can only prove argument parsing and dry-run no-write behavior.
Use a clearly test-created `/tmp` target:

```bash
tmp_target="$(mktemp -d -t cbp-t010-dry-run.XXXXXX)"
./bootstrap --dry-run "$tmp_target" --prefix T10
find "$tmp_target" -maxdepth 1 -type f -print
```

Expected T010 result:

- `./bootstrap --dry-run ...` exits `0`
- output includes `bd_required: no` and `writes: none`
- the `find` command prints no scaffold files

## Deferred T012 Behavioral Checks

These commands are intentionally deferred until T003 has implemented install
planning, conflict checks, write behavior, and missing-`bd` failure handling,
and until T011 has aligned README/operator docs with the implemented installer.

### Disposable Install And Readback

```bash
tmp_target="$(mktemp -d -t cbp-t012-install.XXXXXX)"
./bootstrap "$tmp_target" --prefix T12
test -f "$tmp_target/AGENTS.md"
test -d "$tmp_target/.agents"
test -d "$tmp_target/.codex"
test -d "$tmp_target/docs"
test -d "$tmp_target/.beads"
test ! -e "$tmp_target/.claude"
```

Expected T012 result: install exits `0`, initializes Beads, creates the
Codex-native tree, and does not create an active `.claude/` runtime tree.

### Managed-Path Conflict Behavior

```bash
tmp_target="$(mktemp -d -t cbp-t012-conflict.XXXXXX)"
printf 'preexisting\n' > "$tmp_target/AGENTS.md"
if ./bootstrap "$tmp_target" --prefix T12; then
    printf 'FAIL: expected managed-path conflict\n' >&2
    exit 1
fi
```

Expected T012 result: default install fails before writes and prints a conflict
report that names the path, planned action, reason, and suggested resolution.

### Protected Path Behavior

```bash
tmp_target="$(mktemp -d -t cbp-t012-protected.XXXXXX)"
mkdir -p "$tmp_target/.git" "$tmp_target/.beads"
./bootstrap "$tmp_target" --prefix T12 --force
test -d "$tmp_target/.git"
test -d "$tmp_target/.beads"
```

Expected T012 result: `--force` never overwrites protected paths such as
`.git/`, `.beads/`, credential files, ignored transient state, or paths outside
the managed scaffold contract.

### Missing `bd` Behavior

```bash
tmp_target="$(mktemp -d -t cbp-t012-missing-bd.XXXXXX)"
path_without_bd="$(mktemp -d -t cbp-t012-path-no-bd.XXXXXX)"
for tool in bash dirname readlink; do
    ln -s "$(command -v "$tool")" "$path_without_bd/$tool"
done
if PATH="$path_without_bd" /usr/bin/env bash ./bootstrap "$tmp_target" --prefix T12; then
    printf 'FAIL: expected missing-bd failure\n' >&2
    exit 1
fi
find "$tmp_target" -maxdepth 2 -type f -o -type d
```

Expected T012 result: real install fails before writing scaffold files, prints
an actionable missing-`bd` message, and does not try to install packages or use
network access. Dry-run mode remains allowed without `bd`.
