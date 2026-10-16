#!/bin/sh
# repo-identity.sh: the repository identity $diagram-repo pins its source
# links to (PRD Part III FR-036; AC-075).
#
#   repo-identity.sh
#   repo-identity.sh --check <commit> <paths on stdin, one per line>
#   repo-identity.sh --recheck <commit> <state>
#
# Outside a git work tree it prints "outside-git". Otherwise, one line each:
#   root <path>     the work tree's top level
#   head <sha>      HEAD's full commit SHA, or "head none" before the
#                   first commit. This is the frozen commit: the diagram's
#                   meta.repository.revision, and what --check and
#                   --recheck are given back
#   origin <url>    the origin remote, in a form Archify can pin source
#                   links to: an HTTP(S) URL with any user name, password
#                   or token removed, ssh://git@..., or git@host:path;
#                   "origin unsupported" for any other origin (another SSH
#                   user, an SSH password, a local path or file:// URL, a
#                   query, fragment, space or control character), which is
#                   never printed; or "origin none"
# then, after a commit, either
#   state <id>      a fingerprint of git's tracked changes, for --recheck
#   edits <n>       how many tracked files git's status reports as changed
#                   against HEAD: staged or not, added, deleted or edited
#                   (untracked files don't count). Git applies its built-in
#                   text and eol conversion, so a clean CRLF checkout of an
#                   LF file under an eol rule counts 0
#   edit <path>     for each of the first 20 of them, as git names them
#   edit-more <k>   when k more aren't shown (the list is display only)
# or, when git's own status can't be run safely or trusted,
#   unpinned <why>  no citation may be pinned (nothing is guessed), and
#   state unpinned  <why> is one of: filters (a path carries a filter
#                   attribute: Git LFS or any other, whose command git
#                   would run), index-flags (an assume-unchanged entry, or
#                   a skip-worktree one whose file is on disk, hides
#                   edits from git), names (a name git must quote) or
#                   status (git could not report)
#
# The gate (gather): git's status is run only when no path, tracked or
# untracked candidate, carries a filter attribute (git check-attr reads
# attributes and runs nothing), every git call has fsmonitor and hooks off,
# submodules are ignored (their status would run the submodule's own
# configuration), and no lazy fetch or transport is allowed.
#
# --check <commit> decides citations: for each path on stdin, relative to
# the work tree's top level, against that frozen commit (never HEAD):
#   [pinned] <path>   a regular file in the commit's tree that git's status
#                     does not list as changed, with no symlink on its way
#                     (a sparse-checkout file git skips is unchanged, and
#                     citable because the commit holds it)
#   [changed] <path>  it differs from the commit or the index, staged or
#                     not, is gone, or a symlink sits on its path
#   [absent] <path>   the commit has no regular file there (an untracked
#                     file, a directory, a submodule or a committed symlink)
#   [outside] <path>  an absolute path, one with a ".." part, or one with
#                     a control character (not echoed)
#   [unknown] <path>  git couldn't read it
# Only a [pinned] path may be cited at the commit. It exits 0 only when
# every path is [pinned]. When the gate says unpinned it prints
# "unpinned <why>" and exits 1; when HEAD is no longer the commit it
# refuses (start the Command again); outside git or before the first
# commit it refuses every citation.
#
# --recheck <commit> <state> is the last step before finalize: it exits 0
# only when HEAD is still the commit and the changed set's state is the one
# identity printed; otherwise it refuses with the restart line.
#
# The repository is untrusted (R-023 in the pack notes): it takes PATH from
# the Graphify runner's --path, the agent's PATH cut to its absolute
# entries outside FR-031's untrusted area, before it looks up git, so git
# can't come from the repository; when the runner refuses, it prints the
# refusal and stops. git runs without optional locks, with the fsmonitor
# and hooks off, replace refs ignored, pathspecs literal (whatever the
# environment says) and no lazy fetch or transport, and writes nothing. A
# root whose name holds a control character is refused, so the root can't
# carry a line break into the Command's heredoc.
#
# Exit 0 on a result; 1 on a refusal (the runner's, no git, an unreadable
# repository, a root with a control character, a moved HEAD) or a --check
# path that isn't [pinned]; 2 on a usage error.

refuse() {
    printf 'diagram-repo: %s\n' "$1"
    exit 1
}

mode=identity
frozen=
want_state=
case "$#:${1:-}" in
    0:) ;;
    2:--check) mode=check frozen=$2 ;;
    3:--recheck) mode=recheck frozen=$2 want_state=$3 ;;
    *) printf '%s\n' 'usage: repo-identity.sh [--check <commit> | --recheck <commit> <state>]' >&2; exit 2 ;;
