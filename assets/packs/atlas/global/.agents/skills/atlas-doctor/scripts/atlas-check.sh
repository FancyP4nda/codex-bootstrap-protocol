#!/usr/bin/env bash
# atlas-check.sh: the atlas pack's shared precondition script (PRD Part III
# FR-026, FR-029; AC-061, AC-065, AC-066, AC-094).
#
# Kit-authored, shipped with atlas-doctor. Every Command runs the subset of
# External Prerequisites it needs through it before any other action, and
# atlas-doctor runs all of them, so both print identical fix lines:
#
#   atlas-check.sh <client> check <prereq-id>...
#
# One line per prerequisite, in the order named: "[ok] <id>",
# "[missing] <id>" or "[warn] <id>", each [missing] and [warn] followed by
# its fix line on the next line. Exit 1 when any line is [missing], else 0
# ([warn] alone does not fail); exit 2 on a usage error, before any check.
#
# Two more subcommands serve the Commands that write scratch output:
#
#   atlas-check.sh <client> scratch <graphify-out|.archify> <path> [--apply gitignore|exclude|none]
#     FR-030's scratch-ignore check for <path>/<dir>/, before a Command
#     first writes it: "[ignored] <dir>/", "[not-ignored] <dir>/" (the
#     Command then asks the operator) or "[n/a] <dir>/: ..." outside a git
#     work tree. --apply, after the answer: gitignore appends the row
#     "<dir>/" to the work tree's top-level .gitignore, exclude to the file
#     git rev-parse --git-path info/exclude names (a linked worktree's
#     shared one), each printing "[added] <dir>/ to <file>"; none prints
#     the not-ignored warning. It writes only that one file, only on
#     --apply, and never through a symlink.
#   atlas-check.sh <client> provenance begin <path>
#   atlas-check.sh <client> provenance finish <path> <full|update> [semantic-declined]
#   atlas-check.sh <client> provenance state <path>
#     FR-032's provenance record for <path>/graphify-out/graph.json
#     (format 2: the graph's built_at_commit and the commit the record
#     vouches for, which differ only after a no-op update):
#     begin, before Graphify starts, writes only
#     graphify-out/.atlas-provenance-pending (with graph.json's digest);
#     finish, after it succeeds, writes only
#     graphify-out/atlas-provenance.json and removes the pending file (a
#     full build whose semantic pass the operator declined, with non-code
#     files present, adds semantic-declined: the record then says no clean
#     full pass happened and advances no semantic commit, so state reads
#     semantic-stale);
#     state prints one of current, semantic-stale,
#     "stale <record commit> <HEAD>", dirty-build, unbound or missing and
#     writes nothing. See "Provenance" below.
#
#   atlas-check.sh <client> rea-setup
#   atlas-check.sh <client> rea-doctor
#     FR-038's setup half of the REA Command contract: REA's MCP
#     registration and skill for this client, each by REA's client id
#     (atlas_rea_client maps the client name: claude to claude_code, codex
#     to codex; FR-028), as "[ok] rea-mcp" / "[missing] rea-mcp" and
#     "[ok] rea-skill" / "[missing] rea-skill", each [missing] followed by
#     the rea setup fix line; exit 1 when one is missing. rea-doctor (FR-039)
#     prints the same two lines for the Commands that diagnose the setup,
#     then a plain rea doctor's verdict on the configured providers. Neither
#     runs rea setup or rea update; both only read.
#
# FR-038's environment rule (the ATLAS-REA-ENV block below) runs before any
# rea call: on this process's own environment before check rea runs rea
# --version and before rea-setup and rea-doctor run rea doctor, and for
# rea-setup also on the environment of REA's MCP server. A refusal prints
# "[missing] rea" (check) or "[missing] rea-env" (the two modes) and the
# refusal line, exits 1 and makes no rea call; the doctor shows it as
# "[warn] rea-env" instead.
#
# Both exit 0 on a report, 1 after a line on a refusal or failure, 2 on a
# usage error. git is found like the tools checked here (an in-repo git is
# refused) and runs without optional locks or the fsmonitor hook; neither
# subcommand touches git config or hooks. Commands a repository-local
# .git/config names (a clean filter, say) are trusted like that config,
# which a clone does not carry; both refuse a repository git is
# missing for or does not read as a work tree, rather than call it outside
# git.
#
# A Command that maps a directory other than the one it started in (rea-map)
# sets ATLAS_START_DIR, the directory it started in (the boundary block turns
# it into a further untrusted area). scratch and provenance then treat the
# target as untrusted: one with a .git entry of its own, other than the started-in
# repository's root, is refused before any git call (its config would come
# from the target); inside a trusted parent checkout, a path that carries a
# filter attribute (a command git would run) makes the capture dirty and
# unpinned, and git is not asked for the state. With the variable unset
# (map-repo and the rest) nothing changes.
#
# Prerequisites (pack.yaml external_prerequisites; a static check holds the
# pins and fix lines below to pack.yaml and FR-029):
#   graphify      delegated: the Graphify runner, <config-dir>/skills/
#                 graphify/atlas-graphify.sh --resolve, is the one home of
#                 Graphify's pin, interpreter resolution and fix lines. Its
#                 exit 0 is [ok]; otherwise [missing] and its line,
#                 unchanged. This script holds no Graphify pin or fix line
#                 and never runs Graphify itself.
#   uv            presence (uv --version runs). hint_for graphify: reported
#                 with a missing graphify, or when named.
#   rea           exact, on_newer warn: newer is [warn] with the restore
#                 line, older (or unreadable) is [missing].
#   node-archify  floor; node-rea  range (both from node --version).
#   browser       ARCHIFY_CHROME when set (even empty), else what Archify's
#                 findChrome (skills/archify/bin/visual-check.mjs) tries: the
#                 app bundles on macOS, the PATH candidates elsewhere.
#
# The repository is untrusted (R-023 in the pack notes), as in the runner:
# before any lookup, PATH is cut to its absolute entries outside FR-031's
# untrusted area (the outermost git checkout around the working directory,
# or the working directory outside git; the ATLAS-BOUNDARY block below,
# byte-identical in the runner), and a tool found first on an absolute
# entry inside it is refused, naming it, so no command the checks run comes
# from the repository.
#
# <client> selects the config dir: codex is ~/.agents. This copy takes no other
# client; the Claude kit carries its own for claude (FR-047).
#
# check is read-only: it writes no file. No subcommand installs anything or
# runs a fix line, and only scratch --apply and provenance begin and finish
# write, each only the files named above. It prints no environment value
# of its own; the runner's GRAPHIFY_OUT
# refusal, passed on unchanged, names that variable's value. bash 3.2 or
# newer; check runs builtins and readlink only apart from the tools it
# checks, and scratch and provenance also run git, grep, sha256sum (or
# shasum), mkdir, mv and rm, all from the cut PATH.
# Sourcing it defines the functions without running a check (doctor.sh
# does so); a sourcing caller runs _atlas_fix_path before any _atlas_check_*
# function, stops when it returns non-zero (the system-directories line,
# already printed), and keeps the cut PATH it exports. The command that starts this
# script must not find bash through the repository either: a skill block
# finds bash on the runner's PATH and passes the PATH unchanged (SKILL.md).

ATLAS_IDS="graphify uv rea node-archify node-rea browser"
# ATLAS_REA_ENV_WARN is set only by doctor.sh, after it sources this file,
# and ATLAS_REA_SERVER_SCAN only by the rea-setup dispatch below: a value
# inherited from the environment must not downgrade or skip a refusal.
ATLAS_REA_ENV_WARN=""
ATLAS_REA_SERVER_SCAN=""
ATLAS_REA_PIN="6.4.0"
ATLAS_NODE_ARCHIFY_FLOOR="18"
ATLAS_NODE_REA_RANGE="^22.19.0 || ^24.11.0 || >=26.0.0"

# atlas_pin <id>: "<pin type><TAB><value><TAB><on_newer><TAB><hint_for>"
# for the ids whose pin lives here (the static check compares it with
# pack.yaml); graphify's lives in the runner.
atlas_pin() {
    case "$1" in
        uv) printf 'presence\t\t\tgraphify\n' ;;
        rea) printf 'exact\t%s\twarn\t\n' "$ATLAS_REA_PIN" ;;
        node-archify) printf 'floor\t%s\t\t\n' "$ATLAS_NODE_ARCHIFY_FLOOR" ;;
        node-rea) printf 'range\t%s\t\t\n' "$ATLAS_NODE_REA_RANGE" ;;
        browser) printf 'presence\t\t\t\n' ;;
        *) return 1 ;;
    esac
}

# _atlas_range_words: the node-rea range as prose, "a, b or c".
_atlas_range_words() {
    local rest="$ATLAS_NODE_REA_RANGE" part words="" n=0 last=""
    while [ -n "$rest" ]; do
        part="${rest%%||*}"
        if [ "$part" = "$rest" ]; then rest=""; else rest="${rest#*||}"; fi
        part="${part#"${part%%[! ]*}"}"
        part="${part%"${part##*[! ]}"}"
        [ -n "$last" ] && words="${words:+$words, }$last"
        last="$part"
        n=$((n + 1))
    done
    if [ "$n" -gt 1 ]; then
        printf '%s or %s\n' "$words" "$last"
    else
        printf '%s\n' "$last"
    fi
}

# atlas_fix_line <id> <variant> [<found>]: the FR-029 fix line.
#   uv missing; browser missing; mcp missing (REA MCP server or skill);
#   node-archify, node-rea: missing | found <v>;
#   rea: missing | older <v> | found <v> | newer <v>.
atlas_fix_line() {
    local rea_install="npm install --global rea-agents@${ATLAS_REA_PIN}"
    case "$1:$2" in
        uv:missing)
            printf '%s\n' "uv not found; Graphify installs with it. Install uv (https://docs.astral.sh/uv/), then re-run." ;;
        browser:missing)
            printf '%s\n' "No Chromium-family browser found; Archify's finalize step needs one. Install chromium, or set ARCHIFY_CHROME to a Chrome or Chromium executable." ;;
        mcp:missing)
            printf '%s\n' "REA MCP server or skill not set up for this client. Run: rea setup" ;;
        node-archify:missing)
            printf '%s\n' "Node >= ${ATLAS_NODE_ARCHIFY_FLOOR} not found. Install Node ${ATLAS_NODE_ARCHIFY_FLOOR} or later, then re-run." ;;
        node-archify:found)
            printf '%s\n' "Node >= ${ATLAS_NODE_ARCHIFY_FLOOR} not found (found $3). Install Node ${ATLAS_NODE_ARCHIFY_FLOOR} or later, then re-run." ;;
        node-rea:missing)
            printf '%s\n' "REA needs Node $(_atlas_range_words). Install a matching Node, then re-run." ;;
        node-rea:found)
            printf '%s\n' "REA needs Node $(_atlas_range_words) (found $3). Install a matching Node, then re-run." ;;
        rea:missing)
            printf '%s\n' "REA ${ATLAS_REA_PIN} not found. Install: ${rea_install}" ;;
        rea:older)
            printf '%s\n' "REA ${ATLAS_REA_PIN} not found (found older $3). Install: ${rea_install}" ;;
        rea:found)
            printf '%s\n' "REA ${ATLAS_REA_PIN} not found (found $3). Install: ${rea_install}" ;;
        rea:newer)
            printf '%s\n' "REA $3 is newer than the kit's pin ${ATLAS_REA_PIN} (off-pin, untested by the kit). To restore the pin: ${rea_install}, then rea setup" ;;
        *) return 1 ;;
    esac
}

