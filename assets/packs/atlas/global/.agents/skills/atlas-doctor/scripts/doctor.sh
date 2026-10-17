#!/usr/bin/env bash
# doctor.sh: the atlas-doctor Command (PRD Part III FR-028, FR-042, FR-043
# doctor half; AC-061..AC-064, AC-082, AC-084).
#
#   doctor.sh codex
#
# Kit-authored, shipped with atlas-doctor. One line per check, "[ok] <id>",
# "[warn] <id>" or "[missing] <id>", some with ": <detail>"; each [warn] and
# [missing] line is followed by its exact fix line. Exit 1 when any line is
# [missing], else 0 ([warn] alone does not fail); 2 on a usage error. The
# checks, in order:
#
#   prerequisites   every External Prerequisite (ATLAS_DOCTOR_PREREQS, which
#                   a static check holds equal to pack.yaml's ids), through
#                   the shared script atlas-check.sh, sourced from beside
#                   this file, so its lines are the Commands' lines;
#   uv-constraints  FR-028: uv tool install --help lists --constraints,
#                   which the graphify fix line uses (run from / with
#                   UV_NO_CONFIG=1, so no repository uv config is read);
#   rea-mcp         rea doctor --client codex (REA's name for Codex's
#                   registration, mapped by the shared script's
#                   atlas_rea_client, which the REA Commands use too, and
#                   printed by its report, so the doctor and $rea-doctor
#                   print the same lines); rea-skill: rea doctor --skill
#                   --client codex, Codex's skill copy;
#                   rea-doctor: a plain rea doctor (healthy and its scope
#                   checks), its output shown when it is not healthy;
#   multi_agent     decision brief D-5: config.toml in CODEX_HOME (default
#                   ~/.codex) sets [features] multi_agent = true, which
#                   Graphify's parallel semantic extraction needs; a [warn]
#                   with the two lines to add, and the file is never edited;
#   rea-config      D-6: the same file has an [mcp_servers.rea] entry;
#   migration-*     D-4: <agents-dir>/skills/archify a symlink; a
#                   .graphify_version stamp in <agents-dir>/skills/graphify/;
#                   an archify or graphify skill directory the atlas pack's
#                   install record doesn't list (an identical copy the
#                   installer never adopted), with the line that moves it out
#                   of the skills directory;
#   trace-*         FR-043, in the current repository (its work tree top,
#                   or the working directory outside git): a "## graphify"
#                   section in CLAUDE.md or AGENTS.md; a PreToolUse hook
#                   naming graphify in .claude/settings.json or
#                   settings.local.json (trace-pretooluse), or in
#                   .codex/hooks.json (trace-codex-hooks); a graphify block in post-commit or
#                   post-checkout in the hooks directory git uses (git
#                   rev-parse --git-path hooks: core.hooksPath and linked
#                   worktrees; Husky's .husky/_ means its parent, as for
#                   Graphify); merge.graphify.driver in the repository's git
#                   config or a "graph.json ... merge=graphify" line in the
#                   top-level .gitattributes. Each warns with the upstream
#                   uninstall command, prefixed GRAPHIFY_NO_AUTO_REFRESH=1,
#                   for the operator to run by hand; a trace in a symlinked
#                   file names the resolved target, which the uninstall
#                   writes through;
#   gitignore-*     the graphify-out/ and .archify/ rows, through the
#                   shared script's scratch subcommand (without --apply);
#   gemini-key      GEMINI_API_KEY and GOOGLE_API_KEY, by name only;
#   graph           when ./graphify-out/graph.json exists, the shared
#                   helper's provenance state (provenance state .).
#
# Read-only: it writes no file, runs no install, runs no fix line and edits
# no configuration; git runs without optional locks or the fsmonitor hook.
# The repository is untrusted, as in the shared script: PATH is cut first
# (an area holding /usr/bin or /bin stops the doctor), tools come from the
# cut PATH only, an rea inside the area is never run, the repository's
# files are read with bash builtins (regular files only) and every path or
# tool output it prints has its control characters removed. bash 3.2 or
# newer.

ATLAS_DOCTOR_PREREQS="graphify uv rea node-archify node-rea browser"
# The largest hook settings file the PreToolUse scan reads (bytes).
ATLAS_DOCTOR_SCAN_BYTES=65536

