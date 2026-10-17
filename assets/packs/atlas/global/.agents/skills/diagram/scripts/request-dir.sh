#!/bin/sh
# request-dir.sh: the output-path guard of $diagram, $diagram-repo and
# $diagram-flow (PRD Part III FR-035; AC-073). Each Command runs it before
# its first candidate or renderer write.
#
#   request-dir.sh [--] <type> <slug>
#
# It makes the request's folder, .archify/<type>-<slug>-<YYYYMMDD-HHMMSS>
# in the current directory (local time now), and prints
# "[created] <folder>". .archify must be a real directory, or absent (it is
# then created); the folder must not exist yet, and is created fresh. A
# symlink at either, or anything but a directory, is refused with a line
# that says how to recover, and nothing is written: so a .archify that
# links elsewhere can never take the diagram outside the working
# directory, inside a git work tree or outside one. <type> is one of
# Archify's ten types and <slug> lowercase letters and digits joined by
# single dashes, at most 40 characters; anything else is refused before
# any tool runs.
#
# The repository is untrusted (R-023 in the pack notes): before it runs any
# tool (mkdir, date, rmdir), it takes PATH from the Graphify runner's --path, the
# agent's PATH cut to its absolute entries outside FR-031's untrusted area,
# so no tool can come from the repository (FR-030's helper scripts). When
# the runner refuses instead, it prints the refusal as printed and stops.
#
# A refusal after it made .archify or the folder removes what it made
# (rmdir, empty directories only), so "nothing written" holds.
#
# Exit 0 after [created]; 1 on a refusal about the files or the runner; 2
# on a type or slug it doesn't take.

made_scratch=""
made_folder=""

# refuse <line> [<status>]: undoes what this run made (an empty folder or
# .archify, never through a symlink), prints the line and exits.
refuse() {
    if [ -n "$made_folder" ] && [ -d "$made_folder" ] && [ ! -L "$made_folder" ]; then
        rmdir -- "$made_folder" 2>/dev/null
    fi
    if [ -n "$made_scratch" ] && [ -d .archify ] && [ ! -L .archify ]; then
        rmdir .archify 2>/dev/null
    fi
    printf 'request-dir: %s\n' "$1"
    exit "${2:-1}"
}

[ "${1:-}" = -- ] && shift
[ "$#" -eq 2 ] || refuse 'usage: request-dir.sh [--] <type> <slug>; nothing written.' 2
type=$1
slug=$2
case "$type" in
    architecture | workflow | sequence | dataflow | lifecycle | erd | class | tree | timeline | waterfall) ;;
    *) refuse "the type must be one of Archify's ten (architecture, workflow, sequence, dataflow, lifecycle, erd, class, tree, timeline, waterfall); nothing written." 2 ;;
esac
SLUG_RULE='the slug must be lowercase letters and digits joined by single dashes, at most 40 characters; nothing written.'
case "$slug" in
    '' | *[!a-z0-9-]* | -* | *- | *--*) refuse "$SLUG_RULE" 2 ;;
esac
[ "${#slug}" -le 40 ] || refuse "$SLUG_RULE" 2

NO_PATH='the Graphify runner printed no PATH; run $atlas-doctor; nothing written.'

# cut_path: the runner's one line (the cut PATH, or its refusal), then its
# exit status as "rc=<n>" on a line of its own, since a pipe drops it and
# every refusal the runner prints can start with "/". The runner runs in
# command position here, the one form Command text may call it in.
cut_path() {
    /bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path </dev/null
    printf 'rc=%s\n' "$?"
}

# real_dir <path>: refuses unless <path> is a directory and no symlink.
real_dir() {
    if [ -L "$1" ]; then
        refuse "$1 is a symlink, so the diagram could be written outside this directory; nothing written. Remove the link (or replace it with a real directory), then run the Command again."
    fi
    [ -d "$1" ] || refuse "$1 is not a directory; nothing written. Move it aside, then run the Command again."
}

# main: reads cut_path's two lines on stdin, then makes the folder with
# that PATH.
main() {
    IFS= read -r cut || cut=
    IFS= read -r rc || rc=
    if [ "$rc" != rc=0 ]; then
        case "$cut" in rc=* | '') cut="request-dir: $NO_PATH" ;; esac
        printf '%s\n' "$cut"
        exit 1
    fi
    case "$cut" in
        /*) ;;
        *) refuse "$NO_PATH" ;;
    esac
    PATH=$cut
    export PATH

    # The time first: nothing is written when it can't be read.
    stamp=$(date +%Y%m%d-%H%M%S) || refuse 'could not read the local time; nothing written.'
    case "$stamp" in
        [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]) ;;
        *) refuse 'could not read the local time; nothing written.' ;;
    esac
    if [ -e .archify ] || [ -L .archify ]; then
        real_dir .archify
    else
        mkdir .archify || refuse 'could not create .archify; nothing written.'
        made_scratch=1
        real_dir .archify
    fi
    folder=".archify/$type-$slug-$stamp"
    if [ -e "$folder" ] || [ -L "$folder" ]; then
        refuse "$folder exists already; nothing written. Run the Command again, for a fresh folder."
    fi
    # Without -p: it creates this one folder, or fails.
    mkdir "$folder" || refuse "could not create $folder; nothing written."
    made_folder=$folder
    real_dir .archify
    real_dir "$folder"
    printf '[created] %s\n' "$folder"
}

cut_path | main