# ATLAS-BOUNDARY-BEGIN
# FR-031's untrusted area, shared by the Graphify runner, the shared
# precondition script and the Archify wrapper (each kit-authored, under
# their skills), rea-android's tool helper and rea-binary's provider helper:
# this block is byte-identical in all five (a static check, AC-114), POSIX
# sh so that
# the sh scripts and the bash script run the same text, and none sources it
# from a file, since each must stand alone before PATH is trusted. The
# area is the outermost directory around the working directory that holds
# a .git entry (a linked worktree's or submodule's .git file included); /,
# $HOME (by its name and its resolved name) and its ancestors never count
# as that directory; with none, as outside git, it is the working
# directory. It is found from the physical (pwd -P) and the logical ($PWD)
# name alike, with builtins only: git would be looked up on the PATH being
# checked. A Command that moves into another directory (rea-map) keeps the
# area it started in untrusted too: it passes the directory it started in
# as ATLAS_START_DIR (absolute), and the block finds that directory's area
# the same way, by its physical and its logical name alike, and adds both as
# further areas (it only ever widens the untrusted set). Every _AB variable belongs to this block.
#
# _atlas_slash <path>: the path with its leading slashes cut to one, in
# _ABS (a shell may keep a leading "//", which POSIX allows).
_atlas_slash() {
    _ABS="$1"
    while :; do
        case "$_ABS" in //*) _ABS="${_ABS#/}" ;; *) break ;; esac
    done
}
# _atlas_walk <directory>: the area around it, in _ABW.
_atlas_walk() {
    _ABD="$1"
    _ABW=""
    while :; do
        if [ "$_ABD" != / ] && [ -e "$_ABD/.git" ]; then
            case "$_ABH" in
                "$_ABD" | "$_ABD"/*) ;;
                *) case "$_ABHR" in "$_ABD" | "$_ABD"/*) ;; *) _ABW="$_ABD" ;; esac ;;
            esac
        fi
        [ "$_ABD" = / ] && break
        _ABD="${_ABD%/*}"
        [ -n "$_ABD" ] || _ABD=/
    done
    [ -n "$_ABW" ] || _ABW="$1"
}
# _atlas_area_init: the areas from both names of the working directory, in
# _ABP and _ABL. Returns 1, after the system-directories line, when an area
# holds /usr/bin or /bin: then even the fallback PATH could be the
# repository's, so nothing may be looked up.
_atlas_area_init() {
    _ABH=""
    _ABHR=""
    case "${HOME:-}" in
        /*)
            _atlas_slash "$HOME"
            _ABH="$_ABS"
            if _ABHR=$(cd -P "$HOME" 2>/dev/null && pwd -P); then
                _atlas_slash "$_ABHR"
                _ABHR="$_ABS"
            fi
            ;;
    esac
    _ABP=$(pwd -P 2>/dev/null) || _ABP=/
    _atlas_slash "${_ABP:-/}"
    _atlas_walk "$_ABS"
    _ABP="$_ABW"
    _ABL="$_ABP"
    case "${PWD:-}" in
        /*) _atlas_slash "$PWD"; _atlas_walk "$_ABS"; _ABL="$_ABW" ;;
    esac
    _ABX=""
    _ABY=""
    case "${ATLAS_START_DIR:-}" in
        /*)
            _ABX=$(cd -P "$ATLAS_START_DIR" 2>/dev/null && pwd -P) || _ABX="$ATLAS_START_DIR"
            _atlas_slash "$_ABX"
            _atlas_walk "$_ABS"
            _ABX="$_ABW"
            _atlas_slash "$ATLAS_START_DIR"
            _atlas_walk "$_ABS"
            _ABY="$_ABW"
            # $HOME and its ancestors are not a repository: a start there
            # adds no area (the target's own area still applies).
            case "$_ABH" in "$_ABX" | "$_ABX"/*) _ABX="" ;; esac
            case "$_ABHR" in "$_ABX" | "$_ABX"/*) _ABX="" ;; esac
            case "$_ABH" in "$_ABY" | "$_ABY"/*) _ABY="" ;; esac
            case "$_ABHR" in "$_ABY" | "$_ABY"/*) _ABY="" ;; esac
            ;;
    esac
    if _inside /usr/bin || _inside /bin; then
        _atlas_shown "$_ABHIT"
        printf '%s\n' "$_ABV holds /usr/bin or /bin, so atlas can't keep repository tools apart from system ones; run this from the project directory."
        return 1
    fi
    return 0
}
# _inside <path>: true when the path, by its name, lies at or below either
# area; _ABHIT is then that area. Builtins only, so the PATH cut can use it.
_inside() {
    _atlas_slash "$1"
    _ABI="$_ABS"
    for _ABC in "$_ABP" "$_ABL" "${_ABX:-$_ABP}" "${_ABY:-$_ABP}"; do
        if [ "$_ABC" = / ]; then
            _ABHIT=/
            return 0
        fi
        case "$_ABI" in "$_ABC" | "$_ABC"/*) _ABHIT="$_ABC"; return 0 ;; esac
    done
    return 1
}
# _inside_path <path>: true when the path, its directory resolved, or any
# step of its symlinks (at most 40) lies inside. Runs readlink, so call it
# only once PATH is cut.
_inside_path() {
    _ABF="$1"
    _ABN=0
    while :; do
        _inside "$_ABF" && return 0
        _ABR=$(cd -P "${_ABF%/*}/" 2>/dev/null && pwd -P) && _inside "$_ABR" && return 0
        [ -L "$_ABF" ] && [ "$_ABN" -lt 40 ] || return 1
        # A link that cannot be read counts as inside (fails closed).
        if ! _ABT=$(readlink "$_ABF") || [ -z "$_ABT" ]; then
            _ABHIT="$_ABP"
            return 0
        fi
        case "$_ABT" in /*) _ABF="$_ABT" ;; *) _ABF="${_ABF%/*}/$_ABT" ;; esac
        _ABN=$((_ABN + 1))
    done
}
# _atlas_shown <path>: the path for a refusal line, in _ABV: a name with a
# control character (one the repository could choose, outside git) is
# replaced, so it cannot drive the terminal.
_atlas_shown() {
    case "$1" in
        *[[:cntrl:]]*) _ABV="(a path with control characters)" ;;
        *) _ABV="$1" ;;
    esac
}
# _untrusted_line <path>: FR-031's refusal for a path found inside, after
# _inside or _inside_path returned true for it.
_untrusted_line() {
    _atlas_shown "$_ABHIT"
    printf '%s\n' "$1 lies inside $_ABV, which atlas treats as the repository, so the repository could supply it; take that directory off PATH, or run this from the project directory."
}
# ATLAS-BOUNDARY-END

# ATLAS-REA-ENV-BEGIN
# FR-038's environment rule: REA passes its environment to every tool it
# starts (Java, apktool, Ghidra's and JADX's launchers, shells), and those
# runtimes load code named in it. So no REA call runs until the two
# environments REA and its tools will see pass two rules: no variable that
# loads code is set, and no variable names a path inside FR-031's untrusted
# area (REA reads paths under names no list keeps up with, so every
# variable is a possible path; only four names are exempt). For the
# server's environment that area is the union of this process's and the
# one around the server's own working directory. This block is
# byte-identical in the shared precondition script,
# rea-binary's provider helper and rea-android's tool helper (a static
# check, AC-114), POSIX sh, and uses the ATLAS-BOUNDARY block's functions,
# so a caller runs _atlas_area_init before any of it. Every _REE variable
# belongs to this block; _REETAG, set by the caller, prefixes the reasons a
# fail-closed stop prints.
#
# The two environments:
#   _rea_env_self    this process's own, as env prints it once PATH is cut
#                    (what a rea it starts receives), in _REE, and its
#                    working directory in _REECWD.
#   _rea_env_server  the environment of REA's MCP server as Codex's
#                    configuration starts it (the [mcp_servers.rea] entry
#                    of the closest .codex/config.toml, else CODEX_HOME's;
#                    no process id is read), in _REE, its working directory
#                    in _REECWD, and the area around that directory, by
#                    its physical name and by the snapshot's PWD when
#                    that names it, in _REESP and _REESL. It prints why
#                    and returns 1
#                    when it cannot be read with certainty: no entry, an
#                    entry this reader can't parse or that does not run
#                    "rea mcp", a relative CODEX_HOME, a cwd that can't be
#                    entered, a value holding a line break.
# _rea_env_scan then checks _REE, as the reader just before it left it, and
# prints one refusal line per variable, naming it and never its value; it
# returns 1 on a refusal and, with the reason, on a name set twice or, for
# this process's own environment, a line that is not NAME=value (a value
# holding a line break). It also checks the Java executable a REA call in
# that environment can probe, naming JAVA_HOME or PATH. _rea_java checks
# that Java exists, where REA needs one. Nothing here runs a tool apart
# from env, tr and readlink, from the cut PATH.
_rea_say() {
    printf '%s: %s\n' "${_REETAG:-rea-env}" "$1"
}
_rea_env_self() {
    _REEKIND=self
    _REEW="this shell's environment"
    _REELB=""
    # Relative values and empty PATH entries resolve from here.
    _REECWD=$(pwd -P 2>/dev/null)
    case "$_REECWD" in
        /*) ;;
        *)
            _rea_say "can't read this shell's working directory, so what REA would see can't be checked; nothing run."
            return 1
            ;;
    esac
    _REE=$(env 2>/dev/null) || {
        _rea_say "can't read this shell's environment (env failed), so what REA would see can't be checked; nothing run."
        return 1
    }
    # Where env -0 works, a value holding a line break is seen exactly, as
    # the server's is. Elsewhere _rea_env_scan refuses a line of env's text
    # that is not NAME=value.
    _REER=$({ env -0 | tr -d '\000'; } 2>/dev/null)
    case "$_REER" in
        *'
'*) _REELB=1 ;;
    esac
}
# Codex's discovery of REA's MCP server (T053 round 5). The Claude kit finds
# the server as a child of its agent's process and reads that process's
# environment from /proc; a Codex session has no such agent id, and an
# inherited one would name another agent's server. Here the snapshot comes from the configuration Codex starts
# the server from: the [mcp_servers.rea] entry of the closest .codex/config.toml
# on the way up from this directory, else $CODEX_HOME/config.toml (default
# ~/.codex). Its command and args must run "rea mcp", its cwd is the server's
# working directory (default: this one), and its environment is what Codex
# gives a stdio server: the variables of its default list and the entry's
# env_vars, taken from this process's own environment (already checked), then
# the entry's env table over them. Only plain TOML is read: [mcp_servers.rea]
# and [mcp_servers.rea.env] tables, one-line strings without backslash
# escapes, one-line arrays and inline tables. Anything else, and a missing
# entry, fails closed with a line that names the file.
_rea_ltrim() {
    while :; do
        case "$_REETR" in
            ' '* | "$_REETB"*) _REETR=${_REETR#?} ;;
            *) break ;;
        esac
    done
}
# _rea_tstr <text>: the one-line quoted string at the start of text, in
# _REETV, the rest in _REETR. A basic string with a backslash is refused.
_rea_tstr() {
    _REETR=$1
    case "$_REETR" in
        \"*) _REETQ='"' ;;
        \'*) _REETQ="'" ;;
        *) return 1 ;;
    esac
    _REETR=${_REETR#?}
    _REETV=${_REETR%%"$_REETQ"*}
    [ "$_REETV" != "$_REETR" ] || return 1
    case "$_REETV" in
        *\\*) [ "$_REETQ" != '"' ] || return 1 ;;
    esac
    _REETR=${_REETR#"$_REETV"?}
}
# _rea_tend: nothing but a comment follows.
_rea_tend() {
    _rea_ltrim
    case "$_REETR" in '' | '#'*) return 0 ;; esac
    return 1
}
# _rea_tarr <text>: a one-line array of strings, one per line in _REETL.
_rea_tarr() {
    _REETR=${1#\[}
    _REETL=""
    while :; do
        _rea_ltrim
        case "$_REETR" in
            \]*)
                _REETR=${_REETR#?}
                break
                ;;
            ,*)
                _REETR=${_REETR#?}
                continue
                ;;
        esac
        _rea_tstr "$_REETR" || return 1
        _REETL="$_REETL$_REETV$_REENL"
    done
    _rea_tend
}
# _rea_tname <text>: the text without quotes and blanks, in _REEN (a table
# or key name as TOML's dotted form writes it).
_rea_tname() {
    _REEN=$1
    while :; do
        case "$_REEN" in
            *\"*) _REEN=${_REEN%%\"*}${_REEN#*\"} ;;
            *\'*) _REEN=${_REEN%%\'*}${_REEN#*\'} ;;
            *' '*) _REEN=${_REEN%%' '*}${_REEN#*' '} ;;
            *"$_REETB"*) _REEN=${_REEN%%"$_REETB"*}${_REEN#*"$_REETB"} ;;
            *) break ;;
        esac
    done
}
# _rea_tpair <name> <text>: NAME=value of a string value, appended to _REEEP.
_rea_tpair() {
    case "$1" in '' | *[!A-Za-z0-9_]* | [0-9]*) return 1 ;; esac
    _rea_tstr "$2" && _rea_tend || return 1
    _REEEP="$_REEEP$1=$_REETV$_REENL"
}
# _rea_ttab <text>: a one-line inline table of strings, appended to _REEEP.
_rea_ttab() {
    _REETR=${1#\{}
    while :; do
        _rea_ltrim
        case "$_REETR" in
            \}*)
                _REETR=${_REETR#?}
                break
                ;;
            ,*)
                _REETR=${_REETR#?}
                continue
                ;;
        esac
        _REETK=${_REETR%%[!A-Za-z0-9_-]*}
        if [ -n "$_REETK" ]; then
            _REETR=${_REETR#"$_REETK"}
        else
            _rea_tstr "$_REETR" || return 1
            _REETK=$_REETV
        fi
        _rea_ltrim
        case "$_REETR" in =*) _REETR=${_REETR#?} ;; *) return 1 ;; esac
        _rea_ltrim
        _rea_tstr "$_REETR" || return 1
        case "$_REETK" in '' | *[!A-Za-z0-9_]* | [0-9]*) return 1 ;; esac
        _REEEP="$_REEEP$_REETK=$_REETV$_REENL"
    done
    _rea_tend
}
# _rea_cfg_read <file>: the [mcp_servers.rea] keys of one config file.
# Returns 0 with the keys it sets in _REEC (command), _REEARGS (one per line,
# _REEHAVE set), _REEEV (env_vars names, one per line, _REEEVSET set), _REEEP
# (env, NAME=value per line) and _REECW (cwd), each empty when the file does
# not set it; 1 when the file has no such entry; 2 with the reason in
# _REEWHY.
_rea_cfg_read() {
    _REEWHY=""
    _REEFOUND=""
    _REEFORM=""
    _REEC=""
    _REEARGS=""
    _REEEV=""
    _REEEP=""
    _REECW=""
    _REEHAVE=""
    _REEEVSET=""
    _REEENVT=""
    _REEBL=top
    [ -r "$1" ] || return 1
    while IFS= read -r _REEL || [ -n "$_REEL" ]; do
        _REEL=${_REEL%"$_REECR"}
        _REETR=$_REEL
        _rea_ltrim
        _REEL=$_REETR
        case "$_REEL" in
            '' | '#'*) continue ;;
            '[['*)
                _REEBL=other
                continue
                ;;
            '['*)
                _REEN=${_REEL#\[}
                _REEN=${_REEN%%\]*}
                _rea_tname "$_REEN"
                case "$_REEN" in
                    mcp_servers.rea)
                        if [ -n "$_REEFOUND" ]; then
                            _REEWHY="is set in two tables"
                            return 2
                        fi
                        _REEFOUND=1
                        _REEBL=main
                        ;;
                    mcp_servers.rea.env)
                        _REEBL=env
                        _REEENVT=1
                        ;;
                    mcp_servers.rea.*)
                        _REEBL=other
                        _REEFORM=1
                        ;;
                    mcp_servers) _REEBL=servers ;;
                    *) _REEBL=other ;;
                esac
                continue
                ;;
        esac
        case "$_REEL" in *=*) ;; *) continue ;; esac
        _REEK=${_REEL%%=*}
        _REETR=${_REEL#*=}
        _rea_ltrim
        _REEV=$_REETR
        _rea_tname "$_REEK"
        _REEK=$_REEN
        case "$_REEBL" in
            top)
                case "$_REEK" in mcp_servers.rea | mcp_servers.rea.*) _REEFORM=1 ;; esac
                ;;
            servers)
                case "$_REEK" in rea | rea.*) _REEFORM=1 ;; esac
                ;;
            env)
                if ! _rea_tpair "$_REEK" "$_REEV"; then
                    _REEWHY="has an [mcp_servers.rea.env] line this check can't read (one NAME = \"value\" per line)"
                    return 2
                fi
                ;;
            main)
                case "$_REEK" in
                    command)
                        if [ -n "$_REEC" ] || ! { _rea_tstr "$_REEV" && _rea_tend; }; then
                            _REEWHY="has a command that is not set once as a one-line string without backslashes"
                            return 2
                        fi
                        _REEC=$_REETV
                        ;;
                    cwd)
                        if ! { _rea_tstr "$_REEV" && _rea_tend; }; then
                            _REEWHY="has a cwd that is not a one-line string without backslashes"
                            return 2
                        fi
                        _REECW=$_REETV
                        ;;
                    args)
                        if ! _rea_tarr "$_REEV"; then
                            _REEWHY="has args that are not a one-line array of strings"
                            return 2
                        fi
                        _REEARGS=$_REETL
                        _REEHAVE=1
                        ;;
                    env_vars)
                        # The names Codex passes on from the session. They
                        # only widen the snapshot with variables the session's
                        # own check covered, so a list spread over lines is
                        # left out rather than refused.
                        if _rea_tarr "$_REEV"; then
                            _REEEV=$_REETL
                            _REEEVSET=1
                        fi
                        ;;
                    env)
                        if ! _rea_ttab "$_REEV"; then
                            _REEWHY="has an env table that is not a one-line inline table of strings"
                            return 2
                        fi
                        ;;
                    env.*)
                        if ! _rea_tpair "${_REEK#env.}" "$_REEV"; then
                            _REEWHY="has an env line that is not a one-line string"
                            return 2
                        fi
                        ;;
                esac
                ;;
        esac
    done <"$1"
    # A layer may hold only part of the entry (Codex merges the layers per
    # key), so completeness is checked on the merged entry, not here.
    if [ -n "$_REEFOUND$_REEENVT" ]; then
        return 0
    fi
    if [ -n "$_REEFORM" ]; then
        _REEWHY="is written in a form this check can't read; write it as a [mcp_servers.rea] table"
        return 2
    fi
    return 1
}
# _rea_isrea_script <path>: REA's entry script by name (bin "rea" or
# "rea-agents", or scripts/rea.mjs in the package).
_rea_isrea_script() {
    case "${1##*/}" in
        rea | rea-agents) return 0 ;;
        rea.mjs) case "$1" in /*/scripts/rea.mjs) return 0 ;; esac ;;
    esac
    return 1
}
# _rea_cfg_isrea: command and args are one of the registrations rea-agents
# 6.4.0 writes (SetupHost.js, ClientRegistrationIdentity.js), each checked by
# its exact arguments:
#   rea mcp | rea-agents mcp | <abs>/rea mcp | <abs>/scripts/rea.mjs mcp
#   <abs>/node <abs>/rea|rea-agents|scripts/rea.mjs mcp
#   npx -y rea-agents[@latest|@6.4.0] mcp
_rea_cfg_isrea() {
    _REEPIN=6.4.0
    _REEJ=${_REEARGS%"$_REENL"}
    _REEAN=0
    _REET=$_REEARGS
    while [ -n "$_REET" ]; do
        _REET=${_REET#*"$_REENL"}
        _REEAN=$((_REEAN + 1))
    done
    _REEA1=${_REEJ%%"$_REENL"*}
    _REEA2=""
    _REEA3=""
    if [ "$_REEAN" -ge 2 ]; then
        _REET=${_REEJ#*"$_REENL"}
        _REEA2=${_REET%%"$_REENL"*}
    fi
    if [ "$_REEAN" -ge 3 ]; then
        _REET=${_REEJ#*"$_REENL"}
        _REET=${_REET#*"$_REENL"}
        _REEA3=${_REET%%"$_REENL"*}
    fi
    case "$_REEAN:$_REEC" in
        1:rea | 1:rea-agents)
            [ "$_REEA1" = mcp ] && return 0
            ;;
        1:/*)
            [ "$_REEA1" = mcp ] && _rea_isrea_script "$_REEC" && return 0
            ;;
        2:/*)
            [ "${_REEC##*/}" = node ] && [ "$_REEA2" = mcp ] && case "$_REEA1" in /*) _rea_isrea_script "$_REEA1" && return 0 ;; esac
            ;;
        3:npx)
            [ "$_REEA1" = -y ] && [ "$_REEA3" = mcp ] || return 1
            case "$_REEA2" in
                rea-agents | rea-agents@latest | "rea-agents@$_REEPIN") return 0 ;;
            esac
            ;;
    esac
    return 1
}
# _rea_layer <file> <project>: one config layer's [mcp_servers.rea] keys,
# merged over the earlier layers as Codex does: per key, the later layer
# wins, an array (args, env_vars) is replaced whole, and the env table is
# merged name by name. Returns 0 when the layer was merged, 1 when it
# holds no entry or is ignored (a project layer of an untrusted project),
# 2 after a named line when it can't be read.
_rea_layer() {
    _rea_cfg_read "$1"
    _REERC=$?
    if [ "$2" = project ] && [ "$_REERC" -ne 1 ] && [ "$_REETRUST" != yes ]; then
        if [ "$_REETRUST" = no ]; then
            return 1
        fi
        _rea_say "$1 sets an [mcp_servers.rea] entry, but whether Codex trusts the project $_REEROOT can't be read from the [projects] tables of $_REEHOME/config.toml, so REA's MCP server can't be checked; nothing checked."
        return 2
    fi
    case $_REERC in
        0) ;;
        2)
            _rea_say "the [mcp_servers.rea] entry in $1 $_REEWHY, so REA's MCP server can't be checked; nothing checked."
            return 2
            ;;
        *) return 1 ;;
    esac
    [ -z "$_REEC" ] || _REEMC=$_REEC
    if [ -n "$_REEHAVE" ]; then
        _REEMA=$_REEARGS
        _REEMHAVE=1
    fi
    [ -z "$_REEEVSET" ] || _REEMEV=$_REEEV
    if [ -n "$_REECW" ]; then
        _REEMCW=$_REECW
        _REEMCWFILE=$1
    fi
    _REEMT=""
    while IFS= read -r _REEL; do
        [ -n "$_REEL" ] || continue
        case "$_REENL$_REEEP" in
            *"$_REENL${_REEL%%=*}="*) continue ;;
        esac
        _REEMT="$_REEMT$_REEL$_REENL"
    done <<EOF
