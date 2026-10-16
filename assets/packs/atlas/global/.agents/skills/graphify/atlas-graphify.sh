#!/bin/sh
# atlas-graphify.sh: the atlas pack's one runner for Graphify (PRD Part III
# FR-031, FR-029; AC-065, AC-107..AC-110, AC-112).
#
# Kit-authored, not vendored: the pack lists it in pack_paths, and each call
# to it from a vendored Graphify file is a recorded patch. After the
# preflight (atlas-preflight.sh), every Graphify CLI operation the skill runs
# goes through this script; no block runs a bare graphify or finds Graphify
# through PATH. The preflight's own version check is this script's
# (--resolve), so the two cannot drift apart.
#
# The supported surface (FR-031) is five operations: update (--force,
# --no-cluster), query (--dfs, --budget), path, explain and export html (no
# options). None takes a credential or a destination option. Any other
# operation (a hook subcommand, claude or codex install, another export, the
# MCP server, watch, add, clone, merge-graphs, extract, cluster-only,
# save-result, reflect, benchmark, ...) is answered with FR-031's
# unsupported-operation line, naming it, before anything else runs:
# Graphify is not even asked for its version.
#
# What it does, in this order, stopping at the first refusal with one line
# on stdout (the skill tells the agent to show it as printed) and exit 1:
#   1. a fixed environment for itself and Graphify: PATH cut to its
#      absolute entries outside the untrusted area (FR-031: the outermost
#      git checkout around the working directory, or the working directory
#      outside git; the ATLAS-BOUNDARY block below; /usr/bin:/bin when
#      none is left, and a refusal when the area holds /usr/bin or /bin)
#      before any external command runs, so no command it,
#      Graphify or a skill block runs comes from the repository (with
#      --path it prints that PATH and exits: every skill block's first
#      command), GRAPHIFY_NO_AUTO_REFRESH=1, GRAPHIFY_QUERY_LOG_DISABLE=1,
#      GIT_NO_LAZY_FETCH=1, GIT_PROTOCOL_FROM_USER=0, GIT_ALLOW_PROTOCOL empty
#      (no lazy fetch, no transport), the git helper variables unset,
#      PYTHONPATH unset, PYTHONSAFEPATH=1 and PYTHONHASHSEED=0. The last one
#      stops 0.9.85's update from re-executing itself as "python -m
#      graphify" without -I, which would import a graphify/ package from the
#      working directory. GRAPHIFY_OUT set to anything but "" is refused,
#      naming its value: it would move Graphify's output away from the
#      checked paths;
#   2. the operation: one of the five above, or the unsupported-operation
#      line; then (for every operation and --resolve, not --path) the git
#      environment rule: a git-steering variable set non-empty (GIT_CONFIG*,
#      GIT_DIR, GIT_WORK_TREE and the rest, listed below) is refused,
#      naming it, before any git call;
#   3. the interpreter, found beside the real graphify executable (uv tool,
#      pipx or a venv) after following its symlinks, never from its first
#      line. The executable and the interpreter, by name, resolved
#      directory and every symlink step, must lie outside the untrusted
#      area (every scan root lies inside it, so this covers the scan roots
#      too), so a repository can supply neither: a graphify found on an
#      absolute PATH entry inside it is refused, naming it and the area;
#   4. the pin, through the interpreter that will run: "$PY" -I -m graphify
#      --version must print exactly "graphify 0.9.85" (a newer CLI is a
#      mismatch), or it prints the matching FR-029 graphify fix line. The
#      executable's own --version is read only to word that line;
#   5. with --resolve (the preflight's call), it prints the interpreter's
#      path and exits 0;
#   6. otherwise the operation, checked against TABLE below: every option
#      must be listed there, and each value goes where the 0.9.85 parser
#      reads it literally. Then the output-root check on every destination
#      the operation writes (its listed defaults): inside the working
#      directory, not "..", and not being, containing or sitting below a
#      symlink. Then it runs "$PY" -I -m graphify <operation> ... in the
#      fixed environment.
#
# Usage (from a skill block; values only after the runner's own "--"):
#   /bin/sh atlas-graphify.sh <operation> [<option> ...] [-- <value> ...]
#   /bin/sh atlas-graphify.sh --resolve
#   PATH=$(/bin/sh atlas-graphify.sh --path) || { printf '%s\n' "$PATH"; exit 1; }
# The options before "--" are fixed words from TABLE (a flag such as --dfs,
# or a value option such as --budget). The values after "--" fill the value
# options in the order they were named, then the operation's own values
# (for query: --budget -- "$BUDGET" "$QUESTION"). No value may start with
# "-": at 0.9.85 no operation the skill uses honours "--", so such a value
# could be read as an option.

