#!/bin/sh
# target-kind.sh: the static target reader of the REA Commands (PRD Part III
# FR-038 "static by default", FR-039 rea-triage; AC-076, AC-077). $rea-triage,
# $rea-feature and $diagram-flow on a binary target run it before any
# investigation.
#
#   target-kind.sh [--] <target>
#
# It prints one line, "kind: <kind>", for a local path or a URL, where <kind>
# is native, electron-js, dotnet, apk, firmware, website, har or unknown. It
# only reads: file names, the first bytes of a file, for a .NET assembly a
# search of the file for the metadata signature, and for a directory its
# package.json and a search of the main file that names. It never
# executes the target, never opens a special file (a fifo, a device or a
# socket is refused), and never fetches a URL: an http or https URL is a
# website by its text alone. The target is data, never a command.
#
# The repository is untrusted (R-023 in the pack notes): before it runs any
# tool (od, grep, head), it takes PATH from the Graphify runner's --path, the
# agent's PATH cut to its absolute entries outside FR-031's untrusted area, so
# no tool can come from the repository (FR-030's helper scripts). When the
# runner refuses instead, it prints the refusal as printed and stops.
#
# Exit 0 after a kind line (unknown included); 1 on a refusal about the
# target or the runner; 2 on a missing target or one that starts with "-".

# refuse <line> [<status>]
refuse() {
    printf 'target-kind: %s\n' "$1"
    exit "${2:-1}"
}

[ "${1:-}" = -- ] && shift
[ "$#" -eq 1 ] || refuse 'usage: target-kind.sh [--] <target>' 2
target=$1
case "$target" in
    '') refuse 'give a target: a path or a URL.' 2 ;;
    -*) refuse 'a target cannot start with "-"; give its path (./-name) instead.' 2 ;;
esac

NO_PATH='the Graphify runner printed no PATH; run $atlas-doctor; nothing read.'

# cut_path: the runner's one line (the cut PATH, or its refusal), then its
# exit status as "rc=<n>" on a line of its own, since a pipe drops it and
# every refusal the runner prints can start with "/". The runner runs in
# command position here, the one form Command text may call it in.
cut_path() {
    /bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path </dev/null
    printf 'rc=%s\n' "$?"
}

# bytes <file> <count>: the first bytes as lowercase hex pairs, space joined.
bytes() {
    od -An -tx1 -N "$2" -- "$1" 2>/dev/null | tr -s ' \n' '  ' | sed 's/^ //; s/ $//'
}

# has_text <file> <text>: the file holds the text (binary files included).
has_text() {
    grep -aqF -- "$2" "$1" 2>/dev/null
}

# kind_of_file <file> <lowercase name>
kind_of_file() {
    f=$1
    case "$2" in
        *.har) echo har; return ;;
        *.apk) echo apk; return ;;
        *.asar) echo electron-js; return ;;
        *.js | *.cjs | *.m?s) echo electron-js; return ;;
        *.bin | *.img | *.fw | *.rom | *.trx) echo firmware; return ;;
    esac
    head4=$(bytes "$f" 4)
    case "$head4" in
        "7f 45 4c 46"* | "cf fa ed fe" | "ce fa ed fe" | "fe ed fa ce" | "fe ed fa cf" | "ca fe ba be") echo native; return ;;
        "68 73 71 73" | "73 71 73 68" | "55 42 49 23" | "27 05 19 56" | "5f 53 48 5f") echo firmware; return ;;
        "4d 5a"*)
            # BSJB starts the CLI metadata root of a managed assembly.
            if has_text "$f" BSJB; then echo dotnet; else echo native; fi
            return
            ;;
        "50 4b 03 04")
            if has_text "$f" AndroidManifest.xml; then echo apk; else echo unknown; fi
            return
            ;;
    esac
    echo unknown
}

# main_requires_electron <dir>: package.json's first "main" value, a
# relative path without a ".." step, names a regular file in the directory
# (as written, or with .js added, as Node resolves it) that holds
# require('electron'), import ... from 'electron' or import('electron'),
# in either quote. The file is only searched, never run.
main_requires_electron() {
    main=$(sed -n 's/.*"main"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1/package.json" 2>/dev/null | head -n 1)
    case "$main" in
        '' | /* | .. | ../* | */.. | */../*) return 1 ;;
    esac
    entry="$1/$main"
    [ -f "$entry" ] || entry="$entry.js"
    [ -f "$entry" ] || return 1
    grep -aqE "(require|import)[[:space:]]*\([[:space:]]*['\"]electron['\"][[:space:]]*\)|from[[:space:]]*['\"]electron['\"]" "$entry" 2>/dev/null
}

# kind_of_dir <dir>
kind_of_dir() {
    d=$1
    if [ -e "$d/resources/app.asar" ] || [ -d "$d/resources/app" ] || [ -e "$d/app.asar" ]; then
        echo electron-js
        return
    fi
    # A macOS bundle keeps the app under Contents/Resources, and Electron's
    # own framework beside the executable: both read as Electron before the
    # native .app fallback below.
    if [ -e "$d/Contents/Resources/app.asar" ] || [ -d "$d/Contents/Resources/app" ] \
        || [ -d "$d/Contents/Frameworks/Electron Framework.framework" ]; then
        echo electron-js
        return
    fi
    if [ -f "$d/package.json" ] && has_text "$d/package.json" '"electron"'; then
        echo electron-js
        return
    fi
    # An unpacked app (an extracted app.asar) often lists no electron
    # dependency: its package.json main names a file inside the directory
    # that requires or imports electron.
    if [ -f "$d/package.json" ] && main_requires_electron "$d"; then
        echo electron-js
        return
    fi
    case "$d" in
        *.app | *.app/) [ -d "$d/Contents/MacOS" ] && { echo native; return; } ;;
    esac
    echo unknown
}

main() {
    IFS= read -r cut || cut=
    IFS= read -r rc || rc=
    if [ "$rc" != rc=0 ]; then
        case "$cut" in rc=* | '') cut="target-kind: $NO_PATH" ;; esac
        printf '%s\n' "$cut"
        exit 1
    fi
    case "$cut" in
        /*) ;;
        *) refuse "$NO_PATH" ;;
    esac
    PATH=$cut
    export PATH

    # A URL is text: nothing is fetched.
    case "$target" in
        http://* | https://* | HTTP://* | HTTPS://*) printf 'kind: website\n'; exit 0 ;;
    esac

    if [ -d "$target" ]; then
        printf 'kind: %s\n' "$(kind_of_dir "$target")"
        exit 0
    fi
    # Only a regular file (or a link to one) is read; a fifo, a device or a
    # socket is refused unopened.
    if [ ! -e "$target" ]; then
        refuse "$target does not exist."
    fi
    [ -f "$target" ] || refuse "$target is not a regular file or a directory; nothing read."
    lower=$(printf '%s' "${target##*/}" | tr 'A-Z' 'a-z')
    printf 'kind: %s\n' "$(kind_of_file "$target" "$lower")"
}

cut_path | main