$_REEMEP
EOF
    _REEMEP="$_REEMT$_REEEP"
    _REEFILE="${_REEFILE:+$_REEFILE, }$1"
    _REEANY=1
    return 0
}
# _rea_layers <dir>: the project layers from the project root down to dir,
# the root's first. Each candidate path is read directly, quoted, as the
# recursion unwinds; no list of paths is built.
_rea_layers() {
    if [ "$1" != "$_REEROOT" ]; then
        _REEUP=${1%/*}
        [ -n "$_REEUP" ] || _REEUP=/
        _rea_layers "$_REEUP" || return 2
    fi
    _rea_layer "$1/.codex/config.toml" project
    [ $? -ne 2 ]
}
# _rea_user_scan <file>: from the user's config.toml, project_root_markers
# (in _REEMARK, one per line, default ".git") and whether Codex trusts the
# project at _REEROOT (_REETRUST: yes, no, or unknown when the file's
# [projects] tables are in a form this reader can't take).
_rea_user_scan() {
    _REEMARK=".git"
    _REETRUST=no
    [ -r "$1" ] || return 0
    _REEPB=""
    _REEPU=""
    _REEPL=""
    _REETOPL=1
    while IFS= read -r _REEL || [ -n "$_REEL" ]; do
        _REEL=${_REEL%"$_REECR"}
        _REETR=$_REEL
        _rea_ltrim
        _REEL=$_REETR
        case "$_REEL" in
            '' | '#'*) continue ;;
            '[['*)
                _REEPB=""
                _REETOPL=""
                continue
                ;;
            '['*)
                _REEPB=""
                _REETOPL=""
                case "$_REEL" in
                    '[projects]'* | '[ projects ]'*) _REEPU=1 ;;
                    '[projects.'*)
                        if _rea_tstr "${_REEL#\[projects.}" && case "$_REETR" in \]*) true ;; *) false ;; esac; then
                            if [ -n "$_REEROOT" ] && { [ "$_REETV" = "$_REEROOT" ] || [ "$_REETV" = "$_REEROOT/" ]; }; then
                                _REEPB=1
                            fi
                        else
                            _REEPU=1
                        fi
                        ;;
                esac
                continue
                ;;
        esac
        case "$_REEL" in *=*) ;; *) continue ;; esac
        _REEK=${_REEL%%=*}
        _REETR=${_REEL#*=}
        _rea_ltrim
        _REEV=$_REETR
        _rea_tname "$_REEK"
        case "$_REEN" in
            project_root_markers)
                if [ -z "$_REETOPL" ]; then
                    :
                elif _rea_tarr "$_REEV"; then
                    _REEMARK=$_REETL
                else
                    _REEPU=1
                fi
                ;;
            projects | projects.*) _REEPU=1 ;;
            trust_level)
                if [ -n "$_REEPB" ]; then
                    if _rea_tstr "$_REEV" && _rea_tend; then
                        _REEPL=$_REETV
                    else
                        _REEPU=1
                    fi
                fi
                ;;
        esac
    done <"$1"
    if [ -n "$_REEPL" ]; then
        [ "$_REEPL" = trusted ] && _REETRUST=yes
    elif [ -n "$_REEPU" ]; then
        _REETRUST=unknown
    fi
    return 0
}
_rea_env_server() {
    _REEKIND=server
    _REEW="the environment of REA's MCP server"
    _REECWD=""
    _REELB=""
    _REENL='
'
    _REECR=$(printf '\r')
    _REETB=$(printf '\t')
    _REESS=$(pwd -P 2>/dev/null)
    case "$_REESS" in
        /*) ;;
        *)
            _rea_say "can't read this shell's working directory, so REA's MCP server can't be found; nothing checked."
            return 1
            ;;
    esac
    _REEHOME=${CODEX_HOME:-${HOME-}/.codex}
    case "$_REEHOME" in
        /*) ;;
        *)
            _rea_say "CODEX_HOME (or HOME) is not an absolute path, so Codex's config.toml can't be found and REA's MCP server can't be checked; nothing checked. Set it to an absolute path."
            return 1
            ;;
    esac
    # Codex's layering (Advanced Configuration, "Project config files"): the
    # user's config.toml, then the .codex/config.toml of each directory from the
    # project root down to this one, closest last, merged per key. Project
    # layers count only when the user's config marks the project trusted.
    _REEROOT=""
    _rea_user_scan "$_REEHOME/config.toml"
    _REED=$_REESS
    while :; do
        while IFS= read -r _REEMK; do
            case "$_REEMK" in '' | */*) continue ;; esac
            if [ -e "$_REED/$_REEMK" ]; then
                _REEROOT=$_REED
                break
            fi
        done <<EOF
$_REEMARK
EOF
        [ -z "$_REEROOT" ] || break
        [ "$_REED" = / ] && break
        _REED=${_REED%/*}
        [ -n "$_REED" ] || _REED=/
    done
    [ -n "$_REEROOT" ] || _REEROOT=$_REESS
    _rea_user_scan "$_REEHOME/config.toml"
    _REEMC=""
    _REEMA=""
    _REEMHAVE=""
    _REEMEV=""
    _REEMEP=""
    _REEMCW=""
    _REEMCWFILE=""
    _REEFILE=""
    _REEANY=""
    _rea_layer "$_REEHOME/config.toml" user
    [ $? -ne 2 ] || return 1
    _rea_layers "$_REESS" || return 1
    [ -n "$_REEANY" ] || {
        _rea_say "found no [mcp_servers.rea] entry in $_REEHOME/config.toml or in a trusted project's .codex/config.toml from $_REEROOT down to this directory, so REA's MCP server can't be checked; nothing checked. Run: rea setup"
        return 1
    }
    if [ -z "$_REEMC" ] || [ -z "$_REEMHAVE" ]; then
        _rea_say "the [mcp_servers.rea] entry ($_REEFILE, merged as Codex layers them) has no command, or no args array on one line, so REA's MCP server can't be checked; nothing checked."
        return 1
    fi
    _REEC=$_REEMC
    _REEARGS=$_REEMA
    _REEEV=$_REEMEV
    _REEEP=$_REEMEP
    _REECW=$_REEMCW
    _rea_cfg_isrea || {
        _rea_say "the [mcp_servers.rea] entry ($_REEFILE) does not run \"rea mcp\" in a form rea-agents $_REEPIN registers (command, then args), so it is not recognised as REA's MCP server; nothing checked."
        return 1
    }
    # What Codex gives a stdio server: its default variables and env_vars
    # from the session (this process's own environment, checked before this),
    # then the entry's env over them.
    _REEO=$(env 2>/dev/null) || {
        _rea_say "can't read this shell's environment (env failed), so what REA's MCP server would see can't be checked; nothing checked."
        return 1
    }
    _REE=""
    for _REEK in HOME LOGNAME PATH SHELL USER __CF_USER_TEXT_ENCODING LANG LC_ALL TERM TMPDIR TZ $_REEEV; do
        case "$_REENL$_REEEP" in
            *"$_REENL$_REEK="*) continue ;;
        esac
        while IFS= read -r _REEL; do
            case "$_REEL" in
                "$_REEK="*)
                    _REE="$_REE$_REEL$_REENL"
                    break
                    ;;
            esac
        done <<EOF
$_REEO
EOF
    done
    _REE="$_REE$_REEEP"
    _REE=${_REE%"$_REENL"}
    # The raw text without its separators, for the line-break check that follows.
    _REER=$(printf '%s' "$_REE" | tr -d '\n')
    if [ -n "$_REECW" ]; then
        case "$_REECW" in
            /*) ;;
            *)
                _rea_say "the cwd of the [mcp_servers.rea] entry in $_REEMCWFILE is not an absolute path, so the area around REA's MCP server is unknown; nothing checked. Write an absolute cwd."
                return 1
                ;;
        esac
        _REECWD=$(cd -P "$_REECW" 2>/dev/null && pwd -P) && [ -n "$_REECWD" ] || {
            _rea_say "the cwd of the [mcp_servers.rea] entry in $_REEMCWFILE can't be entered, so the area around REA's MCP server is unknown; nothing checked."
            return 1
        }
    else
        _REECWD=$_REESS
    fi
    _REEM="its config entry"
    case "$_REER" in
        *"$_REENL"*)
            _rea_say "a value in the environment of REA's MCP server holds a line break, so what REA reads can't be checked; nothing checked. Change it where Codex started the server (or in the env of REA's MCP registration), then restart Codex."
            return 1
            ;;
    esac
    # A removed working directory reads as "<path> (deleted)": its area,
    # and what relative values name, are unknown.
    case "$_REECWD" in
        *' (deleted)' | [!/]*)
            _rea_say "the working directory of REA's MCP server (from its config entry) was removed or can't be read as a path, so the area around it is unknown; nothing checked. Restart Codex from the project directory."
            return 1
            ;;
    esac
    # The server's own area, from both names of its working directory: a
    # server started in another checkout must not run that checkout's tools.
    _atlas_slash "$_REECWD"
    _atlas_walk "$_ABS"
    _REESP=$_ABW
    _REESL=$_REESP
    # The snapshot's PWD is its logical name only when it names that same
    # directory, as a shell checks before trusting PWD: a launcher can leave
    # a stale one (/, $HOME) that names another and would widen the area.
    if _rea_env_get PWD; then
        case "$_REEG" in
            /*)
                if _REEX=$(cd -P "$_REEG" 2>/dev/null && pwd -P) && [ "$_REEX" = "$_REECWD" ]; then
                    _atlas_slash "$_REEG"
                    _atlas_walk "$_ABS"
                    _REESL=$_ABW
                fi
                ;;
        esac
    fi
}
# _rea_env_get <name>: true when _REE sets it (the first line that does);
# the value in _REEG.
_rea_env_get() {
    while IFS= read -r _REEL; do
        case "$_REEL" in
            "$1="*)
                _REEG=${_REEL#*=}
                return 0
                ;;
        esac
    done <<EOF
$_REE
EOF
    return 1
}
# _rea_norm <absolute path>: the path with its "." and ".." segments
# removed by their text, as Node's path.normalize and REA's path joins
# remove them, in _REEO.
_rea_norm() {
    _REEO=""
    _REEY="${1#/}/"
    while [ -n "$_REEY" ]; do
        _REEK=${_REEY%%/*}
        _REEY=${_REEY#*/}
        case "$_REEK" in
            '' | .) ;;
            ..) _REEO=${_REEO%/*} ;;
            *) _REEO="$_REEO/$_REEK" ;;
        esac
    done
    [ -n "$_REEO" ] || _REEO=/
}
# _rea_hit_form <absolute path>: true when it lies inside the areas
# _inside checks: by its name, by its directory resolved or a step of its
# symlinks, or, for a directory, resolved itself. _REEH is then the area.
_rea_hit_form() {
    if _inside_path "$1"; then
        _REEH=$_ABHIT
        return 0
    fi
    if [ -d "$1" ] && _REEX=$(cd -P "$1" 2>/dev/null && pwd -P) && _inside "$_REEX"; then
        _REEH=$_ABHIT
        return 0
    fi
    return 1
}
# _rea_hit_here: _REEA2, an absolute path, in two forms, each given the
# whole check: as written, which the kernel resolves, and with "." and ".."
# removed by their text, which REA runs (/proc/self/status/../cwd is
# /proc/self/cwd to REA, and a missing directory before ".." can hide a
# link).
_rea_hit_here() {
    _rea_hit_form "$_REEA2" && return 0
    _rea_norm "$_REEA2"
    [ "$_REEO" != "$_REEA2" ] && _rea_hit_form "$_REEO"
}
# _rea_cand_hit <candidate>: true when it names a path inside the area, in
# _REEH. One starting with / is absolute. Any other is resolved from the
# environment's working directory (_REECWD): in a search path (_REESR set),
# every entry, whether it names anything or not; elsewhere only one holding
# a / or starting with "." that names an existing path in either form, so
# a bare word (CLAUDE_CODE_ENTRYPOINT=cli, LANG=C.UTF-8) is never a path
# there. The server's environment is held to the union of this process's
# area and the server's own (_REESP, _REESL).
_rea_cand_hit() {
    case "$1" in
        '') return 1 ;;
        /*) _REEA2=$1 ;;
        *)
            if [ -z "${_REESR:-}" ]; then
                case "$1" in */* | .*) ;; *) return 1 ;; esac
                if ! [ -e "$_REECWD/$1" ] && ! [ -L "$_REECWD/$1" ]; then
                    # As written it may name nothing (a missing directory
                    # or a file before ".."), while its normal form does.
                    _rea_norm "$_REECWD/$1"
                    [ -e "$_REEO" ] || [ -L "$_REEO" ] || return 1
                fi
            fi
            _REEA2="$_REECWD/$1"
            ;;
    esac
    _rea_hit_here && return 0
    [ "$_REEKIND" = server ] || return 1
    _REEP0=$_ABP
    _REEL0=$_ABL
    _ABP=$_REESP
    _ABL=$_REESL
    _rea_hit_here
    _REEX=$?
    _ABP=$_REEP0
    _ABL=$_REEL0
    return "$_REEX"
}
# _rea_cand_trim <candidate>: the candidate, then, since REA trims some
# values before use, its form without leading and trailing white space.
_rea_cand_trim() {
    _rea_cand_hit "$1" && return 0
    _REET=${1#"${1%%[![:space:]]*}"}
    _REET=${_REET%"${_REET##*[![:space:]]}"}
    [ "$_REET" != "$1" ] && _rea_cand_hit "$_REET"
}
# _rea_value_hit <value>: true when the whole value, or an entry of it
# between ":", names a path inside; nothing else is split or expanded, and
# a space is part of a path. Lists of directories are default-deny: a tool
# REA starts may search or load code from any of them (Qt's plugin
# directories, Lua's module paths), resolving a relative entry from its
# working directory. So PATH, every name ending in PATH or with PATH_
# (GST_PLUGIN_PATH_1_0), every *_DIRS name and GLib's module directories
# (GIO_EXTRA_MODULES, GIO_MODULE_DIR) get PATH's rule (_REESR): every
# entry is a path, bare words included, an empty one is ".", and each ":"
# entry, each ";" entry (Lua's lists) and each piece split at both is a
# candidate of its own. The Perl and Ruby library lists are
# refused above as code-loading; they are named here too so that leaving
# that list would still keep them strict. Only four names are relaxed
# (_REELS), each because nothing loads code from it: MANPATH (man pages),
# INFOPATH (info pages), NIX_PATH (Nix expressions, evaluated by nix, which
# REA never runs) and WINDOWPATH (X virtual-terminal numbers, not
# directories, exported by xinit and display managers). There an empty
# entry is a default marker (manpath(5)), not the working directory, and a
# name=path entry is checked by its path part.
# _rea_split_hit <value> <":" or ";">: true when an entry of the value
# between that separator names a path inside, by PATH's rule (_REESR set):
# an empty entry is ".".
_rea_split_hit() {
    _REESD="$1$2"
    while [ -n "$_REESD" ]; do
        case "$2" in
            :)
                _REEV=${_REESD%%:*}
                _REESD=${_REESD#*:}
                ;;
            *)
                _REEV=${_REESD%%;*}
                _REESD=${_REESD#*;}
                ;;
        esac
        [ -n "$_REEV" ] || _REEV=.
        _rea_cand_trim "$_REEV" && return 0
    done
    return 1
}
_rea_value_hit() {
    _REESR=""
    _rea_cand_trim "$1" && return 0
    _REELS=""
    case "$_REEN" in
        MANPATH | INFOPATH | NIX_PATH) _REELS=1 ;;
        # Only in its own shape, digits and ":", is WINDOWPATH relaxed.
        WINDOWPATH)
            case "$1" in
                *[!0-9:]*) _REESR=1 ;;
                *) _REELS=1 ;;
            esac
            ;;
        *PATH | *PATH_* | *_DIRS | PERL5LIB | PERLLIB | RUBYLIB | GIO_EXTRA_MODULES | GIO_MODULE_DIR) _REESR=1 ;;
    esac
    # Outside PATH an empty value sets no entries: unset, the default (the
    # XDG spec; VS Code's snap exports GTK_PATH_VSCODE_SNAP_ORIG= empty).
    if [ -z "$1" ] && [ "$_REEN" != PATH ]; then
        _REESR=""
        return 1
    fi
    _REEU="$1:"
    if [ -n "$_REESR" ]; then
        # Every splitting a tool might use adds candidates, none replaces
        # another: each ":" entry whole (a tool that splits only at ":" and
        # joins by text: in /proc/self/cwdx;/../cwd/bin the ".." pops
        # "cwdx;"), each ";" entry whole (Lua), then the pieces split at
        # both, below.
        if _rea_split_hit "$1" : || _rea_split_hit "$1" ';'; then
            _REESR=""
            return 0
        fi
        _REESC=$_REEU
        _REEU=""
        while :; do
            case "$_REESC" in
                *';'*)
                    _REEU="$_REEU${_REESC%%;*}:"
                    _REESC=${_REESC#*;}
                    ;;
                *)
                    _REEU="$_REEU$_REESC"
                    break
                    ;;
            esac
        done
    fi
    while [ -n "$_REEU" ]; do
        _REEV=${_REEU%%:*}
        _REEU=${_REEU#*:}
        [ -n "$_REEV" ] || [ -z "$_REESR" ] || _REEV=.
        if _rea_cand_trim "$_REEV"; then
            _REESR=""
            return 0
        fi
        if [ -n "$_REELS" ]; then
            _REEK=${_REEV%%=*}
            case "$_REEK" in
                "$_REEV" | */*) ;;
                *) _rea_cand_trim "${_REEV#*=}" && return 0 ;;
            esac
        fi
    done
    _REESR=""
    return 1
}
# The two refusal lines (FR-038), by variable name in _REEN.
_rea_refuse_code() {
    _atlas_shown "$_REEN"
    _REEZ=$_ABV
    printf '%s is set in %s, and it makes a runtime REA starts load code; unset it there, or set it empty in the env of REA'"'"'s MCP registration, then restart Codex.\n' "$_REEZ" "$_REEW"
}
_rea_refuse_path() {
    _atlas_shown "$_REEN"
    _REEZ=$_ABV
    _atlas_shown "$_REEH"
    printf '%s in %s names a path inside %s, which atlas treats as a repository, so it could supply what REA or a tool it starts runs; unset it or point it outside the repository there, then restart Codex.\n' "$_REEZ" "$_REEW" "$_ABV"
}
_rea_env_scan() {
    _REEBAD=0
    _REESR=""
    _REESEEN='
'
    _REEREF='
'
    while IFS= read -r _REEL; do
        case "$_REEL" in
            [A-Za-z_]*=*) ;;
            *)
                # This process's own environment comes from env's text, where a
                # value holding a line break could hide a variable.
                [ "$_REEKIND" != self ] || _REELB=1
                continue
                ;;
        esac
        _REEN=${_REEL%%=*}
        _REEG=${_REEL#*=}
        [ -n "$_REEN" ] || continue
        case "$_REESEEN" in
            *'
'"$_REEN"'
'*)
                _atlas_shown "$_REEN"
                _rea_say "$_REEW sets $_ABV more than once, so which value is read is unknown; nothing checked."
                return 1
                ;;
        esac
        _REESEEN="$_REESEEN$_REEN
"
        # Exempt by name: they name the working directory by convention and
        # no tool loads code from them. Nothing else is exempt.
        case "$_REEN" in PWD | OLDPWD | CLAUDE_PROJECT_DIR | _) continue ;; esac
        case "$_REEN" in
            BASH_ENV | ENV | SHELLOPTS | BASHOPTS | PS4 | BASH_FUNC_* | \
                JAVA_TOOL_OPTIONS | _JAVA_OPTIONS | JDK_JAVA_OPTIONS | JAVA_OPTS | CLASSPATH | \
                NODE_OPTIONS | NODE_PATH | \
                LD_PRELOAD | LD_AUDIT | LD_LIBRARY_PATH | GCONV_PATH | \
                DYLD_INSERT_LIBRARIES | DYLD_LIBRARY_PATH | DYLD_FRAMEWORK_PATH | DYLD_FALLBACK_LIBRARY_PATH | \
                PYTHONPATH | PYTHONSTARTUP | PYTHONHOME | PYTHONUSERBASE | \
                PERL5OPT | PERL5LIB | PERLLIB | RUBYOPT | RUBYLIB | \
                QT_PLUGIN_PATH | QT_QPA_PLATFORM_PLUGIN_PATH)
                if [ -n "$_REEG" ]; then
                    _rea_refuse_code
                    _REEBAD=1
                fi
                continue
                ;;
        esac
        # Paths, in every other variable: no name list exists for them.
        if _rea_value_hit "$_REEG"; then
            _rea_refuse_path
            _REEBAD=1
            _REEREF="$_REEREF$_REEN
"
        fi
    done <<EOF
$_REE
EOF
    # The Java a REA call can probe, by the executable itself: a JAVA_HOME,
    # or a PATH directory, outside the area can hold a bin/java that leads
    # into it. Named by the variable that selects it, unless that variable
    # was refused above.
    _rea_java_find || :
    if [ -n "$_REEJR" ]; then
        case "$_REEREF" in
            *'
'"$_REEJN"'
'*) ;;
            *)
                _REEN=$_REEJN
                if _rea_cand_hit "$_REEJR"; then
                    _rea_refuse_path
                    _REEBAD=1
                fi
                ;;
        esac
    fi
    # After the per-variable lines, so that a refusal is never lost to it.
    if [ -n "${_REELB:-}" ]; then
        _rea_say "a value in $_REEW holds a line break, so what REA reads can't be checked; nothing checked."
        _REEBAD=1
    fi
    [ "$_REEBAD" = 0 ]
}
# _rea_java_find: the Java REA will select in the environment last read by
# _rea_env_self or _rea_env_server. With JAVA_HOME set, $JAVA_HOME/bin/java
# (_REEJN=JAVA_HOME): _REEJR as written, _REEJ with "." and ".." removed,
# which is what REA runs. Else the first executable regular java on that
# PATH (/bin:/usr/bin when unset; an empty or relative entry resolves from
# the working directory), in both (_REEJN=PATH). Returns 2, both empty, for
# a set JAVA_HOME that isn't absolute, which REA's parser
# (JadxConfiguration.js) rejects, empty and white space included; 1 when
# PATH holds none.
_rea_java_find() {
    _REEJ=""
    _REEJR=""
    if _rea_env_get JAVA_HOME; then
        _REEJN=JAVA_HOME
        case "$_REEG" in
            /*) ;;
            *) return 2 ;;
        esac
        _REEJR="${_REEG%/}/bin/java"
        _rea_norm "$_REEJR"
        _REEJ=$_REEO
        return 0
    fi
    _REEJN=PATH
    _rea_env_get PATH || _REEG=/bin:/usr/bin
    _REEU="$_REEG:"
    while [ -n "$_REEU" ]; do
        _REEV=${_REEU%%:*}
        _REEU=${_REEU#*:}
        case "$_REEV" in
            /*) ;;
            '') _REEV=$_REECWD ;;
            *) _REEV="$_REECWD/$_REEV" ;;
        esac
        if [ -f "$_REEV/java" ] && [ -x "$_REEV/java" ]; then
            _REEJ="$_REEV/java"
            _REEJR=$_REEJ
            return 0
        fi
    done
    return 1
}
# _rea_java: that Java, where REA needs one. A set JAVA_HOME that isn't
# absolute prints the not-absolute [missing] java line. Otherwise the
# executable REA runs must exist and be an executable regular file, and
# both its forms must lie outside the area, resolved; else it prints the
# [missing] java line. Either line returns 1.
_rea_java() {
    _REESR=""
    _rea_java_find
    if [ "$?" = 2 ]; then
        printf '%s\n' '[missing] java: JAVA_HOME is set but isn'"'"'t an absolute path, which REA rejects. Set it to a JDK'"'"'s absolute path outside the repository, or unset it to use java on PATH (in the env of REA'"'"'s MCP registration, and in the environment Codex starts from), then restart Codex.'
        return 1
    fi
    case "$_REEJ" in
        /*) [ -f "$_REEJ" ] && [ -x "$_REEJ" ] && ! _rea_cand_hit "$_REEJR" && return 0 ;;
    esac
    printf '%s\n' '[missing] java: REA runs $JAVA_HOME/bin/java, or java on its PATH, and found none it can use. Install a JDK outside the repository and set JAVA_HOME to it (in the env of REA'"'"'s MCP registration, and in the environment Codex starts from), then restart Codex.'
    return 1
}
# ATLAS-REA-ENV-END

# _atlas_noglob / _atlas_glob: set -f for a word-splitting loop, then back to
# the caller's setting (a sourcing caller may run with set -f).
_atlas_noglob() {
    case "$-" in *f*) _ATLAS_HAD_F=1 ;; *) _ATLAS_HAD_F="" ;; esac
    set -f
}
_atlas_glob() {
    [ -n "$_ATLAS_HAD_F" ] || set +f
}

# _atlas_fix_path: the environment the runner keeps (R-023). It finds the
# untrusted area (the block above; on the system-directories line it
# returns 1 and nothing may be looked up). _ATLAS_ABS gets PATH's absolute
# entries; PATH is cut to those of them outside the area, by name and
# resolved (/usr/bin:/bin when none is left), and exported, so no lookup or
# tool run here (rea's "env node" included) takes a command from the
# repository. Builtins only until PATH is cut. _ATLAS_ORIG_PATH keeps the
# PATH it was given, for the Graphify runner, which cuts PATH itself and
# must see every absolute entry to refuse an in-repo graphify rather than
# skip it.
_atlas_fix_path() {
    local e r trusted="" oldifs="$IFS"
    _ATLAS_ORIG_PATH="$PATH"
    _atlas_area_init || return 1
    _ATLAS_ABS=""
    _atlas_noglob
    IFS=:
    for e in $PATH; do
        case "$e" in /*) ;; *) continue ;; esac
        _ATLAS_ABS="${_ATLAS_ABS:+$_ATLAS_ABS:}$e"
        r="$(cd -P "$e" 2>/dev/null && pwd -P)" || r="$e"
        _inside "$e" || _inside "$r" || trusted="${trusted:+$trusted:}$e"
    done
    IFS="$oldifs"
    _atlas_glob
    PATH="${trusted:-/usr/bin:/bin}"
    export PATH
}

# _atlas_locate <id> <command>: the command on PATH's absolute entries, in
# _AF. Returns 0 when found outside the untrusted area, 1 when not found, 2
# when the first hit lies inside it (by name, resolved directory or any
# symlink step: _inside_path): then it prints [missing] <id> and FR-031's
# untrusted-area line, as the runner does for graphify, rather than a
# misleading install line. A hit on a relative entry is never seen (those
# entries are dropped, as in the runner).
_atlas_locate() {
    local e oldifs="$IFS"
    _AF=""
    _atlas_noglob
    IFS=:
    for e in $_ATLAS_ABS; do
        if [ -f "$e/$2" ] && [ -x "$e/$2" ]; then
            _AF="$e/$2"
            break
        fi
    done
    IFS="$oldifs"
    _atlas_glob
    [ -n "$_AF" ] || return 1
    if _inside_path "$_AF"; then
        printf '[missing] %s\n' "$1"
        _untrusted_line "$(_atlas_printable "$_AF")"
        return 2
    fi
    return 0
}

# _atlas_printable <text>: the text without control characters, so tool
# output and paths cannot drive the terminal.
_atlas_printable() {
    printf '%s' "${1//[[:cntrl:]]/}"
}

# _atlas_version <executable>: the first line of "<executable> --version",
# cut after its last space (rea 6.4.0) and without a leading "v" (v22.19.0),
# in _AV: the version alone when it starts like one, else the text without
# characters outside [A-Za-z0-9.+_-]; empty when the output is.
_atlas_version() {
    local out re='^[0-9]+(\.[0-9]+)*(-[0-9A-Za-z.]+)?(\+[0-9A-Za-z.]+)?'
    out="$("$1" --version </dev/null 2>/dev/null)"
    out="${out%%$'\n'*}"
    out="${out##* }"
    out="${out#v}"
    if [[ "$out" =~ $re ]]; then
        _AV="${BASH_REMATCH[0]}"
    else
        _AV="${out//[^A-Za-z0-9.+_-]/}"
    fi
}

# _atlas_cmp <version> <version>: the numeric MAJOR.MINOR.PATCH order
# (missing parts are 0; a pre-release or build suffix is ignored here) in
# _AC: -1, 0 or 1. Returns 1 when either does not start with a number.
_atlas_cmp() {
    local re='^([0-9]+)(\.([0-9]+))?(\.([0-9]+))?' a1 a2 a3 b1 b2 b3
    [[ "$1" =~ $re ]] || return 1
    a1=$((10#${BASH_REMATCH[1]})) a2=$((10#${BASH_REMATCH[3]:-0})) a3=$((10#${BASH_REMATCH[5]:-0}))
    [[ "$2" =~ $re ]] || return 1
    b1=$((10#${BASH_REMATCH[1]})) b2=$((10#${BASH_REMATCH[3]:-0})) b3=$((10#${BASH_REMATCH[5]:-0}))
    if ((a1 != b1)); then
        ((a1 < b1)) && _AC=-1 || _AC=1
    elif ((a2 != b2)); then
        ((a2 < b2)) && _AC=-1 || _AC=1
    elif ((a3 != b3)); then
        ((a3 < b3)) && _AC=-1 || _AC=1
    else
        _AC=0
    fi
    return 0
}

# _atlas_in_range <version>: true when it satisfies ATLAS_NODE_REA_RANGE,
# alternatives joined by "||", each "^X.Y.Z" (same major, not lower),
# ">=X.Y.Z" or an exact "X.Y.Z".
_atlas_in_range() {
    local rest="$ATLAS_NODE_REA_RANGE" part
    while [ -n "$rest" ]; do
        part="${rest%%||*}"
        if [ "$part" = "$rest" ]; then rest=""; else rest="${rest#*||}"; fi
        part="${part// /}"
        case "$part" in
            ^*)
                part="${part#^}"
                _atlas_cmp "$1" "$part" && [ "$_AC" -ge 0 ] \
                    && _atlas_cmp "$1" "$((10#${part%%.*} + 1))" && [ "$_AC" -lt 0 ] && return 0
                ;;
            '>='*) _atlas_cmp "$1" "${part#>=}" && [ "$_AC" -ge 0 ] && return 0 ;;
            *) _atlas_cmp "$1" "$part" && [ "$_AC" -eq 0 ] && return 0 ;;
        esac
    done
    return 1
}

# Each _atlas_check_<id> prints its line (and fix line) and returns 1 on
# [missing], else 0.
_atlas_check_graphify() {
    local runner="${ATLAS_CONFIG_DIR}/skills/graphify/atlas-graphify.sh" out
    if [ ! -f "$runner" ]; then
        printf '[missing] graphify\n%s\n' "atlas-check.sh: the Graphify runner skills/graphify/atlas-graphify.sh is missing from the config directory; reinstall the atlas pack."
        return 1
    fi
    # The PATH as given: the runner refuses a graphify on an in-repo entry,
    # which the cut PATH would hide from it.
    if out="$(PATH="${_ATLAS_ORIG_PATH-$PATH}" GRAPHIFY_NO_AUTO_REFRESH=1 /bin/sh "$runner" --resolve </dev/null)" \
        && [ -n "$out" ]; then
        printf '[ok] graphify\n'
        return 0
    fi
    printf '[missing] graphify\n%s\n' "${out:-atlas-check.sh: the Graphify runner stopped without a line; reinstall the atlas pack.}"
    return 1
}

# _atlas_check_uv [quiet]: quiet prints nothing when uv is there (hint_for).
_atlas_check_uv() {
    local st=0
    _atlas_locate uv uv || st=$?
    [ "$st" -eq 2 ] && return 1
    if [ "$st" -eq 0 ] && "$_AF" --version </dev/null >/dev/null 2>&1; then
        [ -n "${1:-}" ] || printf '[ok] uv\n'
        return 0
    fi
    printf '[missing] uv\n'
    atlas_fix_line uv missing
    return 1
}

# FR-038's environment rule on this process's own environment, the one a
# rea it starts receives (the ATLAS-REA-ENV block above), run at most once:
# the result is kept in _ATLAS_REAENV_RC (0 passed, 1 refused) and the
# refusal lines in _ATLAS_REAENV_OUT. _atlas_rea_env_show prints them once
# under a label. No rea call runs while it is refused.
_ATLAS_REAENV_RC=""
_ATLAS_REAENV_OUT=""
_ATLAS_REAENV_SHOWN=""
_ATLAS_REAENV_BAD=""
_atlas_rea_env_own() {
    if [ -z "$_ATLAS_REAENV_RC" ]; then
        _ATLAS_REAENV_RC=0
        _ATLAS_REAENV_OUT="$(_REETAG=atlas-check; _rea_env_self && _rea_env_scan)" || _ATLAS_REAENV_RC=1
    fi
    [ "$_ATLAS_REAENV_RC" = 0 ]
}
_atlas_rea_env_show() {
    [ -z "$_ATLAS_REAENV_SHOWN" ] || return 0
    _ATLAS_REAENV_SHOWN=1
    printf '%s\n%s\n' "$1" "$_ATLAS_REAENV_OUT"
}

_atlas_check_rea() {
    local st=0
    _atlas_locate rea rea || st=$?
    [ "$st" -eq 2 ] && return 1
    if [ "$st" -ne 0 ]; then
        printf '[missing] rea\n'
        atlas_fix_line rea missing
        return 1
    fi
    # rea --version below starts rea, which passes its environment on: the
    # doctor (ATLAS_REA_ENV_WARN) shows a refusal as a warning instead.
    if ! _atlas_rea_env_own; then
        if [ -n "${ATLAS_REA_ENV_WARN:-}" ]; then
            _atlas_rea_env_show '[warn] rea-env'
            return 0
        fi
        _atlas_rea_env_show '[missing] rea'
        return 1
    fi
    _atlas_version "$_AF"
    if [ "$_AV" = "$ATLAS_REA_PIN" ]; then
        printf '[ok] rea\n'
        return 0
    fi
    if [ -z "$_AV" ] || ! _atlas_cmp "$_AV" "$ATLAS_REA_PIN"; then
        printf '[missing] rea\n'
        atlas_fix_line rea found "${_AV:-an unreadable version}"
        return 1
    fi
    if [ "$_AC" -gt 0 ]; then
        printf '[warn] rea\n'
        atlas_fix_line rea newer "$_AV"
        return 0
    fi
    # Lower, or the pin's own core with a pre-release or build suffix.
    printf '[missing] rea\n'
    atlas_fix_line rea older "$_AV"
    return 1
}

_atlas_check_node_archify() {
    local st=0
    _atlas_locate node-archify node || st=$?
    [ "$st" -eq 2 ] && return 1
    if [ "$st" -ne 0 ]; then
        printf '[missing] node-archify\n'
        atlas_fix_line node-archify missing
        return 1
    fi
    _atlas_version "$_AF"
    if _atlas_cmp "$_AV" "$ATLAS_NODE_ARCHIFY_FLOOR" && [ "$_AC" -ge 0 ]; then
        printf '[ok] node-archify\n'
        return 0
    fi
    printf '[missing] node-archify\n'
    atlas_fix_line node-archify found "${_AV:-an unreadable version}"
    return 1
}

_atlas_check_node_rea() {
    local st=0
    _atlas_locate node-rea node || st=$?
    [ "$st" -eq 2 ] && return 1
    if [ "$st" -ne 0 ]; then
        printf '[missing] node-rea\n'
        atlas_fix_line node-rea missing
        return 1
    fi
    _atlas_version "$_AF"
    if _atlas_in_range "$_AV"; then
        printf '[ok] node-rea\n'
        return 0
    fi
    printf '[missing] node-rea\n'
    atlas_fix_line node-rea found "${_AV:-an unreadable version}"
    return 1
}

# atlas_rea_client <client>: REA's client id for a client name (FR-028,
# FR-038). rea doctor --client takes REA's own names, not the kit's. The
# doctor and the REA Commands share this copy.
atlas_rea_client() {
    case "$1" in
        claude) printf '%s\n' claude_code ;;
        codex) printf '%s\n' codex ;;
        *) return 1 ;;
    esac
}

ATLAS_REA_DOCTOR_LINES=200

# _atlas_rea_setup: FR-038's setup half. REA's MCP registration and skill
# for this client, by REA's client id; with the id, REA checks the client's
# own skill copy, not the shared ~/.agents/skills one this client doesn't
# load. Prints a line for each and the rea setup fix line after each
# [missing]. _ATLAS_REA_BIN is the rea found outside the untrusted area, or
# empty (nothing ran then). Returns 1 when either is missing. It runs
# rea doctor only, never rea setup.
_atlas_rea_setup() {
    local st=0 client bad=0 srv
    _ATLAS_REA_BIN=""
    client="$(atlas_rea_client "${ATLAS_CLIENT:-codex}")" || return 1
    _atlas_locate rea rea >/dev/null || st=$?
    if [ "$st" -ne 0 ]; then
        printf '[missing] rea-mcp\n%s\n' "$(atlas_fix_line mcp missing)"
        printf '[missing] rea-skill\n%s\n' "$(atlas_fix_line mcp missing)"
        return 1
    fi
    # FR-038: no rea call runs until the environments pass the rule: this
    # process's own, and (ATLAS_REA_SERVER_SCAN, set for rea-setup) REA's
    # MCP server's. The doctor (ATLAS_REA_ENV_WARN) shows a refusal as a
    # warning and still reports the rest.
    _ATLAS_REAENV_BAD=""
    if ! _atlas_rea_env_own; then
        _ATLAS_REAENV_BAD=1
        if [ -n "${ATLAS_REA_ENV_WARN:-}" ]; then
            _atlas_rea_env_show '[warn] rea-env'
            return 0
        fi
        _atlas_rea_env_show '[missing] rea-env'
        return 1
    fi
    if [ -n "${ATLAS_REA_SERVER_SCAN:-}" ]; then
        if ! srv="$(_REETAG=atlas-check; _rea_env_server && _rea_env_scan)"; then
            _ATLAS_REAENV_BAD=1
            printf '[missing] rea-env\n%s\n' "$srv"
            return 1
        fi
    fi
    _ATLAS_REA_BIN="$_AF"
    if "$_ATLAS_REA_BIN" doctor --client "$client" </dev/null >/dev/null 2>&1; then
        printf '[ok] rea-mcp\n'
    else
        printf '[missing] rea-mcp\n%s\n' "$(atlas_fix_line mcp missing)"
        bad=1
    fi
    if "$_ATLAS_REA_BIN" doctor --skill --client "$client" </dev/null >/dev/null 2>&1; then
        printf '[ok] rea-skill\n'
    else
        printf '[missing] rea-skill\n%s\n' "$(atlas_fix_line mcp missing)"
        bad=1
    fi
    return "$bad"
}

# _atlas_rea_report: _atlas_rea_setup, then a plain rea doctor on the
# configured providers (FR-028, FR-039): "[ok] rea-doctor", or "[warn]
# rea-doctor" with rea's own output indented below, at most
# ATLAS_REA_DOCTOR_LINES lines. A provider that is not ready is a warning,
# not a failure. Returns 1 when the setup half did.
_atlas_rea_report() {
    local status=0 out rc=0 n=0 l
    _ATLAS_REAENV_BAD=""
    _atlas_rea_setup || status=1
    # A refusal of the environment rule was already shown, and nothing ran.
    [ -z "$_ATLAS_REAENV_BAD" ] || return "$status"
    if [ -z "$_ATLAS_REA_BIN" ]; then
        printf '[warn] rea-doctor\n%s\n' "rea doctor did not run: no usable rea (see the rea line above)."
        return 1
    fi
    out="$("$_ATLAS_REA_BIN" doctor --filter-output healthy,scope_checks </dev/null 2>&1)" || rc=$?
    if [ "$rc" -eq 0 ]; then
        printf '[ok] rea-doctor\n'
        return "$status"
    fi
    printf '[warn] rea-doctor\n%s\n' "rea doctor reports checks that are not ready; its output follows."
    while IFS= read -r l; do
        n=$((n + 1))
        if [ "$n" -gt "$ATLAS_REA_DOCTOR_LINES" ]; then
            printf '    (more lines cut; run rea doctor to see them all)\n'
            break
        fi
        printf '    %s\n' "$(_atlas_printable "$l")"
    done <<EOF
$out
EOF
    return "$status"
}

# The browser as Archify's findChrome looks for it: ARCHIFY_CHROME alone when
# set; else on macOS only the two app bundles, elsewhere only the PATH
# candidates (an in-repo one is refused).
_atlas_check_browser() {
    local c st
    if [ "${ARCHIFY_CHROME+set}" = set ]; then
        if [ -n "$ARCHIFY_CHROME" ] && [ -f "$ARCHIFY_CHROME" ] && [ -x "$ARCHIFY_CHROME" ]; then
            printf '[ok] browser\n'
            return 0
        fi
    else
        case "${OSTYPE:-}" in
            darwin*)
                for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
                    "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
                    if [ -f "$c" ] && [ -x "$c" ]; then
                        printf '[ok] browser\n'
                        return 0
                    fi
                done
                ;;
            *)
                for c in google-chrome google-chrome-stable chromium chromium-browser; do
                    st=0
                    _atlas_locate browser "$c" || st=$?
                    [ "$st" -eq 2 ] && return 1
                    if [ "$st" -eq 0 ]; then
                        printf '[ok] browser\n'
                        return 0
                    fi
                done
                ;;
        esac
    fi
    printf '[missing] browser\n'
    atlas_fix_line browser missing
    return 1
}

# _atlas_find_git: git on the cut PATH, in _ATLAS_GIT. Returns 0 when found
# outside the untrusted area, 1 when not found, 2 after the refusal lines
# when the first git lies inside it.
_atlas_find_git() {
    local st=0
    _ATLAS_GIT=""
    _atlas_locate git git || st=$?
    [ "$st" -eq 0 ] && _ATLAS_GIT="$_AF"
    return "$st"
}

# _atlas_git <dir> <git args>: the located git, run in <dir>. No optional
# locks (git status would otherwise refresh the index) and no fsmonitor
# hook: the checks only read the repository.
_atlas_git() {
    local d="$1"
    shift
    if [ -n "${ATLAS_START_DIR:-}" ]; then
        # A target other than the started-in repository: no repository hook
        # path either (a config read there is not the operator's).
        # No lazy fetch and no transport either: a promisor remote's
        # core.sshCommand would be a command from the target.
        GIT_OPTIONAL_LOCKS=0 GIT_NO_LAZY_FETCH=1 GIT_ALLOW_PROTOCOL= "$_ATLAS_GIT" --no-replace-objects \
            -C "$d" -c core.fsmonitor=false -c core.hooksPath=/dev/null "$@"
    else
        GIT_OPTIONAL_LOCKS=0 "$_ATLAS_GIT" -C "$d" -c core.fsmonitor=false "$@"
    fi
}

# _atlas_target_gate <dir>: with ATLAS_START_DIR set, refuses (after a
# line, returning 1) a <dir> with a .git entry of its own, or below one
# before the walk up reaches the started-in repository's root: git would
# read that .git, and its config, and they would be the target's, not the
# operator's. The started-in root (the nearest .git at or above the start)
# itself is the operator's choice. The walk
# stops at $HOME and its ancestors, which never count as a repository. Needs
# _atlas_area_init to have run (for $HOME's names).
_atlas_target_gate() {
    local d root=""
    [ -n "${ATLAS_START_DIR:-}" ] || return 0
    # The started-in repository: the nearest .git at or above the start
    # directory (not the outermost one the PATH cut uses), $HOME and its
    # ancestors never counting.
    if root="$(cd -P -- "$ATLAS_START_DIR" 2>/dev/null && pwd -P)"; then
        while [ "$root" != / ]; do
            case "$_ABH" in "$root" | "$root"/*) root=""; break ;; esac
            case "$_ABHR" in "$root" | "$root"/*) root=""; break ;; esac
            if [ -e "$root/.git" ] || [ -L "$root/.git" ]; then break; fi
            root="${root%/*}"
            [ -n "$root" ] || root=/
        done
        [ "$root" != / ] || root=""
    else
        root=""
    fi
    if ! d="$(cd -P "$1" 2>/dev/null && pwd -P)" || [ -z "$d" ]; then
        printf 'atlas-check.sh: cannot resolve %s.\n' "$(_atlas_printable "$1")"
        return 1
    fi
    while [ "$d" != / ]; do
        [ -n "$root" ] && [ "$d" = "$root" ] && return 0
        case "$_ABH" in "$d" | "$d"/*) return 0 ;; esac
        case "$_ABHR" in "$d" | "$d"/*) return 0 ;; esac
        if [ -e "$d/.git" ] || [ -L "$d/.git" ]; then
            printf '%s has a .git entry between the target and the repository you started in, so git would read its configuration (filters, say) from the target; atlas runs no git there. Map a copy of the files without that .git.\n' "$(_atlas_printable "$d")"
            return 1
        fi
        d="${d%/*}"
        [ -n "$d" ] || d=/
    done
    return 0
}

# _atlas_filtered <dir>: true when a path under <dir> (tracked, or untracked
# and not ignored) carries a filter attribute, when a filter is configured
# under the names check-attr cannot tell from "none", or when git cannot
# say (fails closed). check-attr reads attributes and runs nothing.
_atlas_filtered() {
    local hit rc=0
    if _atlas_git "$1" config --name-only --get-regexp '^filter\.(unset|unspecified)\.' >/dev/null 2>&1; then
        return 0
    fi
    # A submodule (a gitlink) would run git again under its own config.
    # The whole listing is read before it is tested, so a long one cannot end
    # a pipe early (SIGPIPE) and hide a gitlink; a failing ls-files counts as
    # filtered (fails closed).
    hit="$(_atlas_git "$1" ls-files -s -- .)" || return 0
    case "$hit" in
        "160000 "* | *$'\n'"160000 "*) return 0 ;;
    esac
    hit="$(
        set -o pipefail
        _atlas_git "$1" ls-files -z --cached --others --exclude-standard -- . \
            | _atlas_git "$1" check-attr -z filter --stdin \
            | {
                while IFS= read -r -d '' _p && IFS= read -r -d '' _a && IFS= read -r -d '' _v; do
                    case "$_v" in
                        unspecified | unset) ;;
                        *) printf x; break ;;
                    esac
                done
            }
    )" || rc=1
    [ "$rc" -ne 0 ] || [ -n "$hit" ]
}

# _atlas_in_work_tree <dir>: true when <dir> lies inside a git work tree.
_atlas_in_work_tree() {
    [ "$(_atlas_git "$1" rev-parse --is-inside-work-tree 2>/dev/null)" = true ]
}

# _atlas_ignored <dir> <name>: 0 when <dir>/<name>/ is ignored, 1 when it
# is not, 2 (after a line) when git cannot tell.
_atlas_ignored() {
    local st=0
    _atlas_git "$1" check-ignore -q -- "$2/" 2>/dev/null || st=$?
    case "$st" in
        0 | 1) return "$st" ;;
    esac
    printf 'atlas-check.sh: git check-ignore failed in %s.\n' "$(_atlas_printable "$1")"
    return 2
}

# _atlas_append_row <file> <row>: the row appended on a line of its own;
# the file is created when missing. A symlink or a non-regular file is
# refused, so the row can only land in the file git reads.
_atlas_append_row() {
    local f="$1" shown content="" sep=""
    shown="$(_atlas_printable "$f")"
    if [ -L "$f" ]; then
        printf '%s is a symlink; atlas writes no ignore row through it. Add the row %s by hand, or choose another option.\n' "$shown" "$2"
        return 1
    fi
    if [ -e "$f" ]; then
        if [ ! -f "$f" ]; then
            printf '%s is not a regular file; atlas writes no ignore row to it.\n' "$shown"
            return 1
        fi
        IFS= read -r -d '' content <"$f"
        case "$content" in
            "" | *$'\n') ;;
            *) sep=$'\n' ;;
        esac
    fi
    if ! printf '%s%s\n' "$sep" "$2" >>"$f"; then
        printf 'atlas-check.sh: cannot write %s.\n' "$shown"
        return 1
    fi
}

# _atlas_scratch <name> <path> <apply>: FR-030's scratch-ignore check for
# <path>/<name>/ (AC-093). It writes only on --apply gitignore or exclude,
# and only the one file that choice names.
_atlas_scratch() {
    local name="$1" path="$2" apply="$3" st=0 file parent
    _atlas_find_git || st=$?
    [ "$st" -eq 2 ] && return 1
    if [ ! -d "$path" ]; then
        printf 'atlas-check.sh: %s is not a directory.\n' "$(_atlas_printable "$path")"
        return 1
    fi
    _atlas_unreadable_repo "$path" && return 1
    if [ -z "$_ATLAS_GIT" ] || ! _atlas_in_work_tree "$path"; then
        printf '[n/a] %s/: not inside a git work tree\n' "$name"
        return 0
    fi
    st=0
    _atlas_ignored "$path" "$name" || st=$?
    case "$st" in
        0) printf '[ignored] %s/\n' "$name"; return 0 ;;
        2) return 1 ;;
    esac
    case "$apply" in
        "")
            printf '[not-ignored] %s/\n' "$name"
            return 0
            ;;
        none)
            printf '[warn] %s/ is not ignored, so its output can be committed by accident.\n' "$name"
            return 0
            ;;
        gitignore)
            if ! file="$(_atlas_git "$path" rev-parse --show-toplevel 2>/dev/null)" || [ -z "$file" ]; then
                printf 'atlas-check.sh: git cannot name the work tree of %s.\n' "$(_atlas_printable "$path")"
                return 1
            fi
            file="${file}/.gitignore"
            ;;
        exclude)
            # The repository's local exclude file, as git names it, so a
            # linked worktree gets the shared one.
            if ! file="$(_atlas_git "$path" rev-parse --git-path info/exclude 2>/dev/null)" || [ -z "$file" ]; then
                printf 'atlas-check.sh: git cannot name the exclude file of %s.\n' "$(_atlas_printable "$path")"
                return 1
            fi
            case "$file" in /*) ;; *) file="${path%/}/${file}" ;; esac
            parent="${file%/*}"
            if [ ! -d "$parent" ] && ! mkdir -- "$parent"; then
                printf 'atlas-check.sh: cannot create %s.\n' "$(_atlas_printable "$parent")"
                return 1
            fi
            if ! parent="$(cd -P "$parent" && pwd -P)" || [ -z "$parent" ]; then
                printf 'atlas-check.sh: cannot resolve the directory of %s.\n' "$(_atlas_printable "$file")"
                return 1
            fi
            file="${parent}/${file##*/}"
            ;;
    esac
    _atlas_append_row "$file" "${name}/" || return 1
    printf '[added] %s/ to %s\n' "$name" "$(_atlas_printable "$file")"
    st=0
    _atlas_ignored "$path" "$name" || st=$?
    case "$st" in
        0) return 0 ;;
        1) printf '[warn] %s/ is still not ignored: a later rule un-ignores it.\n' "$name" ;;
    esac
    return 1
}