GRAPHIFY_PIN="0.9.85"

# Builtins only (pwd, cd, case, command, printf, [, set, for, while) until
# PATH is fixed below.
# ATLAS-BOUNDARY-BEGIN
# FR-031's untrusted area, shared by skills/graphify/atlas-graphify.sh,
# skills/atlas-doctor/scripts/atlas-check.sh and
# skills/atlas-doctor/scripts/atlas-archify.sh: this block is
# byte-identical in all three (a static check, AC-114), POSIX sh so that
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
_refuse_inside() {
    _untrusted_line "$1"
    exit 1
}
_atlas_area_init || exit 1
# PATH: _GABS keeps the absolute entries, _GPATH those of them that lie
# outside the untrusted area, by name and resolved. Every command after
# this runs from _GPATH, and so do Graphify and its children (git, say) and
# every skill block, which takes _GPATH with --path as its first command.
set -f
_GABS=""
_GPATH=""
_GIFS="$IFS"
IFS=:
for _GE in $PATH; do
    case "$_GE" in /*) ;; *) continue ;; esac
    _GABS="${_GABS:+$_GABS:}$_GE"
    _GR=$(cd -P "$_GE" 2>/dev/null && pwd -P) || _GR="$_GE"
    _inside "$_GE" || _inside "$_GR" || _GPATH="${_GPATH:+$_GPATH:}$_GE"
done
IFS="$_GIFS"
set +f
PATH="${_GPATH:-/usr/bin:/bin}"
export PATH

# graphify is looked up on every absolute entry, so one inside the
# untrusted area (by name, resolved directory or any symlink step) is
# refused, naming it, rather than silently skipped; --path refuses it too,
# so a block whose PATH would hide it still stops.
GRAPHIFY_BIN=$(PATH="${_GABS:-/usr/bin:/bin}"; command -v graphify 2>/dev/null)
case "$GRAPHIFY_BIN" in /*) ;; *) GRAPHIFY_BIN="" ;; esac
[ -n "$GRAPHIFY_BIN" ] && _inside_path "$GRAPHIFY_BIN" && _refuse_inside "$GRAPHIFY_BIN"

if [ "${1:-}" = --path ]; then
    [ "$#" -eq 1 ] || { printf '%s\n' "atlas-graphify.sh: --path takes nothing else."; exit 2; }
    printf '%s\n' "${_GPATH:-/usr/bin:/bin}"
    exit 0
fi

# The supported surface (FR-031), with shell builtins only: any operation
# but the five answers with the unsupported-operation line, naming it (a
# second word for export, hook, claude and codex), and nothing runs.
_unsupported() {
    printf '%s\n' "Not available in the atlas pack: $1. The pack supports building, updating and querying the graph; to use $1, run upstream Graphify by hand outside the kit (see \"Running Graphify by hand\" in references/atlas-pack-notes.md in the agents directory (`~/.agents`))."
    exit 1
}
case "${1:-}" in
    --resolve | update | query | path | explain) ;;
    "" | -* | *[!a-z0-9-]*) printf '%s\n' "atlas-graphify.sh: name an operation."; exit 2 ;;
    export | hook | claude | codex)
        case "$1 ${2:-}" in
            "export html") ;;
            *" " | *" "-* | *" "*[!a-z0-9-]*) _unsupported "$1" ;;
            *) _unsupported "$1 $2" ;;
        esac ;;
    *) _unsupported "$1" ;;
esac

# The git environment rule (FR-031): Graphify's detection runs git, which
# inherits this environment, and these variables steer what git reads and
# runs (configuration, repository, helpers), so a value the repository's
# environment supplies (direnv, a devcontainer) could start a command or hide
# a setting from the preflight's configuration check (GIT_CONFIG applies to
# git config only, not to the listing). Set non-empty, each is refused,
# naming it, never its value; GIT_CONFIG even when empty, since git config
# reads an empty one as a file named "" and so still skips .git/config.
# GIT_TEST_FSMONITOR names a hook git runs when no core.fsmonitor is set.
# GIT_CONFIG_NOSYSTEM is not refused: it only drops the system file, for
# every git command alike. Helper variables that redirect neither the
# repository nor the configuration (GIT_ASKPASS, SSH_ASKPASS, GIT_SSH,
# GIT_SSH_COMMAND, GIT_TERMINAL_PROMPT, GIT_EXTERNAL_DIFF) are not refused
# either: an IDE sets them for credentials, and no operation here needs a
# credential or a transport. They are unset below, for every child.
# Builtins only.
_git_env_refuse() {
    printf '%s\n' "$1 is set in the environment, and git would follow it while Graphify lists the files; unset it before running the Command (unset $1), then run it again."
    exit 1
}
[ "${GIT_CONFIG+set}" = set ] && _git_env_refuse GIT_CONFIG
for _GN in GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM \
    GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR \
    GIT_CEILING_DIRECTORIES GIT_EXEC_PATH GIT_TEMPLATE_DIR GIT_TEST_FSMONITOR; do
    eval "_GW=\${$_GN:-}"
    [ -n "$_GW" ] && _git_env_refuse "$_GN"
done
# GIT_CONFIG_KEY_<n> and GIT_CONFIG_VALUE_<n>, found by name in export -p.
# Each variable starts its own line there; a line from inside a multi-line
# value can only name a variable that is then checked and found unset or
# empty, so no variable is missed and none is refused wrongly.
_GW=$(export -p)
_GIFS="$IFS"
IFS='
'
set -f
for _GL in $_GW; do
    case "$_GL" in
        "export "*) _GL="${_GL#export }" ;;
        "declare -x "*) _GL="${_GL#declare -x }" ;;
        *) continue ;;
    esac
    _GN="${_GL%%=*}"
    case "$_GN" in
        GIT_CONFIG_KEY_* | GIT_CONFIG_VALUE_*) ;;
        *) continue ;;
    esac
    case "$_GN" in *[!A-Za-z0-9_]*) continue ;; esac
    eval "_GW2=\${$_GN:-}"
    [ -n "$_GW2" ] && _git_env_refuse "$_GN"
done
set +f
IFS="$_GIFS"
unset _GW _GW2 _GL _GN

export GRAPHIFY_NO_AUTO_REFRESH=1
export GRAPHIFY_QUERY_LOG_DISABLE=1
# No helper, no lazy fetch and no transport for Graphify or any git it starts
# (its detection runs plain git ls-files, which expands a sparse index and
# would fetch a missing object from a promisor remote over a transport
# command the repository configured, core.sshCommand say): the recorded
# settings every skill block exports, GIT_ALLOW_PROTOCOL empty included.
unset GIT_ASKPASS SSH_ASKPASS GIT_SSH GIT_SSH_COMMAND GIT_TERMINAL_PROMPT GIT_EXTERNAL_DIFF
export GIT_NO_LAZY_FETCH=1 GIT_PROTOCOL_FROM_USER=0 GIT_ALLOW_PROTOCOL=
unset PYTHONPATH
export PYTHONSAFEPATH=1
export PYTHONHASHSEED=0

if [ -n "${GRAPHIFY_OUT:-}" ]; then
    printf '%s\n' "GRAPHIFY_OUT is set (to $GRAPHIFY_OUT), which would move Graphify's output away from the checked paths; unset it, then run /graphify again."
    exit 1
fi
unset GRAPHIFY_OUT

# _follow: _GF with its symlinks followed (at most 40), in place.
_follow() {
    _GN=0
    while [ -L "$_GF" ] && [ "$_GN" -lt 40 ]; do
        _GL=$(readlink "$_GF")
        case "$_GL" in /*) _GF="$_GL" ;; *) _GF="${_GF%/*}/$_GL" ;; esac
        _GN=$((_GN + 1))
    done
}

PYTHON=""
_GP=""
_GV=""
if [ -n "$GRAPHIFY_BIN" ]; then
    _GF="$GRAPHIFY_BIN"
    _follow
    _GB="$_GF"
    _GD="${_GB%/*}"
    _GD=$(cd -P "${_GD:-/}" 2>/dev/null && pwd -P)
    if [ -n "$_GD" ]; then
        _GP="$_GD/python"
        _inside_path "$_GP" && _refuse_inside "$_GP"
    fi
    if [ -n "$_GP" ] && [ -f "$_GP" ] && [ -x "$_GP" ]; then
        _GV=$("$_GP" -I -m graphify --version </dev/null 2>/dev/null | head -1)
    fi
    [ "$_GV" = "graphify $GRAPHIFY_PIN" ] && PYTHON="$_GP"
fi
if [ -z "$PYTHON" ]; then
    # The constraints file atlas-doctor installs, as a resolved absolute path quoted for POSIX shells.
    _GC="$HOME/.agents/skills/atlas-doctor"
    case "$_GC" in /*) ;; *) _GC="$PWD/$_GC" ;; esac
    if [ -d "$_GC" ]; then _GR=$(cd -P "$_GC" 2>/dev/null && pwd -P) && _GC="$_GR"; fi
    _GC="$_GC/graphify-constraints.txt"
    _GQ="'$(printf '%s' "$_GC" | sed "s/'/'\\\\''/g")'"
    _GBROKEN=""
    if [ -n "$GRAPHIFY_BIN" ] && [ -z "$_GV" ]; then
        # The interpreter could not run Graphify: the executable's version
        # only words the fix line (installed, but broken, or another version).
        _GV=$("$GRAPHIFY_BIN" --version </dev/null 2>/dev/null | head -1)
        [ "$_GV" = "graphify $GRAPHIFY_PIN" ] && _GBROKEN=1
    fi
    if [ -z "$GRAPHIFY_BIN" ]; then
        printf '%s\n' "Graphify CLI $GRAPHIFY_PIN not found. Install: uv tool install graphifyy==$GRAPHIFY_PIN --constraints $_GQ"
    elif [ -n "$_GBROKEN" ]; then
        printf '%s\n' "Graphify CLI $GRAPHIFY_PIN not found (found $GRAPHIFY_PIN, but its Python cannot import graphify). Install: uv tool install graphifyy==$GRAPHIFY_PIN --constraints $_GQ --force"
    else
        _FOUND="${_GV#graphify }"
        printf '%s\n' "Graphify CLI $GRAPHIFY_PIN not found (found ${_FOUND:-an unreadable version}). Install: uv tool install graphifyy==$GRAPHIFY_PIN --constraints $_GQ --force"
    fi
    exit 1
fi

if [ "${1:-}" = --resolve ]; then
    [ "$#" -eq 1 ] || { printf '%s\n' "atlas-graphify.sh: --resolve takes nothing else."; exit 2; }
    printf '%s\n' "$PYTHON"
    exit 0
fi

# The operation, in the pinned interpreter, isolated. Its arguments arrive
# as argv and are never part of any shell or Python source. The program
# below sits in one single-quoted shell word: it must hold no single quote.
exec "$PYTHON" -I -c '
import os, sys

# ATLAS-TABLE-BEGIN
# The supported operations (FR-031), exactly. For each: "values", the names
# of its own values in the order the parser reads them; "flags", the
# options it takes without a value; "options", the options it takes with
# one (none of them a destination); and "writes", its write destinations
# ("{0}" is its first own value). The shell above answers every other
# operation with the unsupported-operation line.
TABLE = {
    "update": {"values": ["the path"], "flags": ["--force", "--no-cluster"], "options": [],
               "writes": ["graphify-out", "{0}/graphify-out"]},
    "query": {"values": ["the question"], "flags": ["--dfs"], "options": ["--budget"],
              "writes": ["graphify-out"]},
    "path": {"values": ["the first node", "the second node"], "flags": [], "options": [],
             "writes": ["graphify-out"]},
    "explain": {"values": ["the node"], "flags": [], "options": [], "writes": ["graphify-out"]},
    "export html": {"values": [], "flags": [], "options": [], "writes": ["graphify-out"]},
}
# ATLAS-TABLE-END

def stop(message):
    sys.stdout.write(message + "\n")
    sys.exit(1)

cwd = os.getcwd()

def shown(path):
    return os.path.relpath(path, cwd)

def inside(path):
    return os.path.commonpath([cwd, path]) == cwd

def destination(given):
    """The output-root check on one destination: inside the working
    directory, no "..", and not being, containing or sitting below a
    symlink."""
    if ".." in given.split("/"):
        stop("%s uses \"..\"; give a path inside the working directory without it." % given)
    full = os.path.normpath(os.path.join(cwd, given))
    if not inside(full):
        stop("%s lies outside the working directory; Graphify may write only inside it." % given)
    cur = cwd
    for part in os.path.relpath(full, cwd).split(os.sep):
        if part == ".":
            continue
        cur = os.path.join(cur, part)
        if os.path.islink(cur):
            stop("%s is a symlink; remove it, then run /graphify again." % shown(cur))
        if not os.path.lexists(cur):
            return
    if not inside(os.path.realpath(full)):
        stop("%s lies outside the working directory; Graphify may write only inside it." % given)
    if os.path.isdir(full):
        def unreadable(exc):
            stop("cannot read all of %s; fix its permissions, then run /graphify again." % shown(full))
        for dirpath, dirnames, filenames in os.walk(full, onerror=unreadable):
            for name in dirnames + filenames:
                path = os.path.join(dirpath, name)
                if os.path.islink(path):
                    stop("%s is a symlink; remove it, then run /graphify again." % shown(path))

args = sys.argv[1:]
two = " ".join(args[:2])
if len(args) > 1 and two in TABLE:
    op, rest = two, args[2:]
elif args and args[0] in TABLE:
    op, rest = args[0], args[1:]
else:
    stop("atlas-graphify.sh: %s is not in the runner table." % (args[0] if args else "no operation"))
spec = TABLE[op]

if "--" in rest:
    named, values = rest[:rest.index("--")], rest[rest.index("--") + 1:]
else:
    named, values = rest, []
flags, options = [], []
for word in named:
    if word in flags or word in options:
        stop("atlas-graphify.sh: %s names %s twice." % (op, word))
    if word in spec["flags"]:
        flags.append(word)
    elif word in spec["options"]:
        options.append(word)
    else:
        stop("atlas-graphify.sh: %s does not take %s; the atlas pack passes only the options its table lists." % (op, word))
own = spec["values"]
want = len(options) + len(own)
if len(values) != want:
    stop("atlas-graphify.sh: %s takes %d value(s) after --, got %d." % (op, want, len(values)))
names = ["the %s value" % o for o in options] + list(own)
for n, value in enumerate(values, 1):
    if value.startswith("-"):
        stop("atlas-graphify.sh: %s value %d (%s) starts with \"-\", which Graphify 0.9.85 would read as an option; refused."
             % (op, n, names[n - 1]))
opt_values = values[:len(options)]
own_values = values[len(options):]

checked = set()
for d in spec["writes"]:
    d = d.format(*own_values)
    if os.path.normpath(os.path.join(cwd, d)) not in checked:
        checked.add(os.path.normpath(os.path.join(cwd, d)))
        destination(d)

argv = [sys.executable, "-I", "-m", "graphify"] + op.split(" ") + own_values
for o, v in zip(options, opt_values):
    argv += [o, v]
argv += flags
sys.stdout.flush()
os.execv(sys.executable, argv)
' "$@"
