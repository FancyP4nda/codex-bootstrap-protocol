#!/bin/sh
# atlas-read-chunk.sh: the one command a Graphify semantic worker uses to read
# a file of its chunk (T053 round 6). Run as
#   /bin/sh "$HOME/.agents/skills/graphify/atlas-read-chunk.sh" graphify-out/.graphify_chunk_NN.files <index>
# from the project root. Kit-authored for the Codex mirror, not derived.
#
# It keeps the worker's reader out of the repository's reach: before any
# external command runs it finds FR-031's untrusted area (the ATLAS-BOUNDARY
# block below, spliced in by tools/migrate-atlas.mjs from the Graphify runner so
# the two cannot drift) and cuts PATH to the absolute entries outside it, as the
# runner does. It runs no cat or other tool from the ambient PATH: the
# interpreter path is read with the shell's own `read`, must be absolute and
# executable, and must lie outside the untrusted area by name, resolved
# directory and every symlink step. Then it hands over to atlas-read-chunk.py,
# which checks the entry again and finds pdftotext only on this PATH, outside the
# untrusted areas of the scan root and of the working directory.
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
_atlas_area_init || exit 1
set -f
_RPATH=""
_RIFS="$IFS"
IFS=:
for _RE in $PATH; do
    case "$_RE" in /*) ;; *) continue ;; esac
    _RR=$(cd -P "$_RE" 2>/dev/null && pwd -P) || _RR="$_RE"
    _inside "$_RE" || _inside "$_RR" || _RPATH="${_RPATH:+$_RPATH:}$_RE"
done
IFS="$_RIFS"
set +f
PATH="${_RPATH:-/usr/bin:/bin}"
export PATH

_stop() {
    printf '%s\n' "STOP: $1"
    exit 1
}
if [ "$#" -ne 2 ]; then
    _stop "usage: atlas-read-chunk.sh <graphify-out/.graphify_chunk_NN.files> <index>, the index a whole number from 0."
fi
case "$1" in */*) _RDIR="${1%/*}" ;; *) _RDIR=. ;; esac
_RPY=""
if [ -r "$_RDIR/.graphify_python" ]; then
    IFS= read -r _RPY <"$_RDIR/.graphify_python" || [ -n "$_RPY" ] || _RPY=""
fi
case "$_RPY" in
    /*) ;;
    *) _stop "found no absolute interpreter path in $_RDIR/.graphify_python; run Graphify's preflight again." ;;
esac
if [ ! -f "$_RPY" ] || [ ! -x "$_RPY" ]; then
    _stop "the interpreter in $_RDIR/.graphify_python is not an executable file; run Graphify's preflight again."
fi
if _inside_path "$_RPY"; then
    _atlas_shown "$_ABHIT"
    _stop "the interpreter lies inside $_ABV, which atlas treats as the repository, so the repository could supply it; run Graphify's preflight again."
fi
case "$0" in */*) _RHERE="${0%/*}" ;; *) _RHERE=. ;; esac
unset PYTHONPATH
export PYTHONSAFEPATH=1
exec "$_RPY" -I "$_RHERE/atlas-read-chunk.py" "$@"