ATLAS_USAGE_CHECK="usage: atlas-check.sh codex check <prerequisite>... (prerequisites: ${ATLAS_IDS})"
ATLAS_USAGE_SCRATCH="usage: atlas-check.sh codex scratch <graphify-out|.archify> <path> [--apply gitignore|exclude|none]"
ATLAS_USAGE_PROVENANCE="usage: atlas-check.sh codex provenance begin <path> | finish <path> <full|update> [semantic-declined] | state <path>"
ATLAS_USAGE_REA="usage: atlas-check.sh codex rea-setup | rea-doctor"


# --- Provenance (FR-032, FR-033; AC-096, AC-064) ---------------------------
#
# The record, graphify-out/atlas-provenance.json, binds a graph.json to how
# it was built; begin captures the start of a build into
# graphify-out/.atlas-provenance-pending, finish turns that capture into
# the record after Graphify succeeds, and state reports the graph's
# provenance state. graphify-out/ may come from the repository (a committed
# one), so a symlinked graphify-out/, graph.json or record is refused and
# the record is parsed line by line in the exact form finish writes.

ATLAS_PENDING=".atlas-provenance-pending"
ATLAS_RECORD="atlas-provenance.json"

# Graphify 0.9.85's CODE_EXTENSIONS (graphify/detect.py:47), lower-cased as
# its classify_file compares them (path.suffix.lower()); a re-pin updates
# this copy. Any other extension, and none, counts as non-code, so a file
# Graphify would read as code by another rule (a package manifest, a
# shebang script) can only make the state semantic-stale, never current.
ATLAS_CODE_EXTENSIONS=".py .ts .tsx .mts .cts .js .jsx .mjs .cjs .ejs .ets .go .rs .vb .cbl .cob .cobol .cpy .java .groovy .gradle .cpp .cc .cxx .c .h .hpp .cu .cuh .metal .rb .rake .swift .kt .kts .cs .scala .php .lua .luau .toc .zig .ps1 .psm1 .psd1 .ex .exs .m .mm .ml .mli .jl .vue .svelte .astro .dart .v .sv .svh .vh .sql .r .f .f90 .f95 .f03 .f08 .pas .pp .dpr .dpk .lpr .inc .dfm .lfm .lpk .sh .bash .json .tf .tfvars .hcl .dm .dme .dmi .dmm .dmf .sln .slnx .csproj .fsproj .vbproj .xaml .razor .cshtml .cls .trigger .lisp .cl .lsp .asd .robot .resource .sol .erl .hrl .escript"

