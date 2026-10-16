#!/bin/sh
# update.sh: the one install step of $rea-update (PRD Part III FR-041;
# AC-081). It is the only place the atlas pack runs software that installs
# anything, and it does so only after the operator's yes.
#
#   update.sh <yes|no>
#
# On no it runs nothing at all and prints "Not updated: ...". On yes it reads
# REA's version, runs `rea update` exactly once, reads the version again, and
# prints what rea update printed (indented, colour sequences and control
# characters removed, at most 200 lines of at most 500 characters), then one
# result line:
#   [current] REA was already at the latest version (<v>); nothing changed.
#   [updated] REA <before> -> <after>; rea setup was not run.
#   [failed] rea update exited <n>; REA reports <after> (it was <before>).
#   [unknown] rea update exited 0, but REA reports <after> (it was <before>); ...
#     when either version could not be read, so neither line above holds.
# It never runs rea setup: the Command prints the setup line REA suggests,
# and the operator runs it. Any other answer is refused before anything runs.
#
# The repository is untrusted (R-023 in the pack notes): before it looks up
# rea, it takes PATH from the Graphify runner's --path, the agent's PATH cut
# to its absolute entries outside FR-031's untrusted area, so no rea (and no
# node or npm that rea starts) can come from the repository (FR-030's helper
# scripts). When the runner refuses instead, it prints the refusal as printed
# and stops. rea runs from / with stdin closed, so nothing in the working
# directory is read and nothing waits for input.
#
# The environment could come from the repository too (a direnv or mise file
# the operator trusted, say), and Node and npm read much of it: NODE_OPTIONS
# loads code, npm_config_* (hyphenated and scoped names included, which a
# shell can't even list) and PREFIX redirect the registry or the config. So
# every rea run gets a fresh environment through env -i, with only PATH,
# HOME, the user and locale names, TERM, TMPDIR and the proxy variables
# (without NODE_EXTRA_CA_CERTS or NODE_TLS_REJECT_UNAUTHORIZED a proxy can't
# break TLS). REA 6.4.0 needs no more: it finds its install prefix from its
# own package path and has npm install the release globally into that
# prefix with --ignore-scripts, so npm reads the operator's ~/.npmrc and that
# prefix's etc/npmrc, and runs no package script.
#
# Exit 0 after a no, [current] or [updated]; 1 after [failed], [unknown] or
# a refusal about the runner or rea; 2 on an answer it doesn't take.

[ "$#" -eq 1 ] || { printf '%s\n' 'rea-update: usage: update.sh <yes|no>; nothing updated.'; exit 2; }
case "$1" in
    yes) ;;
    no)
        printf '%s\n' 'Not updated: rea update did not run, and the REA install is unchanged.'
        exit 0
        ;;
    *)
        printf '%s\n' 'rea-update: answer yes or no; nothing updated.'
        exit 2
        ;;
esac

LINES_MAX=200
LINE_MAX=500
ESC=$(printf '\033')
BEL=$(printf '\007')
NO_PATH='rea-update: the Graphify runner printed no PATH; run /atlas-doctor; nothing updated.'

# cut_path: the runner's one line (the cut PATH, or its refusal), then its
# exit status as "rc=<n>" on a line of its own, since a pipe drops it and
# every refusal the runner prints can start with "/". The runner runs in
# command position here, the one form Command text may call it in.
cut_path() {
    /bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path </dev/null
    printf 'rc=%s\n' "$?"
}

# rea_run <argument>...: rea with the allowlisted environment, from /, stdin
# closed. ENV_BIN and REA_BIN are absolute paths from the cut PATH. The
# names are fixed words, so eval only ever sees "set -- NAME=..." with the
# value expanded inside quotes.
rea_run() {
    for name in TMPDIR TERM LANG LOGNAME USER no_proxy NO_PROXY https_proxy HTTPS_PROXY http_proxy HTTP_PROXY; do
        eval "isset=\${$name+x}"
        [ -z "$isset" ] || eval "set -- $name=\"\${$name}\" \"\$@\""
    done
    (cd / && "$ENV_BIN" -i PATH="$PATH" HOME="${HOME:-/}" "$@" "$REA_BIN" "$REA_ARG" </dev/null)
}

# version: the version rea reports, as the shared precondition script shows
# one (FR-029): the last word of the first line without a leading v, every
# character outside A-Za-z0-9.+_- removed; "an unreadable version" when
# nothing is left.
version() {
    REA_ARG=--version
    v=$(rea_run 2>/dev/null | head -n 1)
    v=${v##* }
    v=${v#v}
    v=$(printf '%s' "$v" | tr -cd 'A-Za-z0-9.+_-')
    [ -n "$v" ] || v='an unreadable version'
    printf '%s\n' "$v"
}

# main: reads cut_path's two lines on stdin, then updates with that PATH.
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

    REA_BIN=$(command -v rea) || REA_BIN=
    case "$REA_BIN" in
        /*) ;;
        *)
            printf '%s\n' 'rea-update: rea not found on PATH outside the repository; run /atlas-doctor; nothing updated.'
            exit 1
            ;;
    esac
    # env takes a word holding "=" as a variable, so such a path can't follow it.
    case "$REA_BIN" in
        *=*)
            printf '%s\n' 'rea-update: the path of rea holds "="; run rea update by hand; nothing updated.'
            exit 1
            ;;
    esac
    ENV_BIN=$(command -v env) || ENV_BIN=
    case "$ENV_BIN" in
        /*) ;;
        *)
            printf '%s\n' 'rea-update: env not found on PATH outside the repository; nothing updated.'
            exit 1
            ;;
    esac

    before=$(version)
    REA_ARG=update
    out=$(rea_run 2>&1)
    status=$?
    after=$(version)

    if [ -n "$out" ]; then
        printf '%s\n' 'rea update printed:'
        # Colour, cursor and OSC (hyperlink, title) sequences go whole, then
        # every other control character; each line is cut at LINE_MAX.
        printf '%s\n' "$out" | sed -e "s|${ESC}\[[0-?]*[ -/]*[@-~]||g" -e "s|${ESC}][^${BEL}${ESC}]*${BEL}||g" \
            -e "s|${ESC}][^${BEL}${ESC}]*${ESC}\\\\||g" | tr -d '\000-\010\013-\037\177' \
            | tr '\011' ' ' | head -n "$LINES_MAX" | cut -c "1-$LINE_MAX" | sed 's/^/    /'
        n=$(printf '%s\n' "$out" | wc -l)
        if [ "$n" -gt "$LINES_MAX" ]; then
            printf '%s\n' '    (more lines cut)'
        fi
    else
        printf '%s\n' 'rea update printed nothing.'
    fi

    if [ "$status" -ne 0 ]; then
        printf '[failed] rea update exited %s; REA reports %s (it was %s).\n' "$status" "$after" "$before"
        exit 1
    fi
    if [ "$before" = 'an unreadable version' ] || [ "$after" = 'an unreadable version' ]; then
        printf '[unknown] rea update exited 0, but REA reports %s (it was %s); run /atlas-doctor.\n' "$after" "$before"
        exit 1
    fi
    if [ "$before" = "$after" ]; then
        printf '[current] REA was already at the latest version (%s); nothing changed.\n' "$after"
        exit 0
    fi
    printf '[updated] REA %s -> %s; rea setup was not run.\n' "$before" "$after"
    exit 0
}

cut_path | main
