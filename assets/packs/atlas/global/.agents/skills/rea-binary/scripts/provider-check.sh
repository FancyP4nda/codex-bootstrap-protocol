#!/bin/sh
# provider-check.sh: the provider side of $rea-binary (PRD Part III FR-039;
# AC-079).
#
#   provider-check.sh [--] [<provider>]
#     <provider> is ghidra or hopper: asks REA whether that provider is
#     ready (rea doctor --provider <provider>) and prints "[ok] provider
#     <provider>", or "[missing] provider <provider>" followed by REA's own
#     report, indented, which carries REA's fix text. With no provider it
#     asks for ghidra and then hopper, prints the first one that is ready
#     (nothing about the other) and passes, or prints both reports.
#     ida (any case) prints "IDA is not supported here." and asks REA
#     nothing: REA can host IDA, the kit does not support it.
#
# It runs only `rea doctor`, which changes nothing; it never runs the fix
# text it prints and never runs rea setup or rea update.
#
# FR-038's environment rule comes first (the ATLAS-REA-ENV block below,
# built on the ATLAS-BOUNDARY block): rea doctor here, and the MCP server
# for analysis, start Ghidra's Java and Hopper's launcher with the server's
# environment, and the rule holds this process's own environment to it too,
# so both must carry no code-loading variable
# (JAVA_TOOL_OPTIONS, BASH_ENV, ...) and no variable naming a path inside
# the repository (any name: JAVA_HOME, GHIDRA_INSTALL_DIR,
# HOPPER_LAUNCHER_PATH, ...; for the server, inside the area around its
# own working directory too), or the helper prints
# the refusal and stops before any rea call. The server's environment is
# read from /proc/<pid>/environ of the one "rea mcp" child of the agent
# (CLAUDE_PID, an ancestor of this script); when it can't be read with
# certainty the helper stops and says why. Readiness is the MCP server's:
# rea doctor runs in the server's working directory with exactly its
# validated environment (plus the version-manager guards below), so a
# provider configured only in REA's MCP registration reads ready and one
# configured only in this shell doesn't. For Ghidra it also needs a Java
# REA can use in that environment: none means Ghidra is not ready
# ("[missing] provider ghidra" with the [missing] java line below it); with
# no provider the helper goes on to Hopper.
#
# The repository is untrusted (R-023 in the pack notes): before it looks up
# rea or any tool, it takes PATH from the Graphify runner's --path, the
# agent's PATH cut to its absolute entries outside FR-031's untrusted area
# (FR-030's helper scripts). When the runner refuses instead, it prints the
# refusal as printed and stops.
#
# Exit 0 when a provider is ready; 1 when none is, on IDA, without a usable
# rea, on a runner refusal or on a refusal of the environment rule; 2 on a provider it does not know, before rea
# runs.

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
#   _rea_env_server  the environment of the one "rea mcp" child of the
#                    agent (CLAUDE_PID, an ancestor of this process), from
#                    /proc/<pid>/environ, in _REE, its working directory
#                    in _REECWD, and the area around that directory, by
#                    its physical name and by the snapshot's PWD when
#                    that names it, in _REESP and _REESL. It prints why
#                    and returns 1
#                    when it cannot be read with certainty: no /proc,
#                    CLAUDE_PID not an ancestor, no such server or more
#                    than one, an unreadable environment, a value holding
#                    a line break.
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
# _rea_ppid <pid>: its parent in _REEQ, from /proc/<pid>/stat (the name
# field, which may hold spaces or parentheses, ends at the last ") ").
_rea_ppid() {
    IFS= read -r _REES 2>/dev/null <"/proc/$1/stat" || return 1
    _REES=${_REES##*) }
    _REEQ=${_REES#* }
    _REEQ=${_REEQ%% *}
    case "$_REEQ" in '' | *[!0-9]*) return 1 ;; esac
}
# _rea_is_mcp <pid>: its command line is rea then mcp, run directly or by
# an interpreter (node .../bin/rea mcp, as REA's setup registers it). Any
# other form is not recognised, and the reader then fails closed.
_rea_is_mcp() {
    _REEC=$(tr '\000' '\n' 2>/dev/null <"/proc/$1/cmdline") || return 1
    _REE0=""
    _REE1=""
    _REE2=""
    {
        IFS= read -r _REE0
        IFS= read -r _REE1
        IFS= read -r _REE2
    } <<EOF
$_REEC
EOF
    [ "${_REE0##*/}:$_REE1" = rea:mcp ] && return 0
    [ "${_REE1##*/}:$_REE2" = rea:mcp ] && return 0
    return 1
}
_rea_env_server() {
    _REEKIND=server
    _REEW="the environment of REA's MCP server"
    _REECWD=""
    _REELB=""
    _REENL='
'
    [ -r /proc/self/stat ] || {
        _rea_say "this system has no /proc, so the environment REA's MCP server runs its tools with can't be read; nothing checked."
        return 1
    }
    _REEA=${CLAUDE_PID-}
    case "$_REEA" in
        '' | *[!0-9]*)
            _rea_say "CLAUDE_PID does not name the agent this runs under, so REA's MCP server can't be found; nothing checked. Run this from Codex."
            return 1
            ;;
    esac
    _REEP=$$
    while [ "$_REEP" != "$_REEA" ]; do
        if ! _rea_ppid "$_REEP" || [ "$_REEP" = 1 ] || [ "$_REEQ" = 0 ]; then
            _rea_say "CLAUDE_PID ($_REEA) is not the agent this runs under, so REA's MCP server can't be found; nothing checked. Run this from Codex."
            return 1
        fi
        _REEP=$_REEQ
    done
    _REEM=""
    for _REEF in /proc/[0-9]*/stat; do
        _REEP=${_REEF#/proc/}
        _REEP=${_REEP%/stat}
        _rea_ppid "$_REEP" || continue
        [ "$_REEQ" = "$_REEA" ] || continue
        _rea_is_mcp "$_REEP" || continue
        [ -z "$_REEM" ] || {
            _rea_say "found more than one REA MCP server started by this session, so which one REA's tools run under is unknown; nothing checked."
            return 1
        }
        _REEM=$_REEP
    done
    [ -n "$_REEM" ] || {
        _rea_say "found no REA MCP server started by this session (a \"rea mcp\" child of CLAUDE_PID $_REEA); run \$rea-doctor; nothing checked."
        return 1
    }
    _REER=$(tr -d '\000' 2>/dev/null <"/proc/$_REEM/environ") \
        && _REE=$(tr '\000' '\n' 2>/dev/null <"/proc/$_REEM/environ") \
        && _REECWD=$(readlink "/proc/$_REEM/cwd" 2>/dev/null) \
        && [ -n "$_REECWD" ] || {
        _rea_say "can't read the environment or working directory of REA's MCP server (process $_REEM); nothing checked."
        return 1
    }
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
            _rea_say "the working directory of REA's MCP server (process $_REEM) was removed or can't be read as a path, so the area around it is unknown; nothing checked. Restart Codex from the project directory."
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
# a space is part of a path. PATH (_REEN) is the one executable search
# path REA 6.4.0 and the tools it starts walk, so there every entry is a
# path (_REESR), bare words included, and an empty one is ".". Any other
# name ending in PATH is a list (MANPATH, INFOPATH, NIX_PATH): an empty
# entry is a default marker, not the working directory, and a name=path
# entry is checked by its path part too.
_rea_value_hit() {
    _REESR=""
    _rea_cand_trim "$1" && return 0
    _REELS=""
    case "$_REEN" in
        PATH) _REESR=1 ;;
        *PATH) _REELS=1 ;;
    esac
    _REEU="$1:"
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
                PERL5OPT | PERL5LIB | PERLLIB | RUBYOPT | RUBYLIB)
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