# _atlas_is_code <file>: true when its extension is in the copy above.
_atlas_is_code() {
    local base="${1##*/}" core ext had="" st=1
    core="${base#.}"
    case "$core" in
        *.*) ext=".${core##*.}" ;;
        *) return 1 ;;
    esac
    [ "$ext" = . ] && return 1
    shopt -q nocasematch && had=1
    shopt -s nocasematch
    [[ " $ATLAS_CODE_EXTENSIONS " == *" $ext "* ]] && st=0
    [ -n "$had" ] || shopt -u nocasematch
    return "$st"
}

# _atlas_out_dir <path>: <path>/graphify-out in _AO. Returns 1, after a
# line, when it is a symlink or not a directory.
_atlas_out_dir() {
    _AO="${1%/}/graphify-out"
    if [ -L "$_AO" ]; then
        printf '%s is a symlink; remove it, then run $map-repo again.\n' "$(_atlas_printable "$_AO")"
        return 1
    fi
    if [ -e "$_AO" ] && [ ! -d "$_AO" ]; then
        printf '%s is not a directory; remove it, then run $map-repo again.\n' "$(_atlas_printable "$_AO")"
        return 1
    fi
}

# _atlas_regular <file>: true for a regular file that is not a symlink.
_atlas_regular() {
    [ -f "$1" ] && [ ! -L "$1" ]
}