_doctor_here="${BASH_SOURCE[0]%/*}"
[ "$_doctor_here" != "${BASH_SOURCE[0]}" ] || _doctor_here=.
# shellcheck source=atlas-check.sh
. "${_doctor_here}/atlas-check.sh" || exit 2

_DOCTOR_STATUS=0

# _doctor_q <text>: the text single-quoted for POSIX shells, control
# characters removed.
_doctor_q() {
    local s q="'"
    s="$(_atlas_printable "$1")"
    printf "'%s'" "${s//$q/$q\\$q$q}"
}

# _doctor_target <path>: the path with every symlink step resolved (at most
# 40) and its directory made physical.
_doctor_target() {
    local p="$1" n=0 t d
    while [ -L "$p" ] && [ "$n" -lt 40 ]; do
        t="$(readlink "$p")" || break
        [ -n "$t" ] || break
        case "$t" in /*) p="$t" ;; *) p="${p%/*}/$t" ;; esac
        n=$((n + 1))
    done
    if d="$(cd -P "${p%/*}/" 2>/dev/null && pwd -P)"; then
        p="${d%/}/${p##*/}"
    fi
    _atlas_printable "$p"
}

# _doctor_where <path> <verb>: the path for a [warn] line; a symlink adds
# "(a symlink to <target>, which the <verb>)".
_doctor_where() {
    if [ -L "$1" ]; then
        printf '%s (a symlink to %s, which the %s)' "$(_atlas_printable "$1")" "$(_doctor_target "$1")" "$2"
    else
        _atlas_printable "$1"
    fi
}

# _doctor_strip <line>: the line without leading and trailing blanks and
# carriage returns, in _DL.
_doctor_strip() {
    _DL="$1"
    _DL="${_DL#"${_DL%%[![:space:]]*}"}"
    _DL="${_DL%"${_DL##*[![:space:]]}"}"
}

# _doctor_has_line <file> <line>...: true when the regular file holds a line
# equal, blanks stripped, to one of the lines (Graphify's own matching).
_doctor_has_line() {
    local f="$1" l want
    shift
    [ -f "$f" ] || return 1
    while IFS= read -r l || [ -n "$l" ]; do
        _doctor_strip "$l"
        for want in "$@"; do
            [ "$_DL" = "$want" ] && return 0
        done
    done 2>/dev/null <"$f"
    return 1
}

# _doctor_pretooluse <file>: 0 when a string inside a "PreToolUse" array of
# the regular JSON file mentions graphify (Graphify's uninstall removes the
# entries that do), 1 when none does, 2 when the file is larger than
# ATLAS_DOCTOR_SCAN_BYTES. One pass, one byte per read, so the time grows
# with the file's size alone, whatever the repository puts in it: the key
# string is kept only up to 16 bytes, an array string only as its last 8.
_doctor_pretooluse() {
    local LC_ALL=C f="$1" c n=0 instr="" esc="" str="" last="" want="" depth=0
    [ -f "$f" ] || return 1
    while IFS= read -r -n 1 -d '' c; do
        n=$((n + 1))
        [ "$n" -le "$ATLAS_DOCTOR_SCAN_BYTES" ] || return 2
        if [ -n "$instr" ]; then
            if [ -n "$esc" ]; then
                esc=""
            elif [ "$c" = '\' ]; then
                esc=1
                continue
            elif [ "$c" = '"' ]; then
                instr=""
                if [ "$depth" -eq 0 ]; then
                    last="$str"
                fi
                continue
            fi
            if [ "$depth" -gt 0 ]; then
                str="${str}${c}"
                [ "${#str}" -le 8 ] || str="${str:1}"
                [ "$str" = graphify ] && return 0
            elif [ "${#str}" -lt 16 ]; then
                str="${str}${c}"
            fi
            continue
        fi
        case "$c" in
            '"')
                instr=1
                str=""
                [ "$depth" -gt 0 ] || want=""
                ;;
            ':')
                if [ "$depth" -eq 0 ] && [ "$last" = PreToolUse ]; then want=1; fi
                last=""
                ;;
            '[')
                if [ "$depth" -gt 0 ]; then
                    depth=$((depth + 1))
                elif [ -n "$want" ]; then
                    depth=1
                fi
                want=""
                ;;
            ']') [ "$depth" -eq 0 ] || depth=$((depth - 1)) ;;
            '' | ' ' | $'\t' | $'\n' | $'\r') ;;
            *)
                if [ "$depth" -eq 0 ]; then
                    last=""
                    want=""
                fi
                ;;
        esac
    done 2>/dev/null <"$f"
    return 1
}