esac
if [ "$mode" != identity ]; then
    case "$frozen" in
        *[!0-9a-f]* | '') printf '%s\n' 'repo-identity.sh: the commit must be a full lowercase hex SHA' >&2; exit 2 ;;
    esac
    case ${#frozen} in
        40 | 64) ;;
        *) printf '%s\n' 'repo-identity.sh: the commit must be a full lowercase hex SHA' >&2; exit 2 ;;
    esac
fi
# The paths to check, read before stdin becomes the runner's pipe.
paths=""
if [ "$mode" = check ]; then
    while IFS= read -r p || [ -n "$p" ]; do
        paths="$paths$p
"
    done
fi

NO_PATH='the Graphify runner printed no PATH; run /atlas-doctor.'

# cut_path: the runner's one line (the cut PATH, or its refusal), then its
# exit status as "rc=<n>" on a line of its own, since a pipe drops it and
# every refusal the runner prints can start with "/". The runner runs in
# command position here, the one form Command text may call it in.
cut_path() {
    /bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path </dev/null
    printf 'rc=%s\n' "$?"
}

# git_ <args>: git with no optional locks (so nothing is written and no hook
# fires; hooksPath covers only file hooks), no fsmonitor, strict stat checks,
# the two filter names check-attr can't tell from "none" emptied, no replace
# refs, every pathspec literal, and no network: no lazy fetch from a
# partial clone's promisor remote, and an empty transport allow-list, so a
# delivered .git's core.sshCommand or uploadpack can't run (as Archify's
# own evidence reader does).
git_() {
    GIT_OPTIONAL_LOCKS=0 GIT_LITERAL_PATHSPECS=1 GIT_NO_LAZY_FETCH=1 GIT_ALLOW_PROTOCOL= \
        git --no-replace-objects -c core.fsmonitor=false -c core.hooksPath=/dev/null \
        -c core.checkStat=default -c core.trustctime=true -c core.ignoreStat=false \
        -c filter.unset.clean= -c filter.unset.smudge= -c filter.unset.process= \
        -c filter.unspecified.clean= -c filter.unspecified.smudge= -c filter.unspecified.process= \
        "$@"
}
unset GIT_GLOB_PATHSPECS GIT_NOGLOB_PATHSPECS GIT_ICASE_PATHSPECS

# main: reads cut_path's two lines on stdin, then reports with that PATH.
main() {
    IFS= read -r cut || cut=
    IFS= read -r rc || rc=
    if [ "$rc" != rc=0 ]; then
        case "$cut" in rc=* | '') cut="diagram-repo: $NO_PATH" ;; esac
        printf '%s\n' "$cut"
        exit 1
    fi
    case "$cut" in
        /*) ;;
        *) refuse "$NO_PATH" ;;
    esac
    PATH=$cut
    export PATH
    command -v git >/dev/null 2>&1 || refuse "git not found; the source links can't be pinned without it."

    inside=$(git_ rev-parse --is-inside-work-tree 2>/dev/null) || inside=
    if [ "$inside" != true ]; then
        [ "$mode" != identity ] && refuse "no commit to pin citations to; write no sources."
        printf '%s\n' outside-git
        exit 0
    fi
    root=$(git_ rev-parse --show-toplevel) || refuse "git could not read this repository."
    case "$root" in
        '' | *[[:cntrl:]]*) refuse "the repository's path holds a control character; refused." ;;
    esac
    head=$(git_ rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null) || head=
    origin=$(git_ remote get-url origin 2>/dev/null) || origin=
    # Only the forms Archify can pin source links to (its
    # parseRepositoryRemote) are printed. Any other origin is "unsupported"
    # and never printed, so a credential in it can't reach the conversation;
    # Archify refuses a query, a fragment or whitespace anyway.
    case "$origin" in
        '') ;;
        *[[:cntrl:][:space:]?#]*) origin=unsupported ;;
        [Hh][Tt][Tt][Pp]://* | [Hh][Tt][Tt][Pp][Ss]://*)
            # The user name, password or token before the last "@" of the
            # authority (Archify matches the origin without them).
            scheme=${origin%%://*}
            rest=${origin#*://}
            authority=${rest%%/*}
            path=${rest#"$authority"}
            authority=${authority##*@}
            if [ -n "$authority" ] && [ -n "$path" ]; then
                origin="$scheme://$authority$path"
            else
                origin=unsupported
            fi
            ;;
        [Ss][Ss][Hh]://git@*)
            rest=${origin#*://git@}
            case "${rest%%/*}" in '' | *@*) origin=unsupported ;; esac
            ;;
        git@*:*)
            host=${origin#git@}
            case "${host%%:*}" in '' | *@* | */*) origin=unsupported ;; esac
            ;;
        *) origin=unsupported ;;
    esac

    if [ "$mode" = check ]; then
        check_paths
        exit
    fi
    if [ "$mode" = recheck ]; then
        recheck
        exit
    fi

    printf 'root %s\n' "$root"
    printf 'head %s\n' "${head:-none}"
    printf 'origin %s\n' "${origin:-none}"
    if [ -z "$head" ]; then
        printf 'edits 0\n'
        exit 0
    fi
    gather
    if [ -n "$unsafe" ]; then
        printf 'unpinned %s\nstate unpinned\n' "$unsafe"
        exit 0
    fi
    printf 'state %s\n' "$state"
    # The first 20 changed files, then the count of all of them: one pass
    # that streams, with the count printed last and split off here.
    res=$(
        printf '%s\n' "$recs" | {
            n=0
            while IFS= read -r l; do
                case "$l" in
                    "T "*)
                        n=$((n + 1))
                        [ "$n" -le 20 ] && printf 'edit %s\n' "${l#T }"
                        ;;
                esac
            done
            printf 'COUNT %s\n' "$n"
        }
    )
    n=${res##*COUNT }
    printf 'edits %s\n' "$n"
    printf '%s' "${res%COUNT *}"
    [ "$n" -gt 20 ] && printf 'edit-more %s\n' "$((n - 20))"
    exit 0
}