# _atlas_rows_only <old> <new>: true when <new> is <old> with nothing but
# scratch rows (graphify-out/, .archify/) and blank lines after it, which
# is all scratch --apply gitignore ever adds.
_atlas_rows_only() {
    local rest line
    case "$2" in "$1"*) ;; *) return 1 ;; esac
    rest="${2#"$1"}"
    # The rows start a line of their own: an edit to the old last line is
    # not an appended row.
    if [ -n "$1" ] && [ -n "$rest" ]; then
        case "$rest" in $'\n'*) ;; *) return 1 ;; esac
    fi
    while IFS= read -r line; do
        case "$line" in
            "" | graphify-out/ | .archify/) ;;
            *) return 1 ;;
        esac
    done <<EOF
$rest
EOF
}

# _atlas_blob <dir> <rev>: the top-level .gitignore at <rev>, in _AGI_TXT
# ("" when that revision has none).
_atlas_blob() {
    _AGI_TXT=""
    _atlas_git "$1" cat-file -e "$2:.gitignore" 2>/dev/null || return 0
    _AGI_TXT="$(_atlas_git "$1" cat-file blob "$2:.gitignore" 2>/dev/null)"
}

# _atlas_scratch_rows_only <dir> <status line>: true when the line is the
# work tree's top-level .gitignore and it differs from HEAD only by scratch
# rows, so the answer to FR-030's question doesn't make the build dirty.
_atlas_scratch_rows_only() {
    local top new
    case "$2" in ??" .gitignore") ;; *) return 1 ;; esac
    top="$(_atlas_git "$1" rev-parse --show-toplevel 2>/dev/null)" || return 1
    _atlas_regular "$top/.gitignore" || return 1
    new="$(<"$top/.gitignore")"
    _atlas_blob "$1" HEAD
    _atlas_rows_only "$_AGI_TXT" "$new"
}