# _doctor_merge_attr <file>: true when a non-comment line of the regular
# file routes a graph.json path to the graphify driver (Graphify's own
# test: the first field ends in graph.json, a later one is merge=graphify).
_doctor_merge_attr() {
    local f="$1" l first field
    [ -f "$f" ] || return 1
    _atlas_noglob
    while IFS= read -r l || [ -n "$l" ]; do
        _doctor_strip "$l"
        case "$_DL" in '' | '#'*) continue ;; esac
        # shellcheck disable=SC2086
        set -- $_DL
        first="$1"
        shift
        case "$first" in *graph.json) ;; *) continue ;; esac
        for field in "$@"; do
            if [ "$field" = merge=graphify ]; then
                _atlas_glob
                return 0
            fi
        done
    done 2>/dev/null <"$f"
    _atlas_glob
    return 1
}

# _doctor_warn <id: detail> <fix line>
_doctor_warn() {
    printf '[warn] %s\n%s\n' "$1" "$2"
}

# --- uv tool install --constraints (FR-028) ---------------------------------
# The graphify fix line installs with --constraints, so a uv whose tool
# install lacks the option can't run it. The help runs from / with
# UV_NO_CONFIG=1: read-only, and no uv.toml or pyproject.toml of the
# repository is read.
_doctor_uv_constraints() {
    local st=0 out
    _atlas_locate uv uv >/dev/null || st=$?
    if [ "$st" -ne 0 ]; then
        printf '[missing] uv-constraints\n%s\n' "Not checked: no usable uv (see the uv line above)."
        _DOCTOR_STATUS=1
        return
    fi
    if ! out="$(cd / && UV_NO_CONFIG=1 "$_AF" tool install --help </dev/null 2>/dev/null)"; then
        printf '[missing] uv-constraints\n%s\n' "uv tool install --help failed, so atlas can't tell whether it supports --constraints. Reinstall or upgrade uv (https://docs.astral.sh/uv/), then re-run."
        _DOCTOR_STATUS=1
        return
    fi
    case "$out" in
        *--constraints[!A-Za-z0-9_-]* | *--constraints) printf '[ok] uv-constraints\n' ;;
        *)
            printf '[missing] uv-constraints\n%s\n' "uv tool install has no --constraints option, which the graphify fix line uses. Upgrade uv (https://docs.astral.sh/uv/), then re-run."
            _DOCTOR_STATUS=1
            ;;
    esac
}

# --- REA --------------------------------------------------------------------
# The shared script's report: the MCP registration and skill by REA's client
# id (atlas_rea_client), then a plain rea doctor. A missing registration or
# skill fails the doctor; a provider that is not ready is a warning only.
_doctor_rea() {
    _atlas_rea_report || _DOCTOR_STATUS=1
}

