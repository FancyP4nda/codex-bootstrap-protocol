#!/bin/sh
# atlas-archify.sh: the atlas pack's one wrapper for Archify (PRD Part III
# FR-030, FR-031; AC-074, AC-114, AC-120).
#
# Kit-authored, shipped with atlas-doctor beside the shared precondition
# script (pack_paths covers skills/atlas-doctor/), not under skills/archify/,
# which is vendored whole. Every Archify run a Command makes goes through
# it, and so does every run the vendored Archify skill makes once its
# recorded patch points it here (T046; FR-025):
#
#   /bin/sh "$HOME/.agents/skills/atlas-doctor/scripts/atlas-archify.sh" <operation> <arguments>
#
# What it does, in this order, stopping at the first refusal with one line
# on stdout (the caller shows it as printed) and a non-zero exit:
#   1. the cut: PATH cut to its absolute entries outside FR-031's untrusted
#      area (the ATLAS-BOUNDARY block below, byte-identical in the Graphify
#      runner and atlas-check.sh; /usr/bin:/bin when none is left, and the
#      system-directories line when the area holds /usr/bin or /bin),
#      before any external command runs;
#   2. the operation: one in TABLE below, or FR-030's unsupported-operation
#      line, naming it (brands capture, which fetches a URL, included; a
#      word with a control character isn't echoed), and nothing runs;
#   3. the options: every argument that starts with "-" must be one TABLE
#      lists for the operation, or it is refused, naming it and the
#      operation. Other arguments pass through unchanged;
#   4. node: the first node on PATH's absolute entries, as atlas-check.sh's
#      node-archify check finds it. One inside the untrusted area (by name,
#      resolved directory or any symlink step) gets FR-031's untrusted-area
#      line; none gets "Node not found". Its version is not checked here:
#      every Command that draws runs the node-archify precondition first;
#   5. the run: node runs Archify's entry point at the fixed path
#      <config dir>/skills/archify/bin/archify.mjs (never found through PATH
#      or the working directory, so a relative config directory is refused)
#      with the operation and its arguments,
#      ARCHIFY_UPDATE_CHECK_DISABLED=1, ARCHIFY_BRAND_CAPTURE_DISABLED=1 and
#      ARCHIFY_BROWSER_NETWORK_DISABLED=1 exported (FR-030 "Network" and
#      "The browser checks") and NODE_OPTIONS and NODE_PATH unset. A
#      missing entry point asks for a reinstall.
#
# It doesn't check where Archify writes: keeping output under .archify/
# stays a Command rule (FR-035). The Command-contract check skips this
# directory (FR-030); verification/atlas-tests/archify-wrapper.sh covers it.