# _atlas_capture <path>: the state of the work tree under <path> now. _AH
# is HEAD ("" outside git or before the first commit); _AD is 1 when the
# work tree under <path> differs from HEAD (a modified tracked file, or an
# untracked file that isn't ignored, submodules included whatever
# .gitmodules says; graphify-out/ and .archify/ never count, ignored or
# not, nor scratch rows added to the top-level .gitignore), else 0.
# Returns 1 after a line when git fails.
_atlas_capture() {
    local st line
    _AH=""
    _AD=0
    [ -n "$_ATLAS_GIT" ] && _atlas_in_work_tree "$1" || return 0
    if [ -n "${ATLAS_START_DIR:-}" ] && _atlas_filtered "$1"; then
        # A filter would run a command from the repository: no status, no
        # commit to pin, and the build counts as dirty.
        _AD=1
        return 0
    fi
    _AH="$(_atlas_git "$1" rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null)" || _AH=""
    if ! st="$(_atlas_git "$1" status --porcelain --untracked-files=all --ignore-submodules=none -- . \
        ':(exclude,glob)**/graphify-out/**' ':(exclude,glob)**/.archify/**' 2>/dev/null)"; then
        printf 'atlas-check.sh: git status failed in %s.\n' "$(_atlas_printable "$1")"
        return 1
    fi
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        _atlas_scratch_rows_only "$1" "$line" && continue
        _AD=1
        break
    done <<EOF
$st
EOF
    return 0
}

# _atlas_sha256 <file>: its SHA-256 in _ASHA (sha256sum, else shasum -a
# 256, read from stdin so no file name is echoed). Returns 1 after a line.
_atlas_sha256() {
    local out
    if command -v sha256sum >/dev/null 2>&1; then
        out="$(sha256sum <"$1")" || out=""
    elif command -v shasum >/dev/null 2>&1; then
        out="$(shasum -a 256 <"$1")" || out=""
    else
        printf 'atlas-check.sh: neither sha256sum nor shasum found; install coreutils, then re-run.\n'
        return 1
    fi
    _ASHA="${out%% *}"
    if [[ ! "$_ASHA" =~ ^[0-9a-f]{64}$ ]]; then
        printf 'atlas-check.sh: cannot hash %s.\n' "$(_atlas_printable "$1")"
        return 1
    fi
}

# _atlas_graph_commit <graph.json>: the built_at_commit Graphify 0.9.85
# stamped, in _AGC ("" when absent, as outside git). export.py's to_json
# writes it as a top-level key with indent=2, so the pattern takes only a
# line at two spaces' indent (the last one, as a JSON reader would).
_atlas_graph_commit() {
    local line hits re='^  "built_at_commit": "([0-9a-f]{40}|[0-9a-f]{64})",?$'
    _AGC=""
    hits="$(grep -E '^  "built_at_commit": ' <"$1")" || hits=""
    while IFS= read -r line; do
        [[ "$line" =~ $re ]] && _AGC="${BASH_REMATCH[1]}"
    done <<EOF
$hits
EOF
}

# _atlas_read_record <out-dir>: the record's fields in _RSHA, _RBUILT (the
# graph's built_at_commit), _RCOMMIT (the commit the record vouches for),
# _RDIRTY, _RMODE, _RVER, _RSEM and _RCLEAN. Format 2 carries commit; a
# format-1 record has none and vouches for its built_at_commit. Returns 0
# when it parses, 1 when there is none, 2 when it exists but isn't a record
# finish wrote (in either format).
_atlas_read_record() {
    local f="$1/$ATLAS_RECORD" line n=0 key val seen=" " ver="" last=0
    local re='^  "([a-z_0-9]+)": (.*[^,]),?$'
    _RSHA="" _RBUILT="" _RCOMMIT="" _RDIRTY="" _RMODE="" _RVER="" _RSEM="" _RCLEAN=""
    [ -e "$f" ] || [ -L "$f" ] || return 1
    _atlas_regular "$f" || return 2
    while IFS= read -r line || [ -n "$line" ]; do
        n=$((n + 1))
        [ "$n" -le 11 ] || return 2
        # The exact shape finish writes: "{" first, "}" last, one key a line.
        case "$n:$line" in
            "1:{") continue ;;
            1:* | *:"{") return 2 ;;
            *:"}") last="$n"; continue ;;
        esac
        [ "$last" -eq 0 ] || return 2
        [[ "$line" =~ $re ]] || return 2
        key="${BASH_REMATCH[1]}"
        val="${BASH_REMATCH[2]}"
        case "$seen" in *" $key "*) return 2 ;; esac
        seen="${seen}${key} "
        case "$key:$val" in
            atlas_provenance:1 | atlas_provenance:2) ver="$val" ;;
            graph_sha256:\"*\") _RSHA="${val//\"/}" ;;
            built_at_commit:null) _RBUILT="" ;;
            built_at_commit:\"*\") _RBUILT="${val//\"/}" ;;
            commit:null) _RCOMMIT="" ;;
            commit:\"*\") _RCOMMIT="${val//\"/}" ;;
            dirty_build:true | dirty_build:false) _RDIRTY="$val" ;;
            mode:\"full\" | mode:\"update\") _RMODE="${val//\"/}" ;;
            graphify_version:\"*\") _RVER="${val//\"/}" ;;
            semantic_commit:null) _RSEM="" ;;
            semantic_commit:\"*\") _RSEM="${val//\"/}" ;;
            clean_full_pass:true | clean_full_pass:false) _RCLEAN="$val" ;;
            *) return 2 ;;
        esac
    done <"$f"
    case "$ver:$n:$last:$seen" in
        "1:10:10: atlas_provenance graph_sha256 built_at_commit dirty_build mode graphify_version semantic_commit clean_full_pass ")
            _RCOMMIT="$_RBUILT" ;;
        "2:11:11: atlas_provenance graph_sha256 built_at_commit commit dirty_build mode graphify_version semantic_commit clean_full_pass ") ;;
        *) return 2 ;;
    esac
    [[ "$_RSHA" =~ ^[0-9a-f]{64}$ ]] || return 2
    [[ "$_RBUILT$_RCOMMIT$_RSEM" =~ ^[0-9a-f]*$ ]] || return 2
    return 0
}

# _atlas_bound <out-dir>: after _atlas_read_record returned 0, true when
# the record matches the graph.json there: its digest and the graph's own
# stamp (built_at_commit). Returns 2 after a line when the graph can't be
# hashed.
_atlas_bound() {
    _atlas_regular "$1/graph.json" || return 1
    _atlas_sha256 "$1/graph.json" || return 2
    [ "$_ASHA" = "$_RSHA" ] || return 1
    _atlas_graph_commit "$1/graph.json"
    [ "$_AGC" = "$_RBUILT" ]
}

# _atlas_write_file <file> <content>: the content through a temporary file
# beside it, renamed over <file>, so a symlink there is replaced, not
# followed.
_atlas_write_file() {
    local tmp="$1.tmp.$$"
    # A symlink goes first: mv onto a link to a directory would move the
    # file into that directory instead of replacing the link.
    if [ -L "$1" ] && ! rm -f -- "$1"; then
        printf 'atlas-check.sh: cannot remove the symlink %s.\n' "$(_atlas_printable "$1")"
        return 1
    fi
    if [ -e "$1" ] && [ ! -f "$1" ]; then
        printf '%s is not a regular file; remove it, then run $map-repo again.\n' "$(_atlas_printable "$1")"
        return 1
    fi
    rm -f -- "$tmp" 2>/dev/null
    if ! (set -C && printf '%s' "$2" >"$tmp") 2>/dev/null || ! mv -f -- "$tmp" "$1"; then
        rm -f -- "$tmp" 2>/dev/null
        printf 'atlas-check.sh: cannot write %s.\n' "$(_atlas_printable "$1")"
        return 1
    fi
}

# _atlas_has_dot_git <dir>: true when the directory or one above it (its
# physical path, / excluded) holds a .git entry. Builtins only.
_atlas_has_dot_git() {
    local d
    d="$(cd -P -- "$1" 2>/dev/null && pwd -P)" || return 1
    while [ -n "$d" ] && [ "$d" != / ]; do
        [ -e "$d/.git" ] && return 0
        d="${d%/*}"
    done
    return 1
}

# _atlas_unreadable_repo <dir>: true, after a line, when a .git entry lies
# at or above <dir> but git is missing or does not read <dir> as a work
# tree (safe.directory, say). Both subcommands refuse then, rather than
# take a repository for "outside git", where scratch would not ask and no
# commit would bind a record.
_atlas_unreadable_repo() {
    _atlas_has_dot_git "$1" || return 1
    if [ -z "$_ATLAS_GIT" ]; then
        printf '%s lies in a git repository, but git was not found; install git, then re-run.\n' "$(_atlas_printable "$1")"
        return 0
    fi
    _atlas_in_work_tree "$1" && return 1
    printf '%s lies in a git repository that git does not read as a work tree (see git status there); fix that, then re-run.\n' "$(_atlas_printable "$1")"
    return 0
}

# _atlas_tracked_out <path>: true when git tracks anything under
# <path>/graphify-out/ (matched in any case, as a case-insensitive file
# system opens it). Such files came from the repository, not from a build
# here, and Graphify reads some of them back (its cache), so a build with
# any of them is never clean and no record or pending file there is
# trusted.
_atlas_tracked_out() {
    local hit
    [ -n "$_ATLAS_GIT" ] && _atlas_in_work_tree "$1" || return 1
    # A failing ls-files counts as tracked (fails closed).
    hit="$(_atlas_git "$1" ls-files -- ':(icase)graphify-out/' 2>/dev/null)" || return 0
    [ -n "$hit" ]
}