# --- Codex config (decision brief D-5, D-6) ---------------------------------
# The config.toml in CODEX_HOME: [features] multi_agent = true and an
# [mcp_servers.rea] entry. Read with bash builtins; the file is never edited.
_doctor_codex_config() {
    local cfg="${CODEX_HOME:-$HOME/.codex}/config.toml" l table="" key val multi="" rea="" shown
    shown="$(_atlas_printable "$cfg")"
    case "$cfg" in
        /*) ;;
        *)
            # A relative CODEX_HOME would read the repository's config.toml.
            _doctor_warn "multi_agent: CODEX_HOME is not an absolute path, so config.toml was not read." "Set CODEX_HOME to an absolute path, then run again."
            _doctor_warn "rea-config: CODEX_HOME is not an absolute path, so config.toml was not read." "Set CODEX_HOME to an absolute path, then run again."
            return
            ;;
    esac
    if [ -f "$cfg" ]; then
        while IFS= read -r l || [ -n "$l" ]; do
            _doctor_strip "$l"
            case "$_DL" in '' | '#'*) continue ;; esac
            case "$_DL" in
                '['*)
                    table="${_DL#\[}"
                    table="${table%%]*}"
                    table="${table//[[:space:]]/}"
                    case "$table" in mcp_servers.rea | mcp_servers.rea.*) rea=1 ;; esac
                    continue
                    ;;
            esac
            case "$_DL" in *=*) ;; *) continue ;; esac
            key="${_DL%%=*}"
            val="${_DL#*=}"
            key="${key//[[:space:]]/}"
            val="${val%%#*}"
            val="${val//[[:space:]]/}"
            case "$table:$key" in
                features:multi_agent | :features.multi_agent)
                    if [ "$val" = true ]; then multi=1; else multi=""; fi
                    ;;
                :features)
                    case "$val" in *multi_agent=true*) multi=1 ;; esac
                    ;;
                :mcp_servers.rea | :mcp_servers.rea.* | mcp_servers:rea | mcp_servers:rea.*)
                    rea=1
                    ;;
            esac
        done 2>/dev/null <"$cfg"
    fi
    if [ -n "$multi" ]; then
        printf '[ok] multi_agent\n'
    else
        _doctor_warn "multi_agent: ${shown} does not set [features] multi_agent = true, so Graphify's parallel semantic extraction runs serially." \
            "Add these two lines to ${shown} by hand (if it already has a [features] table, add only the second line there; nothing here edits the file):
[features]
multi_agent = true"
    fi
    if [ -n "$rea" ]; then
        printf '[ok] rea-config\n'
    else
        _doctor_warn "rea-config: ${shown} has no [mcp_servers.rea] entry." "Run: rea setup"
    fi
}

# --- Migration (decision brief D-4) -----------------------------------------
# _doctor_stamped <name>: true when the atlas pack's install record lists the
# skill's SKILL.md. The installer never adopts an identical file that was
# already there, so a copy from before the pack stays unlisted.
_doctor_stamped() {
    local record="${ATLAS_CONFIG_DIR}/bootstrap/packs/atlas.json" l
    [ -f "$record" ] || return 1
    while IFS= read -r l || [ -n "$l" ]; do
        case "$l" in *"\"skills/$1/SKILL.md\""*) return 0 ;; esac
    done 2>/dev/null <"$record"
    return 1
}

_doctor_migration() {
    local link f name dir retired
    retired="${ATLAS_CONFIG_DIR}/retired"
    for name in archify graphify; do
        link="${ATLAS_CONFIG_DIR}/skills/${name}"
        if [ -L "$link" ]; then
            _doctor_warn "migration-${name}-link: $(_atlas_printable "$link") is a symlink to $(_doctor_target "$link"); the installer refuses to install through a link." \
                "Move or remove the link, not its target: rm $(_doctor_q "$link"); then reinstall the atlas pack (codex-bootstrap --global-only --pack atlas) and check $(_doctor_q "$(_doctor_target "$link")") for pack files."
        else
            printf '[ok] migration-%s-link\n' "$name"
        fi
    done
    f="${ATLAS_CONFIG_DIR}/skills/graphify/.graphify_version"
    if [ -e "$f" ] || [ -L "$f" ]; then
        _doctor_warn "migration-stamp-agents: $(_atlas_printable "$f") exists; a bare graphify command can then overwrite the pack's Graphify skill." \
            "Delete it by hand: rm $(_doctor_q "$f")"
    else
        printf '[ok] migration-stamp-agents\n'
    fi
    for name in archify graphify; do
        dir="${ATLAS_CONFIG_DIR}/skills/${name}"
        if [ -L "$dir" ] || [ ! -d "$dir" ] || _doctor_stamped "$name"; then
            printf '[ok] migration-unstamped-%s\n' "$name"
        else
            _doctor_warn "migration-unstamped-${name}: $(_atlas_printable "$dir") is not in the atlas pack's install record, so the pack neither refreshes nor removes it." \
                "Move it out of the skills directory, then install the pack: mkdir -p $(_doctor_q "$retired") && mv $(_doctor_q "$dir") $(_doctor_q "${retired}/${name}") && codex-bootstrap --global-only --pack atlas"
        fi
    done
}

# --- Traces (FR-043) --------------------------------------------------------
# _doctor_uninstall <graphify arguments>: the fix line for a trace. It runs
# Graphify's own uninstall through the interpreter the runner verified
# (_DOCTOR_PY), by its absolute path, so the operator's shell, whose PATH
# isn't cut, can't pick a graphify the repository supplies (R-023); -I
# keeps the repository off the module path. Without a verified Graphify,
# a pointer to the graphify line instead.
_doctor_uninstall() {
    if [ -n "$_DOCTOR_PY" ]; then
        printf 'GRAPHIFY_NO_AUTO_REFRESH=1 %s -I -m graphify %s\n' "$(_doctor_q "$_DOCTOR_PY")" "$1"
    else
        printf 'Fix the graphify line above first: this fix runs Graphify'"'"'s own "%s" through the verified CLI. Then run $atlas-doctor again for the exact line.\n' "$1"
    fi
}

# _doctor_trace_warn <id> <what> <uninstall>
_doctor_trace_warn() {
    _doctor_warn "$1: $2; run the line below by hand from $(_atlas_printable "$_DOCTOR_TOP")." \
        "$(_doctor_uninstall "$3")"
}

# _doctor_not_checked <id>: the [warn] for a git check that could not run.
_doctor_not_checked() {
    if [ -n "$_DOCTOR_GIT_REFUSED" ]; then
        _doctor_warn "$1: not checked: the git on PATH lies inside the repository" \
            "Take that directory off PATH (see the git line above), then run \$atlas-doctor again."
    else
        _doctor_warn "$1: not checked: git not found" "Install git, then run \$atlas-doctor again."
    fi
}

# _doctor_hook_traces <id> <uninstall> <file>...: a graphify string inside a
# PreToolUse array of any of the JSON files (the clients' hook settings).
_doctor_hook_traces() {
    local id="$1" uninstall="$2" f st found=""
    shift 2
    for f in "$@"; do
        st=0
        _doctor_pretooluse "$f" || st=$?
        case "$st" in
            0)
                _doctor_trace_warn "$id" "$(_doctor_where "$f" "uninstall writes through") has a graphify PreToolUse hook" "$uninstall"
                found=1
                ;;
            2)
                _doctor_warn "${id}: $(_atlas_printable "$f") is larger than ${ATLAS_DOCTOR_SCAN_BYTES} bytes, so it was not scanned." \
                    "Check its PreToolUse entries for graphify by hand; to remove one, run from $(_atlas_printable "$_DOCTOR_TOP"): $(_doctor_uninstall "$uninstall")"
                found=1
                ;;
        esac
    done
    [ -n "$found" ] || printf '[ok] %s\n' "$id"
}

_doctor_traces() {
    local f found hooks name st
    found=""
    if _doctor_has_line "${_DOCTOR_TOP}/CLAUDE.md" '## graphify'; then
        _doctor_trace_warn trace-claude-md "$(_doctor_where "${_DOCTOR_TOP}/CLAUDE.md" "uninstall writes through") has a \"## graphify\" section (always-on mode)" "claude uninstall --project"
    else
        printf '[ok] trace-claude-md\n'
    fi
    if _doctor_has_line "${_DOCTOR_TOP}/AGENTS.md" '## graphify'; then
        _doctor_trace_warn trace-agents-md "$(_doctor_where "${_DOCTOR_TOP}/AGENTS.md" "uninstall writes through") has a \"## graphify\" section (always-on mode)" "codex uninstall"
    else
        printf '[ok] trace-agents-md\n'
    fi
    _doctor_hook_traces trace-pretooluse "claude uninstall --project" "${_DOCTOR_TOP}/.claude/settings.json" "${_DOCTOR_TOP}/.claude/settings.local.json"
    _doctor_hook_traces trace-codex-hooks "codex uninstall" "${_DOCTOR_TOP}/.codex/hooks.json"

    if [ -z "$_DOCTOR_GIT" ]; then
        if [ -n "$_DOCTOR_NOGIT" ]; then
            _doctor_not_checked trace-git-hooks
            _doctor_not_checked trace-merge-driver
        else
            printf '[ok] trace-git-hooks: not inside a git work tree\n'
            printf '[ok] trace-merge-driver: not inside a git work tree\n'
        fi
        return
    fi
    found=""
    if hooks="$(_atlas_git "$_DOCTOR_TOP" rev-parse --git-path hooks 2>/dev/null)" && [ -n "$hooks" ]; then
        case "$hooks" in /*) ;; *) hooks="${_DOCTOR_TOP}/${hooks}" ;; esac
        hooks="${hooks%/}"
        # Husky 9 points core.hooksPath at .husky/_; Graphify writes into
        # its parent, as its _user_hooks_dir does.
        case "$hooks" in */_) hooks="${hooks%/_}" ;; esac
        for name in post-commit post-checkout; do
            f="${hooks}/${name}"
            if _doctor_has_line "$f" '# graphify-hook-start' '# graphify-checkout-hook-start'; then
                _doctor_trace_warn trace-git-hooks "$(_doctor_where "$f" "uninstall writes through") has a graphify hook block" "hook uninstall"
                found=1
            fi
        done
        [ -n "$found" ] || printf '[ok] trace-git-hooks\n'
    else
        _doctor_warn trace-git-hooks "git cannot name the hooks directory of $(_atlas_printable "$_DOCTOR_TOP"); check post-commit and post-checkout there for a graphify block by hand."
    fi
    found=""
    if _atlas_git "$_DOCTOR_TOP" config --local --get merge.graphify.driver >/dev/null 2>&1; then
        _doctor_trace_warn trace-merge-driver "git config sets merge.graphify.driver" "hook uninstall"
        found=1
    fi
    f="${_DOCTOR_TOP}/.gitattributes"
    if _doctor_merge_attr "$f"; then
        _doctor_trace_warn trace-merge-driver "$(_doctor_where "$f" "uninstall writes through") routes graph.json to the graphify merge driver" "hook uninstall"
        found=1
    fi
    [ -n "$found" ] || printf '[ok] trace-merge-driver\n'
}