NL='
'
TAB=$(printf '\t')

# rec_path <porcelain v2 line>: "T <path>" for a changed tracked file (an
# ordinary or unmerged entry), "U <path>" for an untracked one.
rec_path() {
    case "$1" in
        "1 "*)
            _p=${1#1 }
            _i=0
            while [ "$_i" -lt 7 ]; do _p=${_p#* }; _i=$((_i + 1)); done
            printf 'T %s\n' "$_p"
            ;;
        "u "*)
            _p=${1#u }
            _i=0
            while [ "$_i" -lt 9 ]; do _p=${_p#* }; _i=$((_i + 1)); done
            printf 'T %s\n' "$_p"
            ;;
        "? "*) printf 'U %s\n' "${1#\? }" ;;
    esac
}

# gather: decides whether git's own status can be run safely and, if so,
# runs it. Sets unsafe (empty, or why not), recs (one "T <path>" or
# "U <path>" line per path git lists) and state (its fingerprint).
gather() {
    unsafe=
    recs=
    state=
    tracked=$(git_ -C "$root" -c core.quotePath=false ls-files -v 2>/dev/null) || { unsafe=status; return; }
    others=$(git_ -C "$root" -c core.quotePath=false ls-files --others --exclude-standard 2>/dev/null) || { unsafe=status; return; }
    # A name git must quote (a control character, a quote, a backslash)
    # can't be matched back to a path with certainty.
    case "$tracked$NL" in
        ?\ \"* | *"$NL"?\ \"*) unsafe=names; return ;;
    esac
    case "$NL$others" in
        *"$NL"\"*) unsafe=names; return ;;
    esac
    # Assume-unchanged (a lowercase tag) hides edits from git; so does
    # skip-worktree on a file that is on disk. A skip-worktree file that is
    # absent (a sparse checkout) is unchanged.
    case "$NL$tracked" in
        *"$NL"[[:lower:]]\ *) unsafe=index-flags; return ;;
    esac
    case "$NL$tracked" in
        *"${NL}S "*)
            _hide=$(
                printf '%s\n' "$tracked" | while IFS= read -r l; do
                    case "$l" in
                        "S "*)
                            if [ -e "$root/${l#S }" ] || [ -L "$root/${l#S }" ]; then
                                printf x
                                break
                            fi
                            ;;
                    esac
                done
            )
            [ -z "$_hide" ] || { unsafe=index-flags; return; }
            ;;
    esac
    # No path may carry a filter attribute: a filter is a command git would
    # run. check-attr reads the attributes and runs nothing.
    _attrs=$(
        {
            [ -z "$tracked" ] || printf '%s\n' "$tracked" | while IFS= read -r l; do printf '%s\n' "${l#??}"; done
            [ -z "$others" ] || printf '%s\n' "$others"
        } | git_ -C "$root" check-attr filter --stdin 2>/dev/null
    ) || { unsafe=status; return; }
    _filtered=$(
        printf '%s\n' "$_attrs" | while IFS= read -r l; do
            case "$l" in
                '' | *": filter: unspecified" | *": filter: unset") ;;
                *)
                    printf x
                    break
                    ;;
            esac
        done
    )
    [ -z "$_filtered" ] || { unsafe=filters; return; }
    # check-attr prints a driver literally named "unset" or "unspecified"
    # the same as no filter, so any driver configured under those two names
    # is refused (reading config runs nothing; git_ also empties their
    # commands, so this is the second layer and reads without git_'s overrides).
    if GIT_OPTIONAL_LOCKS=0 git --no-replace-objects -C "$root" config --name-only --get-regexp '^filter\.(unset|unspecified)\.' >/dev/null 2>&1; then
        unsafe=filters
        return
    fi
    _st=$(git_ -C "$root" -c core.quotePath=false status --porcelain=v2 --untracked-files=all \
        --no-renames --ignore-submodules=all 2>/dev/null) || { unsafe=status; return; }
    # The state covers tracked changes only: an untracked file (the
    # Command's own scratch folder, say) can't change a pinned citation.
    state=$(printf '%s\n' "$_st" | while IFS= read -r l; do
        case "$l" in "1 "* | "u "*) printf '%s\n' "$l" ;; esac
    done | git_ hash-object --stdin 2>/dev/null) || { unsafe=status; return; }
    recs=$(printf '%s\n' "$_st" | while IFS= read -r l; do rec_path "$l"; done)
}