# _atlas_has_input <entry>: true when <entry> is, or holds at any depth,
# anything but a directory: a file, or a symlink (even one to a
# directory). A directory it cannot list counts too (fails closed). Needs
# the glob settings _atlas_memory_input sets.
_atlas_has_input() {
    local e
    if [ -L "$1" ] || [ ! -d "$1" ]; then return 0; fi
    [ -r "$1" ] && [ -x "$1" ] || return 0
    for e in "$1"/*; do
        _atlas_has_input "$e" && return 0
    done
    return 1
}

# _atlas_memory_input <out-dir>: true when <out-dir>/memory exists and
# _atlas_has_input says it holds input (a memory that is a symlink or not
# a directory counts too). Graphify 0.9.85 scans that directory past every
# exclude, ignored or not, so the rest of graphify-out/ is not input but
# this is (FR-032, AC-119). A subshell, so the settings the walk needs (a
# sourcing caller may run with set -f, failglob, GLOBIGNORE or a FUNCNEST
# that would cut a deep walk short) never reach the caller. Builtins only.
_atlas_memory_input() (
    [ -e "$1/memory" ] || [ -L "$1/memory" ] || exit 1
    set +f
    unset GLOBIGNORE FUNCNEST
    shopt -s nullglob dotglob
    shopt -u failglob
    _atlas_has_input "$1/memory"
)

# _atlas_prov_begin <path>: run before Graphify starts. Writes only
# graphify-out/.atlas-provenance-pending (replacing a stale one): HEAD, the
# dirty flag, and the semantic pass a code-only update would carry over,
# taken from the current record only while it still binds the graph and
# git tracks nothing under graphify-out/ (a committed record, graph or
# cache could otherwise hand a forged clean pass to the build; with any
# tracked there, the capture is dirty). A file under graphify-out/memory/
# at begin makes the capture dirty and carries nothing over either: an
# update may take documents from memory/ into the graph, so its result
# can't stand on the last clean full pass. FR-032 binds that check to the
# start of the build, so finish does not repeat it. The capture also holds
# the SHA-256 digest of graph.json as it is now (empty when there is no
# regular graph.json): an update that leaves the graph byte-identical binds
# the record to the captured HEAD (FR-032, a no-op update; AC-122).
_atlas_prov_begin() {
    local pend clean=0 sem="" st=0 gsha=""
    _atlas_out_dir "$1" || return 1
    _atlas_capture "$1" || return 1
    if _atlas_memory_input "$_AO"; then
        # Input the work tree doesn't show: no carry-over, and a dirty capture.
        st=1
        _AD=1
    elif _atlas_tracked_out "$1"; then
        # Repository-supplied output: no carry-over, and a dirty capture.
        st=1
        _AD=1
    else
        _atlas_read_record "$_AO" || st=$?
    fi
    if [ "$st" -eq 0 ]; then
        _atlas_bound "$_AO" || st=$?
        [ "$st" -eq 2 ] && return 1
        if [ "$st" -eq 0 ] && [ "$_RCLEAN" = true ]; then
            clean=1
            sem="$_RSEM"
        fi
    fi
    if _atlas_regular "$_AO/graph.json"; then
        _atlas_sha256 "$_AO/graph.json" || return 1
        gsha="$_ASHA"
    fi
    if [ ! -d "$_AO" ] && ! mkdir -- "$_AO"; then
        printf 'atlas-check.sh: cannot create %s.\n' "$(_atlas_printable "$_AO")"
        return 1
    fi
    pend="$_AO/$ATLAS_PENDING"
    _atlas_write_file "$pend" "atlas-provenance-pending 2
head=${_AH}
dirty=${_AD}
prev_clean=${clean}
prev_semantic=${sem}
graph_sha256=${gsha}
" || return 1
    printf '[pending] %s\n' "$(_atlas_printable "$pend")"
}

# _atlas_read_pending <file>: the capture in _PH, _PD, _PC, _PS and _PG
# (the graph's digest at begin). Format 2 only: any other capture, an older
# begin's included, is no capture.
_atlas_read_pending() {
    local line n=0 want="atlas-provenance-pending 2"
    _PH="" _PD="" _PC="" _PS="" _PG=""
    _atlas_regular "$1" || return 1
    while IFS= read -r line || [ -n "$line" ]; do
        n=$((n + 1))
        case "$n:$line" in
            "1:$want") ;;
            2:head=*) _PH="${line#head=}" ;;
            3:dirty=0 | 3:dirty=1) _PD="${line#dirty=}" ;;
            4:prev_clean=0 | 4:prev_clean=1) _PC="${line#prev_clean=}" ;;
            5:prev_semantic=*) _PS="${line#prev_semantic=}" ;;
            6:graph_sha256=*) _PG="${line#graph_sha256=}" ;;
            *) return 1 ;;
        esac
    done <"$1"
    [ "$n" -eq 6 ] && [ -n "$_PD" ] && [ -n "$_PC" ] && [[ "$_PH$_PS" =~ ^[0-9a-f]*$ ]] \
        && [[ "$_PG" =~ ^([0-9a-f]{64})?$ ]]
}

# _atlas_verified_graphify_version: in _AGV, the version of the Graphify
# the runner verifies. Its --resolve prints the interpreter it resolved and
# exits 0 only when that interpreter's "-I -m graphify --version" prints the
# runner's pin exactly; the same invocation, through that interpreter, then
# names it here, so this script holds no pin of its own and never asks a
# bare graphify --version. Prints the runner's line and returns 1 when the
# check fails.
_atlas_verified_graphify_version() {
    local runner="${ATLAS_CONFIG_DIR}/skills/graphify/atlas-graphify.sh" py out re='^graphify ([0-9][0-9A-Za-z.+-]*)$'
    _AGV=""
    if ! _atlas_regular "$runner"; then
        printf '%s\n' "atlas-check.sh: the Graphify runner skills/graphify/atlas-graphify.sh is missing from the config directory; reinstall the atlas pack."
        return 1
    fi
    if ! py="$(PATH="${_ATLAS_ORIG_PATH-$PATH}" GRAPHIFY_NO_AUTO_REFRESH=1 /bin/sh "$runner" --resolve </dev/null)" \
        || [ -z "$py" ]; then
        printf '%s\n' "${py:-atlas-check.sh: the Graphify runner stopped without a line; reinstall the atlas pack.}"
        return 1
    fi
    out="$(GRAPHIFY_NO_AUTO_REFRESH=1 PYTHONSAFEPATH=1 "$py" -I -m graphify --version </dev/null 2>/dev/null)" || out=""
    out="${out%%$'\n'*}"
    if [[ "$out" =~ $re ]]; then
        _AGV="${BASH_REMATCH[1]}"
        return 0
    fi
    printf '%s\n' "atlas-check.sh: the interpreter the Graphify runner verified did not name its version; run \$atlas-doctor."
    return 1
}

# _atlas_json_str <value>: "value", or null when empty.
_atlas_json_str() {
    if [ -n "$1" ]; then printf '"%s"' "$1"; else printf 'null'; fi
}

# _atlas_prov_finish <path> <mode>: run after Graphify succeeds. Writes only
# graphify-out/atlas-provenance.json and removes the pending file; without
# a pending capture (no begin), it writes no record. The record's commit is
# the graph's built_at_commit, except after a no-op update: in update mode,
# when graph.json is byte-identical to the digest begin captured, Graphify
# re-extracted the code at the captured HEAD and found the same graph, so
# commit is that HEAD and built_at_commit keeps the older stamp (FR-032,
# AC-122). The build is dirty when the work tree differed from HEAD at begin
# or at finish, when HEAD moved during the build, when commit isn't the
# captured HEAD, or when git tracks something under graphify-out/. A clean
# full pass sets the semantic commit; an update carries over the one begin
# captured.
_atlas_prov_finish() {
    local path="$1" mode="$2" declined="${3:-}" pend graph dirty=false clean=false sem="" tracked commit
    _atlas_out_dir "$path" || return 1
    pend="$_AO/$ATLAS_PENDING"
    graph="$_AO/graph.json"
    if ! _atlas_read_pending "$pend"; then
        printf 'No provenance capture for this build (provenance begin runs before Graphify starts); no record written.\n'
        return 1
    fi
    if ! _atlas_regular "$graph"; then
        printf '%s is missing or not a regular file; no record written.\n' "$(_atlas_printable "$graph")"
        return 1
    fi
    if ! _atlas_verified_graphify_version; then
        printf 'No record written.\n'
        return 1
    fi
    _atlas_sha256 "$graph" || return 1
    _atlas_graph_commit "$graph"
    commit="$_AGC"
    if [ "$mode" = update ] && [ -n "$_PG" ] && [ "$_ASHA" = "$_PG" ]; then
        commit="$_PH"
    fi
    _atlas_capture "$path" || return 1
    # Tracked output (a committed pending file or cache included) makes the
    # build dirty and carries nothing over.
    tracked=""
    _atlas_tracked_out "$path" && tracked=1
    if [ "$_PD" = 1 ] || [ "$_AD" = 1 ] || [ "$_AH" != "$_PH" ] || [ "$commit" != "$_PH" ] || [ -n "$tracked" ]; then
        dirty=true
    fi
    if [ "$mode" = full ]; then
        # A declined semantic pass is no full pass: the documents, papers and
        # images were not read, so the semantic commit does not advance.
        if [ "$dirty" = false ] && [ "$declined" != semantic-declined ]; then
            clean=true
            sem="$commit"
        fi
    elif [ "$_PC" = 1 ] && [ -z "$tracked" ]; then
        clean=true
        sem="$_PS"
    fi
    _atlas_write_file "$_AO/$ATLAS_RECORD" "{
  \"atlas_provenance\": 2,
  \"graph_sha256\": \"${_ASHA}\",
  \"built_at_commit\": $(_atlas_json_str "$_AGC"),
  \"commit\": $(_atlas_json_str "$commit"),
  \"dirty_build\": ${dirty},
  \"mode\": \"${mode}\",
  \"graphify_version\": \"${_AGV}\",
  \"semantic_commit\": $(_atlas_json_str "$sem"),
  \"clean_full_pass\": ${clean}
}
" || return 1
    rm -f -- "$pend"
    printf '[recorded] %s\n' "$(_atlas_printable "$_AO/$ATLAS_RECORD")"
}

# _atlas_prov_state <path>: one line, the provenance state (FR-032):
# current, semantic-stale, "stale <record commit> <HEAD>", dirty-build,
# unbound or missing ("none" stands for an absent commit). Read-only.
_atlas_prov_state() {
    local path="$1" st=0 changed f sem_ignore
    _atlas_out_dir "$path" || return 1
    if [ ! -e "$_AO/graph.json" ] && [ ! -L "$_AO/graph.json" ]; then
        printf 'missing\n'
        return 0
    fi
    if ! _atlas_regular "$_AO/graph.json"; then
        printf '%s is not a regular file; remove it, then run $map-repo again.\n' "$(_atlas_printable "$_AO/graph.json")"
        return 1
    fi
    _atlas_read_record "$_AO" || st=$?
    case "$st" in
        1) printf 'missing\n'; return 0 ;;
        2) printf 'unbound\n'; return 0 ;;
    esac
    # Tracked output is never trusted here either, as in begin and finish
    # (a submodule at graphify-out/ could ship a record naming HEAD).
    if _atlas_tracked_out "$path"; then
        printf 'dirty-build\n'
        return 0
    fi
    _atlas_bound "$_AO" || st=$?
    case "$st" in
        1) printf 'unbound\n'; return 0 ;;
        2) return 1 ;;
    esac
    if [ "$_RDIRTY" = true ]; then
        printf 'dirty-build\n'
        return 0
    fi
    _AH=""
    if [ -n "$_ATLAS_GIT" ] && _atlas_in_work_tree "$path"; then
        _AH="$(_atlas_git "$path" rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null)" || _AH=""
    fi
    if [ "$_RCOMMIT" != "$_AH" ]; then
        printf 'stale %s %s\n' "${_RCOMMIT:-none}" "${_AH:-none}"
        return 0
    fi
    if [ "$_RCLEAN" != true ]; then
        printf 'semantic-stale\n'
        return 0
    fi
    if [ -n "$_AH" ] && [ "$_RSEM" != "$_AH" ]; then
        # Every file changed under <path> between the semantic commit and
        # HEAD; one that isn't code means the doc, paper and image results
        # are older than HEAD.
        if [ -z "$_RSEM" ] || ! _atlas_git "$path" cat-file -e "${_RSEM}^{commit}" 2>/dev/null \
            || ! changed="$(_atlas_git "$path" diff --no-ext-diff --no-renames --no-relative --name-only "$_RSEM" "$_AH" -- . \
                ':(exclude,glob)**/graphify-out/**' ':(exclude,glob)**/.archify/**' 2>/dev/null)"; then
            printf 'semantic-stale\n'
            return 0
        fi
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            f="${f#\"}"
            f="${f%\"}"
            if [ "$f" = .gitignore ]; then
                # Scratch rows committed since the full pass change no input.
                _atlas_blob "$path" "$_RSEM"
                sem_ignore="$_AGI_TXT"
                _atlas_blob "$path" "$_AH"
                _atlas_rows_only "$sem_ignore" "$_AGI_TXT" && continue
            fi
            if ! _atlas_is_code "$f"; then
                printf 'semantic-stale\n'
                return 0
            fi
        done <<EOF
$changed
EOF
    fi
    printf 'current\n'
}

_atlas_main_provenance() {
    local st=0
    case "${1:-}:$#" in
        begin:2 | state:2) ;;
        finish:3)
            case "$3" in
                full | update) ;;
                *) printf '%s\n' "$ATLAS_USAGE_PROVENANCE" >&2; return 2 ;;
            esac
            ;;
        finish:4)
            if [ "$3" != full ] || [ "$4" != semantic-declined ]; then
                printf '%s\n' "$ATLAS_USAGE_PROVENANCE" >&2
                return 2
            fi
            ;;
        *) printf '%s\n' "$ATLAS_USAGE_PROVENANCE" >&2; return 2 ;;
    esac
    if [ -z "$2" ]; then
        printf '%s\n' "$ATLAS_USAGE_PROVENANCE" >&2
        return 2
    fi
    _atlas_fix_path || return 1
    _atlas_find_git || st=$?
    [ "$st" -eq 2 ] && return 1
    if [ ! -d "$2" ]; then
        printf 'atlas-check.sh: %s is not a directory.\n' "$(_atlas_printable "$2")"
        return 1
    fi
    _atlas_target_gate "$2" || return 1
    _atlas_unreadable_repo "$2" && return 1
    case "$1" in
        begin) _atlas_prov_begin "$2" ;;
        finish) _atlas_prov_finish "$2" "$3" "${4:-}" ;;
        state) _atlas_prov_state "$2" ;;
    esac
}

_atlas_main_scratch() {
    local apply=""
    case "${1:-}" in
        graphify-out | .archify) ;;
        *) printf '%s\n' "$ATLAS_USAGE_SCRATCH" >&2; return 2 ;;
    esac
    if [ -z "${2:-}" ]; then
        printf '%s\n' "$ATLAS_USAGE_SCRATCH" >&2
        return 2
    fi
    if [ "$#" -eq 4 ] && [ "$3" = --apply ]; then
        case "$4" in
            gitignore | exclude | none) apply="$4" ;;
            *) printf '%s\n' "$ATLAS_USAGE_SCRATCH" >&2; return 2 ;;
        esac
    elif [ "$#" -ne 2 ]; then
        printf '%s\n' "$ATLAS_USAGE_SCRATCH" >&2
        return 2
    fi
    _atlas_fix_path || return 1
    _atlas_target_gate "$2" || return 1
    _atlas_scratch "$1" "$2" "$apply"
}

_atlas_main_rea() {
    local status=0
    if [ "$#" -ne 0 ]; then
        printf '%s\n' "$ATLAS_USAGE_REA" >&2
        return 2
    fi
    _atlas_fix_path || return 1
    case "$ATLAS_REA_MODE" in
        setup) _atlas_rea_setup || status=1 ;;
        doctor) _atlas_rea_report || status=1 ;;
    esac
    return "$status"
}

atlas_check_main() {
    case "${1:-}" in
        codex)
            ATLAS_CLIENT=codex
            ATLAS_CONFIG_DIR="$HOME/.agents"
            case "$ATLAS_CONFIG_DIR" in
                /*) ;;
                *) printf '%s\n' "atlas-check.sh: HOME is not an absolute path; set HOME to one." >&2; return 2 ;;
            esac
            ;;
        *) printf '%s\n' "$ATLAS_USAGE_CHECK" "$ATLAS_USAGE_SCRATCH" "$ATLAS_USAGE_PROVENANCE" "$ATLAS_USAGE_REA" >&2; return 2 ;;
    esac
    case "${2:-}" in
        check) ;;
        scratch) shift 2; _atlas_main_scratch "$@"; return ;;
        provenance) shift 2; _atlas_main_provenance "$@"; return ;;
        rea-setup) ATLAS_REA_MODE=setup; ATLAS_REA_SERVER_SCAN=1; shift 2; _atlas_main_rea "$@"; return ;;
        rea-doctor) ATLAS_REA_MODE=doctor; shift 2; _atlas_main_rea "$@"; return ;;
        *) printf '%s\n' "$ATLAS_USAGE_CHECK" "$ATLAS_USAGE_SCRATCH" "$ATLAS_USAGE_PROVENANCE" "$ATLAS_USAGE_REA" >&2; return 2 ;;
    esac
    local usage="$ATLAS_USAGE_CHECK"
    if [ "$#" -lt 3 ]; then
        printf '%s\n' "$usage" >&2
        return 2
    fi
    shift 2
    local id seen=" " asked_uv="" status=0
    for id in "$@"; do
        case "$id" in
            "" | *[!a-z-]*) id="" ;;
            *) case " ${ATLAS_IDS} " in *" $id "*) ;; *) id="" ;; esac ;;
        esac
        if [ -z "$id" ]; then
            printf 'atlas-check.sh: unknown prerequisite.\n%s\n' "$usage" >&2
            return 2
        fi
        [ "$id" = uv ] && asked_uv=1
    done
    _atlas_fix_path || return 1
    for id in "$@"; do
        case "$seen" in *" $id "*) continue ;; esac
        seen="${seen}${id} "
        "_atlas_check_${id//-/_}" && continue
        status=1
        # hint_for: uv installs Graphify, so a missing graphify brings uv's
        # line when uv is missing too and was not named.
        if [ "$id" = graphify ] && [ -z "$asked_uv" ]; then
            _atlas_check_uv quiet
        fi
    done
    return "$status"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    atlas_check_main "$@"
    exit $?
fi
