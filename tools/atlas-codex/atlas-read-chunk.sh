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
# @@ATLAS-BOUNDARY@@
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