REA_LINES=200

NO_PATH='the Graphify runner printed no PATH; run $atlas-doctor; nothing run.'
# After a provider that isn't ready: REA's fix text can't say where its
# settings go, and readiness is the server's, not this shell's.
WHERE="provider-check: REA's MCP server judges this with its own configuration: set a provider's settings in the env of REA's MCP registration (or the environment Codex starts from), then restart Codex; a value set only in this shell doesn't count."

cut_path() {
    /bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path </dev/null
    printf 'rc=%s\n' "$?"
}

# srv_doctor <provider>: rea doctor for it, run as the MCP server would see
# the provider: in the server's working directory, with exactly the
# server's environment (env_gate validated both), so a provider configured
# only in REA's MCP registration reads ready and one configured only in this
# shell doesn't. REA_BIN is the rea found on the cut PATH; env too.
#
# The values reach REA through its environment only, never a command line
# (which other users and audit logs can read; the server's environment holds
# tokens): a clean /bin/sh reads them on descriptor 3 and exports each one
# whose name is a shell name (others are dropped: a POSIX shell can't
# export them), so a line that isn't NAME=value is never run or parsed as
# an option. The shell may add PWD, SHLVL or _ of its own. Then the guards,
# which win over the server's values: a version-manager shim must not
# install anything (it may still select a version from the working
# directory's config, as the server's own does), and a Python REA starts
# must not import modules from that directory.
srv_doctor() {
    cd "$SRVCWD" || {
        printf '%s\n' "provider-check: can't enter the working directory of REA's MCP server; nothing run."
        return 1
    }
    # The program is "$1", not "$0": in bash an exported BASH_ARGV0 sets $0.
    # BASH_* names are bash's own (the server's node reads none) and are
    # skipped; `command` keeps a readonly name (PPID, SHELLOPTS, BASHOPTS in
    # bash) from ending the shell, and that name is dropped.
    env -i /bin/sh -c '
        while IFS= read -r _atlas_l <&3; do
            _atlas_n=${_atlas_l%%=*}
            case "$_atlas_n" in "$_atlas_l" | "" | [!A-Za-z_]* | *[!A-Za-z0-9_]* | BASH_*) continue ;; esac
            command export "$_atlas_l" 2>/dev/null || continue
        done
        exec 3<&-
        unset _atlas_l _atlas_n
        MISE_AUTO_INSTALL=0
        MISE_NOT_FOUND_AUTO_INSTALL=0
        PYTHONSAFEPATH=1
        export MISE_AUTO_INSTALL MISE_NOT_FOUND_AUTO_INSTALL PYTHONSAFEPATH
        exec "$1" doctor --provider "$2" --filter-output healthy,scope_checks </dev/null
    ' provider-check "$REA_BIN" "$1" 3<<EOF
