#!/bin/sh
# keep-copy.sh: the copy offer of $diagram, $diagram-repo and $diagram-flow
# (PRD Part III FR-035; AC-073).
#
#   keep-copy.sh <yes|no> <folder>
#
# <folder> is the diagram's folder, .archify/<type>-<slug>-<YYYYMMDD-HHMMSS>
# in the current directory (a trailing slash is fine), and the diagram is
# <slug>.html in it. On yes, the script copies that one file to
# docs/diagrams/<slug>.html in the current directory, creating the
# directories it needs, and prints "[copied] <path>", or "[replaced]
# <path>" when the copy existed. On no it prints "Not copied; the diagram
# stays in <folder>/." and writes nothing. Any other answer, or a folder
# that isn't .archify/ followed by one of Archify's ten types, a slug of
# lowercase letters and digits joined by single dashes (at most 40
# characters) and the timestamp, is refused before anything is read.
#
# It never writes through a symlink: .archify, the folder and the diagram
# must be a real directory and a real file, and docs, docs/diagrams and
# the copy must each be absent or real. The copy
# is written to a new temporary file beside it and renamed into place.
#
# The repository is untrusted (R-023 in the pack notes): before it runs
# any tool (mkdir, cp, mv, rm), it takes PATH from the Graphify runner's
# --path, the agent's PATH cut to its absolute entries outside FR-031's
# untrusted area, so no tool can come from the repository. When the runner
# refuses instead, it prints the refusal and stops.
#
# Exit 0 after a copy or a no; 1 on a refusal about the files or the
# runner; 2 on an answer or a folder it doesn't take. It writes nothing but
# the copy and the directories above it.

refuse() {
    printf 'keep-copy: %s; nothing copied.\n' "$1"
    exit "${2:-1}"
}

[ "$#" -eq 2 ] || refuse 'usage: keep-copy.sh <yes|no> <folder>' 2
case "$1" in
    yes | no) answer=$1 ;;
    *) refuse 'answer yes or no' 2 ;;
esac

# The folder: .archify/<type>-<slug>-<YYYYMMDD>-<HHMMSS>, nothing else.
FOLDER_RULE='give the folder as .archify/<type>-<slug>-<YYYYMMDD-HHMMSS>'
folder=${2%/}
case "$folder" in
    .archify/*) ;;
    *) refuse "$FOLDER_RULE" 2 ;;
esac
name=${folder#.archify/}
case "$name" in
    '' | *[!a-z0-9-]*) refuse "$FOLDER_RULE" 2 ;;
    *-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]) ;;
    *) refuse "$FOLDER_RULE" 2 ;;
esac
rest=${name%-*-*}
type=${rest%%-*}
slug=${rest#*-}
case "$type" in
    architecture | workflow | sequence | dataflow | lifecycle | erd | class | tree | timeline | waterfall) ;;
    *) refuse "$FOLDER_RULE (the type is one of Archify's ten)" 2 ;;
esac
[ "$slug" != "$rest" ] || refuse "$FOLDER_RULE" 2
case "$slug" in
    '' | -* | *- | *--*) refuse "$FOLDER_RULE (the slug is lowercase letters and digits joined by single dashes)" 2 ;;
esac
[ "${#slug}" -le 40 ] || refuse "$FOLDER_RULE (the slug has at most 40 characters)" 2

if [ "$answer" = no ]; then
    printf 'Not copied; the diagram stays in %s/.\n' "$folder"
    exit 0
fi

src="$folder/$slug.html"
dest_dir=docs/diagrams
dest="$dest_dir/$slug.html"

NO_PATH='keep-copy: the Graphify runner printed no PATH; run $atlas-doctor; nothing copied.'

# cut_path: the runner's one line (the cut PATH, or its refusal), then its
# exit status as "rc=<n>" on a line of its own, since a pipe drops it and
# every refusal the runner prints can start with "/". The runner runs in
# command position here, the one form Command text may call it in.
cut_path() {
    /bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path </dev/null
    printf 'rc=%s\n' "$?"
}

# main: reads cut_path's two lines on stdin, then copies with that PATH.
main() {
    IFS= read -r cut || cut=
    IFS= read -r rc || rc=
    if [ "$rc" != rc=0 ]; then
        case "$cut" in rc=* | '') cut=$NO_PATH ;; esac
        printf '%s\n' "$cut"
        exit 1
    fi
    case "$cut" in
        /*) ;;
        *) printf '%s\n' "$NO_PATH"; exit 1 ;;
    esac
    PATH=$cut
    export PATH

    # The source: real directories and a real file, no symlink on the way.
    for p in .archify "$folder"; do
        [ -L "$p" ] && refuse "$p is a symlink"
        [ -d "$p" ] || refuse "$p is not a directory"
    done
    if [ -L "$src" ] || [ ! -f "$src" ]; then
        refuse "$src is not a regular file"
    fi

    # The destination: each part absent or real.
    for p in docs "$dest_dir"; do
        [ -L "$p" ] && refuse "$p is a symlink"
        if [ -e "$p" ] && [ ! -d "$p" ]; then
            refuse "$p is not a directory"
        fi
    done
    [ -L "$dest" ] && refuse "$dest is a symlink"
    verb=copied
    if [ -e "$dest" ]; then
        [ -f "$dest" ] || refuse "$dest is not a regular file"
        verb=replaced
    fi

    mkdir -p -- "$dest_dir" || refuse "could not create $dest_dir"
    [ -L "$dest_dir" ] && refuse "$dest_dir is a symlink"
    tmp="$dest_dir/.$slug.html.keep-copy.$$"
    if [ -e "$tmp" ] || [ -L "$tmp" ]; then
        refuse "$tmp is in the way"
    fi
    if ! cp -- "$src" "$tmp"; then
        rm -f -- "$tmp"
        refuse "could not copy $src"
    fi
    if ! mv -f -- "$tmp" "$dest"; then
        rm -f -- "$tmp"
        refuse "could not write $dest"
    fi
    printf '[%s] %s\n' "$verb" "$dest"
}

cut_path | main