# --- .gitignore rows (through the shared script's scratch) -----------------
_doctor_gitignore() {
    local name id out rc
    for name in graphify-out .archify; do
        id="gitignore-${name#.}"
        if [ -n "$_DOCTOR_NOGIT" ]; then
            _doctor_not_checked "$id"
            continue
        fi
        if [ -z "$_DOCTOR_GIT" ]; then
            printf '[ok] %s: not inside a git work tree\n' "$id"
            continue
        fi
        rc=0
        out="$(_atlas_main_scratch "$name" "$_DOCTOR_TOP" 2>&1)" || rc=$?
        case "$rc:$out" in
            "0:[ignored] ${name}/") printf '[ok] %s\n' "$id" ;;
            "0:[n/a] "*) printf '[ok] %s: not inside a git work tree\n' "$id" ;;
            "0:[not-ignored] ${name}/")
                _doctor_warn "${id}: ${name}/ is not ignored in $(_atlas_printable "$_DOCTOR_TOP")." \
                    "Add the row ${name}/ to $(_doctor_q "${_DOCTOR_TOP}/.gitignore"), or to the file git rev-parse --git-path info/exclude names."
                ;;
            *) _doctor_warn "$id" "${out:-atlas-check.sh: the scratch check stopped without a line.}" ;;
        esac
    done
}