$SRVENV
EOF
}
# check_one <provider>: prints the result; returns rea's verdict.
check_one() {
    p=$1
    # Ghidra runs on Java, which REA starts from the MCP server's
    # environment (FR-038, Java present): none it can use means not ready.
    if [ "$p" = ghidra ] && [ -n "${SRVJ:-}" ]; then
        printf '[missing] provider ghidra\n'
        printf '%s\n' "$SRVJ" | while IFS= read -r l; do
            printf '  %s\n' "$l"
        done
        return 1
    fi
    if out=$(srv_doctor "$p" 2>&1); then
        printf '[ok] provider %s\n' "$p"
        return 0
    fi
    printf '[missing] provider %s\n' "$p"
    n=0
    printf '%s\n' "$out" | tr -d '\000-\010\013-\037\177' | while IFS= read -r l; do
        n=$((n + 1))
        if [ "$n" -gt "$REA_LINES" ]; then
            printf '  ... (output cut after %s lines)\n' "$REA_LINES"
            break
        fi
        printf '  %s\n' "$l"
    done
    return 1
}

# env_gate: FR-038's environment rule on both environments REA and its tools
# see, before any rea doctor: this process's own, then the MCP server's. It
# prints the refusal or the reason and returns 1.
env_gate() {
    { _rea_env_self && _rea_env_scan; } || return 1
    { _rea_env_server && _rea_env_scan; } || return 1
    # The validated server configuration srv_doctor runs REA with.
    SRVENV=$_REE
    SRVCWD=$_REECWD
    # The Java Ghidra would start, in the server's environment: its
    # [missing] java line in SRVJ, empty when there is a usable one.
    if SRVJ=$(_rea_java); then SRVJ=""; fi
}

main() {
    IFS= read -r cut || cut=
    IFS= read -r rc || rc=
    if [ "$rc" != rc=0 ]; then
        case "$cut" in rc=* | '') cut="provider-check: $NO_PATH" ;; esac
        printf '%s\n' "$cut"
        exit 1
    fi
    case "$cut" in
        /*) ;;
        *)
            printf 'provider-check: %s\n' "$NO_PATH"
            exit 1
            ;;
    esac
    PATH=$cut
    # A version-manager shim must not pick a version from the repository or
    # install one (the repository is untrusted).
    MISE_AUTO_INSTALL=0
    MISE_NOT_FOUND_AUTO_INSTALL=0
    export PATH MISE_AUTO_INSTALL MISE_NOT_FOUND_AUTO_INSTALL
    _atlas_area_init || exit 1
    _REETAG=provider-check

    REA_BIN=$(command -v rea 2>/dev/null)
    case "$REA_BIN" in
        /*) ;;
        *)
            printf '%s\n' 'provider-check: no usable rea on the PATH; run $rea-doctor.'
            exit 1
            ;;
    esac
    case "$provider" in
        ghidra | hopper)
            env_gate || exit 1
            check_one "$provider" && exit 0
            printf '%s\n' "$WHERE"
            exit 1
            ;;
        any)
            env_gate || exit 1
            # The first ready provider is the answer: the other one's
            # report is shown only when neither is ready.
            if g=$(check_one ghidra); then
                printf '%s\n' "$g"
                exit 0
            fi
            if h=$(check_one hopper); then
                printf '%s\n' "$h"
                exit 0
            fi
            printf '%s\n%s\n%s\n' "$g" "$h" "$WHERE"
            exit 1
            ;;
    esac
}

[ "${1:-}" = -- ] && shift
[ "$#" -le 1 ] || {
    printf '%s\n' 'usage: provider-check.sh [--] [ghidra|hopper]' >&2
    exit 2
}
case "${1-}" in
    '') [ "$#" -eq 0 ] && provider=any || { printf '%s\n' 'provider-check: give ghidra or hopper.' >&2; exit 2; } ;;
    ghidra | hopper) provider=$1 ;;
    ida | IDA | Ida | iDA | idA | IDa | iDa | ID[aA] | [iI][dD][aA])
        printf '%s\n' 'IDA is not supported here.'
        exit 1
        ;;
    *)
        printf '%s\n' 'provider-check: unknown provider; give ghidra or hopper.' >&2
        exit 2
        ;;
esac

cut_path | main