# Builtins only (pwd, cd, case, printf, [, set, for, while) until PATH is
# fixed below.
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
_atlas_area_init || exit 1
# PATH: _AAABS keeps the absolute entries, _AAPATH those of them that lie
# outside the untrusted area, by name and resolved. node and everything it
# starts run from _AAPATH.
set -f
_AAABS=""
_AAPATH=""
_AAIFS="$IFS"
IFS=:
for _AAE in $PATH; do
    case "$_AAE" in /*) ;; *) continue ;; esac
    _AAABS="${_AAABS:+$_AAABS:}$_AAE"
    _AAR=$(cd -P "$_AAE" 2>/dev/null && pwd -P) || _AAR="$_AAE"
    _inside "$_AAE" || _inside "$_AAR" || _AAPATH="${_AAPATH:+$_AAPATH:}$_AAE"
done
IFS="$_AAIFS"
set +f
PATH="${_AAPATH:-/usr/bin:/bin}"
export PATH

_unsupported() {
    printf '%s\n' "Not available in the atlas pack: $1. The pack supports drawing and checking diagrams; to use $1, run upstream Archify by hand outside the kit (see \"Running Archify by hand\" in references/atlas-pack-notes.md in the agents directory (`~/.agents`))."
    exit 1
}

# ATLAS-TABLE-BEGIN
# The operations the wrapper runs (FR-030), the ones FR-035..FR-037 and
# FR-040 need to draw, repair and check a diagram, each with the options it
# may pass: Archify 3.1.0's COMMAND_USAGE (bin/archify.mjs) without --open,
# and brands for a name lookup only (brands capture is refused below). The
# Command-contract check reads the operation names from this block, and
# archify-wrapper.sh holds the options to COMMAND_USAGE.
_atlas_archify_options() {
    case "$1" in
        finalize) _AAO="--json --receipt --out-dir --quality --repo-root --candidate-sha256" ;;
        validate) _AAO="--json --layout-json --quality --repo-root" ;;
        check) _AAO="--json --require-provenance" ;;
        browser-check) _AAO="--json --summary --require-provenance --out-dir" ;;
        visual-check) _AAO="--json --summary --require-provenance --out-dir" ;;
        guide) _AAO="--json --lang" ;;
        brands) _AAO="--json" ;;
        *) return 1 ;;
    esac
}
# ATLAS-TABLE-END

case "${1:-}" in
    "" | -*) printf '%s\n' "atlas-archify.sh: name an operation."; exit 2 ;;
esac
_AAOP="$1"
shift
if ! _atlas_archify_options "$_AAOP"; then
    # Any other word gets the unsupported line; one holding a control
    # character is never echoed, so it can't drive the terminal.
    case "$_AAOP" in *[[:cntrl:]]*) _AAOP="(an operation with control characters)" ;; esac
    _unsupported "$_AAOP"
fi
# brands takes its first argument other than --json as "capture" to fetch
# a URL, as Archify 3.1.0 reads it.
if [ "$_AAOP" = brands ]; then
    for _AAA in "$@"; do
        [ "$_AAA" = --json ] && continue
        [ "$_AAA" = capture ] && _unsupported "brands capture"
        break
    done
fi

# _atlas_listed <argument>: true when TABLE lists it for the operation.
_atlas_listed() {
    set -f
    for _AAW in $_AAO; do
        if [ "$_AAW" = "$1" ]; then
            set +f
            return 0
        fi
    done
    set +f
    return 1
}
for _AAA in "$@"; do
    case "$_AAA" in
        -*)
            _atlas_listed "$_AAA" && continue
            case "$_AAA" in *[[:cntrl:]]*) _AAA="(an option with control characters)" ;; esac
            printf '%s\n' "atlas-archify.sh: $_AAOP does not take $_AAA; the atlas pack passes only the options its table lists."
            exit 1
            ;;
    esac
done

# node: the first one on the absolute entries, so one inside the area is
# refused, naming it, rather than silently skipped.
_AANODE=""
set -f
IFS=:
for _AAE in $_AAABS; do
    if [ -f "$_AAE/node" ] && [ -x "$_AAE/node" ]; then
        _AANODE="$_AAE/node"
        break
    fi
done
IFS="$_AAIFS"
set +f
if [ -z "$_AANODE" ]; then
    printf '%s\n' "Node not found. Run \$atlas-doctor for the fix line."
    exit 1
fi
if _inside_path "$_AANODE"; then
    _atlas_shown "$_AANODE"
    _untrusted_line "$_ABV"
    exit 1
fi

# The entry point is never found through the working directory: a
# relative config directory would resolve against it.
_AACFG="$HOME/.agents"
case "$_AACFG" in
    /*) ;;
    *)
        _atlas_shown "$_AACFG"
        printf '%s\n' "atlas-archify.sh: the agents directory, $_ABV, is not an absolute path; set HOME to an absolute path."
        exit 1
        ;;
esac
_AAENTRY="$_AACFG/skills/archify/bin/archify.mjs"
if [ ! -f "$_AAENTRY" ]; then
    _atlas_shown "$_AAENTRY"
    printf '%s\n' "Archify's entry point $_ABV is missing; reinstall the atlas pack (codex-bootstrap --global-only --pack atlas)."
    exit 1
fi

export ARCHIFY_UPDATE_CHECK_DISABLED=1
# Archify's object-brand fetch (FR-030 "Network"): Archify 3.1.0 ignores
# this until the recorded patch to renderers/shared/brand-marks.mjs (T046,
# AC-121) makes that function refuse before any lookup or connection.
export ARCHIFY_BRAND_CAPTURE_DISABLED=1
# The browser checks' page load (FR-030 "The browser checks", AC-124): the
# recorded patch to bin/visual-check.mjs starts Chrome off the network.
export ARCHIFY_BROWSER_NETWORK_DISABLED=1
unset NODE_OPTIONS NODE_PATH
exec "$_AANODE" "$_AAENTRY" "$_AAOP" "$@"