# --- Gemini keys, by name only ----------------------------------------------
_doctor_gemini() {
    local found=""
    if [ -n "${GEMINI_API_KEY:-}" ]; then
        _doctor_warn "gemini-key: GEMINI_API_KEY is set" \
            "With GEMINI_API_KEY set, a Graphify semantic pass that uses Gemini sends file contents to Google. Unset it if that is not wanted."
        found=1
    fi
    if [ -n "${GOOGLE_API_KEY:-}" ]; then
        _doctor_warn "gemini-key: GOOGLE_API_KEY is set" \
            "With GOOGLE_API_KEY set, a Graphify semantic pass that uses Gemini sends file contents to Google. Unset it if that is not wanted."
        found=1
    fi
    [ -n "$found" ] || printf '[ok] gemini-key\n'
}

# --- Graph freshness (the shared helper's provenance state) ----------------
_doctor_graph() {
    local out rc=0 a b
    if [ ! -e graphify-out/graph.json ] && [ ! -L graphify-out/graph.json ]; then
        printf '[ok] graph: no graphify-out/graph.json\n'
        return
    fi
    out="$(_atlas_main_provenance state "$_DOCTOR_CWD" 2>&1)" || rc=$?
    case "$rc:$out" in
        0:current) printf '[ok] graph: current\n' ;;
        0:semantic-stale)
            _doctor_warn "graph: semantic-stale" \
                "Documents, papers or images changed since the last full pass, or no full pass is recorded. Run \$map-repo for a full pass." ;;
        "0:stale "*)
            a="${out#stale }"
            b="${a#* }"
            a="${a%% *}"
            _doctor_warn "graph: stale (built at $(_atlas_printable "$a"), HEAD is $(_atlas_printable "$b"))" \
                "Run \$map-repo --update to refresh the code, or \$map-repo for a full pass." ;;
        0:dirty-build)
            _doctor_warn "graph: dirty-build" \
                "The graph was built from uncommitted changes or with files under graphify-out/memory/. Commit the changes and move those files out, then run \$map-repo." ;;
        0:unbound)
            _doctor_warn "graph: unbound" \
                "graphify-out/graph.json changed after its provenance record was written. Run \$map-repo to rebuild it." ;;
        0:missing)
            _doctor_warn "graph: missing" \
                "graphify-out/graph.json has no provenance record. Run \$map-repo to rebuild it." ;;
        *) _doctor_warn "graph: unknown" "$(_atlas_printable "${out:-atlas-check.sh: the provenance check stopped without a line.}")" ;;
    esac
}