# recheck: the changed set is what identity printed and HEAD hasn't moved.
recheck() {
    again="the repository changed since its identity was read; start the Command again."
    [ "$head" = "$frozen" ] || refuse "$again"
    gather
    if [ -n "$unsafe" ]; then
        [ "$want_state" = unpinned ] || refuse "$again"
        exit 0
    fi
    [ "$state" = "$want_state" ] || refuse "$again"
    exit 0
}

# on_link <path>: true when the path, or a directory on its way below
# $root, is a symlink in the work tree.
on_link() {
    _rest=$1
    _at=$root
    while [ -n "$_rest" ]; do
        _part=${_rest%%/*}
        if [ "$_part" = "$_rest" ]; then _rest=; else _rest=${_rest#*/}; fi
        [ -n "$_part" ] || continue
        _at=$_at/$_part
        [ -L "$_at" ] && return 0
    done
    return 1
}

# check_paths: --check's verdict for each path in $paths, against the
# frozen commit in $root, each path on its own.
check_paths() {
    [ -n "$head" ] || refuse "no commit to pin citations to; write no sources."
    [ "$head" = "$frozen" ] || refuse "HEAD moved since the repository's identity was read; start the Command again."
    gather
    if [ -n "$unsafe" ]; then
        printf 'unpinned %s\n' "$unsafe"
        return 1
    fi
    all=0
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        while :; do
            case "$p" in ./*) p=${p#./} ;; *) break ;; esac
        done
        case "$p" in
            *[[:cntrl:]]*)
                printf '[outside] %s\n' '(a path with control characters)'
                all=1
                continue
                ;;
            '' | /* | .. | ../* | */.. | */../*)
                printf '[outside] %s\n' "$p"
                all=1
                continue
                ;;
        esac
        # The commit's entry, from its tree: a regular file's mode, "blob",
        # its ID. Names unquoted, so a non-ASCII name can match; one holding
        # a quote or a backslash is still quoted, and reads as absent (a
        # tab, a control character, is refused above as outside).
        if ! entry=$(git_ -C "$root" -c core.quotePath=false ls-tree "$frozen" -- "$p" 2>/dev/null); then
            printf '[unknown] %s\n' "$p"
            all=1
            continue
        fi
        case "$entry" in
            "100644 blob "*"$TAB$p" | "100755 blob "*"$TAB$p") ;;
            *)
                printf '[absent] %s\n' "$p"
                all=1
                continue
                ;;
        esac
        # No symlink anywhere on the way, and git doesn't list it as changed.
        case "$NL$recs$NL" in
            *"${NL}T $p$NL"* | *"${NL}U $p$NL"*)
                printf '[changed] %s\n' "$p"
                all=1
                continue
                ;;
        esac
        if on_link "$p"; then
            printf '[changed] %s\n' "$p"
            all=1
            continue
        fi
        printf '[pinned] %s\n' "$p"
    done <<EOF
$paths
EOF
    return "$all"
}

cut_path | main