doctor_main() {
    local id st=0
    if [ "$#" -ne 1 ] || [ "$1" != codex ]; then
        printf 'usage: doctor.sh codex\n' >&2
        return 2
    fi
    ATLAS_CLIENT=codex
    ATLAS_REA_ENV_WARN=1
    ATLAS_CONFIG_DIR="$HOME/.agents"
    case "$ATLAS_CONFIG_DIR" in
        /*) ;;
        *) printf 'doctor.sh: HOME is not an absolute path; set HOME to one.\n' >&2; return 2 ;;
    esac
    _atlas_fix_path || return 1
    for id in $ATLAS_DOCTOR_PREREQS; do
        "_atlas_check_${id//-/_}" || _DOCTOR_STATUS=1
    done
    # The interpreter the runner verifies, for the trace fix lines; the
    # graphify line above already reported any problem with it.
    _DOCTOR_PY=""
    if _DOCTOR_PY="$(PATH="${_ATLAS_ORIG_PATH-$PATH}" GRAPHIFY_NO_AUTO_REFRESH=1 \
        /bin/sh "${ATLAS_CONFIG_DIR}/skills/graphify/atlas-graphify.sh" --resolve </dev/null 2>/dev/null)"; then
        case "$_DOCTOR_PY" in /*) ;; *) _DOCTOR_PY="" ;; esac
    else
        _DOCTOR_PY=""
    fi
    _doctor_uv_constraints
    _doctor_rea
    _doctor_codex_config
    _doctor_migration

    _DOCTOR_CWD="$(pwd -P)" || _DOCTOR_CWD="$PWD"
    _DOCTOR_TOP="$_DOCTOR_CWD"
    _DOCTOR_GIT=""
    _DOCTOR_NOGIT=""
    _DOCTOR_GIT_REFUSED=""
    # git as the shared script finds it: an in-repo git prints its refusal
    # (a [missing] line) once, and the git checks then report no work tree.
    if _atlas_find_git; then
        if _atlas_in_work_tree "$_DOCTOR_CWD"; then
            _DOCTOR_GIT=1
            _DOCTOR_TOP="$(_atlas_git "$_DOCTOR_CWD" rev-parse --show-toplevel 2>/dev/null)" || _DOCTOR_TOP=""
            [ -n "$_DOCTOR_TOP" ] || { _DOCTOR_TOP="$_DOCTOR_CWD"; _DOCTOR_GIT=""; }
        fi
    else
        st=$?
        _DOCTOR_NOGIT=1
        if [ "$st" -eq 2 ]; then
            _DOCTOR_STATUS=1
            _DOCTOR_GIT_REFUSED=1
        fi
    fi
    _doctor_traces
    _doctor_gitignore
    _doctor_gemini
    if [ "$st" -eq 2 ]; then
        _doctor_warn "graph: unknown" "Not checked: the git found on PATH lies inside the repository (see the git line above)."
    else
        _doctor_graph
    fi
    return "$_DOCTOR_STATUS"
}

doctor_main "$@"
exit $?
