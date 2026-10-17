#!/bin/sh
# tool-check.sh: the tool side of $rea-android (PRD Part III FR-038, FR-039,
# AC-079, AC-126, AC-127; R-023 in the pack notes).
#
#   tool-check.sh
#
# REA's MCP server, not this shell, runs apktool and the JADX MCP JAR (in
# java), and REA 6.4.0 resolves them from the server's own environment, the
# one Codex started it with (ApktoolConfiguration.js and
# JadxConfiguration.js): REA_APKTOOL_COMMAND (absolute) or else apktool on
# the server's PATH; REA_JADX_MCP_JAR (absolute); java as
# $JAVA_HOME/bin/java or else on that PATH (an apktool launcher script runs
# java on that PATH either way). So this script reads that
# environment from Codex's configuration of REA's MCP server (the
# [mcp_servers.rea] entry of the closest .codex/config.toml, else CODEX_HOME's;
# no process id is read) and applies FR-038's environment rule to
# it with the ATLAS-REA-ENV block below, which builds on the runner's own
# boundary code (the ATLAS-BOUNDARY block):
#   - no variable that loads code (JAVA_TOOL_OPTIONS, BASH_ENV, ...) may be
#     set to anything but empty, whatever its value;
#   - no variable but PWD, OLDPWD, CLAUDE_PROJECT_DIR and _ may name a path
#     inside FR-031's untrusted area or the area around the server's own
#     working directory, by its whole value or an entry between ":" (an
#     empty or relative PATH entry always fails: it resolves from whatever
#     directory runs the lookup); JAVA_HOME, REA_APKTOOL_COMMAND and
#     REA_JADX_MCP_JAR included;
#   - the server's PATH holds absolute entries only, each other one named,
#     so the lookup below and REA's search the same directories.
# Any of these prints a refusal naming the variable, never its value, and
# exits 1, so the Command stops before any REA call. It fails closed the
# same way when the environment can't be read with certainty: no rea entry
# in Codex's config.toml, an entry that can't be read or does not run "rea
# mcp", a relative CODEX_HOME, a cwd that can't be entered, or a name set twice.
#
# Then one line per tool: "[ok] java" or "[missing] java ..." (the Java REA
# will select must exist, be an executable regular file and lie outside the
# area, resolved), "[ok] jadx" or "[missing] jadx ...", then "[ok] apktool"
# or "[missing] apktool ...", naming what REA reads, with no install
# command. An apktool or java found on the PATH that is a symlink into the
# area is refused like the variables. It only reads files and /proc: no
# tool, adb or rea runs. Its own commands (tr, readlink)
# come from the Graphify runner's --path, the agent's PATH cut to its
# entries outside the area (FR-030); a runner refusal is printed as printed.
#
# Exit 0 when java and both tools are present and nothing is refused; 1
# otherwise; 2 on an argument.

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
# one around the server's own working directory, and its PATH must hold
# absolute entries only (_rea_path_abs). This block is
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
#   _rea_env_server  the environment of REA's MCP server as Codex's
#                    configuration starts it (the [mcp_servers.rea] entry
#                    of the closest .codex/config.toml, else CODEX_HOME's;
#                    no process id is read), in _REE, its working directory
#                    in _REECWD, and the area around that directory, by
#                    its physical name and by the snapshot's PWD when
#                    that names it, in _REESP and _REESL. It prints why
#                    and returns 1
#                    when it cannot be read with certainty: no entry, an
#                    file tomllib can't parse, an entry in a form the reader
#                    doesn't map or that does not run "rea mcp", a project
#                    entry whose trust can't be confirmed, no Python 3.11 or
#                    later, a relative CODEX_HOME, a cwd that can't be
#                    entered, a value holding a line break.
# _rea_env_scan then checks _REE, as the reader just before it left it, and
# prints one refusal line per variable, naming it and never its value; it
# returns 1 on a refusal and, with the reason, on a name set twice or, for
# this process's own environment, a line that is not NAME=value (a value
# holding a line break). It also checks the Java executable a REA call in
# that environment can probe, naming JAVA_HOME or PATH. _rea_java checks
# that Java exists, where REA needs one. Nothing here runs a tool apart
# from env, tr and readlink, and, to read Codex's config.toml, a Python 3.11 or
# later (python3 -I), from the cut PATH.
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
# Codex's discovery of REA's MCP server (T053 rounds 5 to 7). The Claude kit finds
# the server as a child of its agent's process and reads that process's
# environment from /proc; a Codex session has no such agent id, and an
# inherited one would name another agent's server. Here the snapshot comes from the configuration Codex starts
# the server from: the [mcp_servers.rea] entry of $CODEX_HOME/config.toml
# (default ~/.codex), layered under the .codex/config.toml of each directory
# from the project root down to this one, for a project the user's config marks
# trusted. Its command and args must run "rea mcp", its cwd is the server's
# working directory (default: this one), and its environment is what Codex
# gives a stdio server: the variables of its default list and the entry's
# env_vars, taken from this process's own environment (already checked), then
# the entry's env table over them.
#
# No shell reads the TOML. A Python 3.11 or later, found on the PATH the caller
# already cut to entries outside the untrusted area (and checked again by name,
# resolved directory and symlink step), runs as `python3 -I -c` over the
# source below: tomllib parses the files, the project's trust comes from the
# parsed [projects] table, and the layers are merged as Codex merges them. It
# prints one record per line (c: f: a: e: v: w: x:), which the loop below reads
# with `read`; nothing it prints is evaluated. A file that does not parse, an
# entry in a form it does not map, a project entry whose trust cannot be
# confirmed and a missing Python 3.11 each fail closed with a line that names
# the file. An unsupported form is never taken for an absent entry.
# _rea_isrea_script <path>: REA's entry script by name (bin "rea" or
# "rea-agents", or scripts/rea.mjs in the package).
_rea_isrea_script() {
    case "${1##*/}" in
        rea | rea-agents) return 0 ;;
        rea.mjs) case "$1" in /*/scripts/rea.mjs) return 0 ;; esac ;;
    esac
    return 1
}
# _rea_cfg_isrea: command and args are one of the registrations rea-agents
# 6.4.0 writes (SetupHost.js, ClientRegistrationIdentity.js), each checked by
# its exact arguments:
#   rea mcp | rea-agents mcp | <abs>/rea mcp | <abs>/scripts/rea.mjs mcp
#   <abs>/node <abs>/rea|rea-agents|scripts/rea.mjs mcp
#   npx -y rea-agents[@latest|@6.4.0] mcp
_rea_cfg_isrea() {
    _REEPIN=6.4.0
    _REEJ=${_REEARGS%"$_REENL"}
    _REEAN=0
    _REET=$_REEARGS
    while [ -n "$_REET" ]; do
        _REET=${_REET#*"$_REENL"}
        _REEAN=$((_REEAN + 1))
    done
    _REEA1=${_REEJ%%"$_REENL"*}
    _REEA2=""
    _REEA3=""
    if [ "$_REEAN" -ge 2 ]; then
        _REET=${_REEJ#*"$_REENL"}
        _REEA2=${_REET%%"$_REENL"*}
    fi
    if [ "$_REEAN" -ge 3 ]; then
        _REET=${_REEJ#*"$_REENL"}
        _REET=${_REET#*"$_REENL"}
        _REEA3=${_REET%%"$_REENL"*}
    fi
    case "$_REEAN:$_REEC" in
        1:rea | 1:rea-agents)
            [ "$_REEA1" = mcp ] && return 0
            ;;
        1:/*)
            [ "$_REEA1" = mcp ] && _rea_isrea_script "$_REEC" && return 0
            ;;
        2:/*)
            [ "${_REEC##*/}" = node ] && [ "$_REEA2" = mcp ] && case "$_REEA1" in /*) _rea_isrea_script "$_REEA1" && return 0 ;; esac
            ;;
        3:npx)
            [ "$_REEA1" = -y ] && [ "$_REEA3" = mcp ] || return 1
            case "$_REEA2" in
                rea-agents | rea-agents@latest | "rea-agents@$_REEPIN") return 0 ;;
            esac
            ;;
    esac
    return 1
}
# _rea_python: a Python 3.11 or later outside the untrusted area, in _REEPY.
# Each candidate is an absolute entry of the (cut) PATH, refused when it lies
# inside the repository by name, resolved directory or symlink step, and must
# run isolated (-I -S, from /) with tomllib. Returns 1 when none does.
_rea_python() {
    _REEPY=""
    _REEPF=""
    case $- in *f*) _REEPF=1 ;; esac
    _REEPS=$IFS
    IFS=:
    set -f
    for _REEPD in $PATH; do
        case "$_REEPD" in /*) ;; *) continue ;; esac
        for _REEPN in python3 python3.14 python3.13 python3.12 python3.11; do
            _REEPC="$_REEPD/$_REEPN"
            [ -f "$_REEPC" ] && [ -x "$_REEPC" ] || continue
            _inside_path "$_REEPC" && continue
            # From /, with the version managers' installs off: a shim (asdf,
            # pyenv, mise) picks its interpreter from files in the working
            # directory, which here is the repository's.
            if (cd / && MISE_AUTO_INSTALL=0 MISE_NOT_FOUND_AUTO_INSTALL=0 "$_REEPC" -I -S -c 'import sys, tomllib
sys.exit(0 if sys.version_info >= (3, 11) and sys.flags.isolated else 1)') >/dev/null 2>&1; then
                _REEPY=$_REEPC
                break 2
            fi
        done
    done
    IFS=$_REEPS
    [ -n "$_REEPF" ] || set +f
    [ -n "$_REEPY" ]
}
# The reader, run by _rea_config: tools/atlas-codex/rea-env-server.py, spliced in
# by the converter (it holds no single quote).
_REEPYSRC='# The Codex configuration of the REA MCP server, read with tomllib (T053 round 7).
# Kit-authored for the Codex mirror, not derived. tools/migrate-atlas.mjs splices
# this file into rea-env-server.sh, which runs it as `python3 -I -c <source>
# <CODEX_HOME> <physical cwd> <logical cwd>` with a trusted Python 3.11 or later.
# That source sits in a shell single-quoted string, so it holds no single quote.
#
# It reads the user config.toml and each project .codex/config.toml, decides
# project trust from the parsed [projects] table, merges the [mcp_servers.rea]
# entry as Codex layers it (per key, the later layer wins; args and env_vars are
# replaced whole; env is merged name by name) and prints the result as one record
# per line, never as shell text:
#   ok            first line of a result
#   f:<path>      a config file that holds the entry (one per layer)
#   c:<command>   h:   (args are set)   a:<arg> (one per argument)
#   v:<NAME>      an env_vars name      e:<NAME>=<value> an env pair
#   w:<cwd>       x:<path of the file that set it>
# On anything it cannot read with certainty it prints one `refuse:<reason>` line
# and exits 1. An unsupported form is never taken for an absent one.
import os
import re
import stat
import sys
import tomllib

LIMIT = 1048576
NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*\Z")


class Refuse(Exception):
    pass


def shown(text):
    return "".join("?" if (c < " " or c == "\x7f") else c for c in str(text))


def read_toml(path):
    try:
        info = os.stat(path)
    except (FileNotFoundError, NotADirectoryError):
        return None
    except OSError as err:
        raise Refuse("%s can not be read (%s)" % (shown(path), shown(err.strerror)))
    if not stat.S_ISREG(info.st_mode):
        raise Refuse("%s is not a regular file" % shown(path))
    if info.st_size > LIMIT:
        raise Refuse("%s is too large to read (over %d bytes)" % (shown(path), LIMIT))
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        try:
            if not stat.S_ISREG(os.fstat(fd).st_mode):
                raise Refuse("%s is not a regular file" % shown(path))
            data = os.read(fd, LIMIT + 1)
        finally:
            os.close(fd)
    except OSError as err:
        raise Refuse("%s can not be read (%s)" % (shown(path), shown(err.strerror)))
    if len(data) > LIMIT:
        raise Refuse("%s is too large to read (over %d bytes)" % (shown(path), LIMIT))
    try:
        return tomllib.loads(data.decode("utf-8"))
    except (ValueError, RecursionError) as err:
        raise Refuse("%s is not valid TOML (%s)" % (shown(path), shown(err)))


def text_of(value, what, path):
    if not isinstance(value, str):
        raise Refuse("the [mcp_servers.rea] entry in %s has %s that is not a string" % (shown(path), what))
    if "\n" in value or "\r" in value or "\x00" in value:
        raise Refuse("the [mcp_servers.rea] entry in %s has %s holding a line break or a NUL" % (shown(path), what))
    return value


def names_of(value, what, path):
    if not isinstance(value, list):
        raise Refuse("the [mcp_servers.rea] entry in %s has %s that is not an array of strings" % (shown(path), what))
    return [text_of(item, what, path) for item in value]


def entry_of(doc, path):
    """The [mcp_servers.rea] entry of one parsed file as a dict of mapped keys, or None when it has none."""
    if "mcp_servers" not in doc:
        return None
    servers = doc["mcp_servers"]
    if not isinstance(servers, dict):
        raise Refuse("%s sets mcp_servers in a form this check cannot map to [mcp_servers.rea] (it is not a table)" % shown(path))
    if "rea" not in servers:
        return None
    raw = servers["rea"]
    if not isinstance(raw, dict):
        raise Refuse("the [mcp_servers.rea] entry in %s is in a form this check cannot map (it is not a table)" % shown(path))
    entry = {}
    if "command" in raw:
        entry["command"] = text_of(raw["command"], "a command", path)
    if "args" in raw:
        entry["args"] = names_of(raw["args"], "args", path)
    if "cwd" in raw:
        entry["cwd"] = text_of(raw["cwd"], "a cwd", path)
    if "env_vars" in raw:
        entry["env_vars"] = names_of(raw["env_vars"], "env_vars", path)
        for name in entry["env_vars"]:
            if not NAME.match(name):
                raise Refuse("the [mcp_servers.rea] entry in %s has an env_vars name this check cannot take" % shown(path))
    if "env" in raw:
        table = raw["env"]
        if not isinstance(table, dict):
            raise Refuse("the [mcp_servers.rea] entry in %s has an env that is not a table of strings" % shown(path))
        env = {}
        for name, value in table.items():
            if not NAME.match(name):
                raise Refuse("the [mcp_servers.rea] entry in %s has an env name this check cannot take (letters, digits and underscores only)" % shown(path))
            env[name] = text_of(value, "the env value of " + name, path)
        entry["env"] = env
    return entry


def marker_root(start, markers):
    here = start
    while True:
        for marker in markers:
            if os.path.lexists(os.path.join(here, marker)):
                return here
        if here == "/":
            return start
        here = os.path.dirname(here) or "/"


def main_worktree(root):
    """The main checkout of a linked worktree rooted at root, or None."""
    link = os.path.join(root, ".git")
    if not os.path.isfile(link):
        return None
    try:
        with open(link, "rb") as handle:
            first = handle.read(4096).decode("utf-8", "replace").splitlines()[0]
        if not first.startswith("gitdir:"):
            return None
        gitdir = first[len("gitdir:"):].strip()
        gitdir = os.path.normpath(os.path.join(root, gitdir))
        if not os.path.isfile(os.path.join(gitdir, "commondir")):
            return None
        with open(os.path.join(gitdir, "commondir"), "rb") as handle:
            common = handle.read(4096).decode("utf-8", "replace").strip()
        common = os.path.normpath(os.path.join(gitdir, common))
    except (OSError, IndexError):
        return None
    return os.path.dirname(common) if os.path.basename(common) == ".git" else None


def trust_of(user, keys):
    """(yes, no, unmarked or bad, with why) for the project, from the parsed user config."""
    projects = user.get("projects") if user else None
    if projects is None:
        return "unmarked", "no [projects] table"
    if not isinstance(projects, dict):
        return "bad", "[projects] is not a table"
    seen = set()
    for key, value in projects.items():
        if key.rstrip("/") not in keys:
            continue
        if not isinstance(value, dict):
            return "bad", "the [projects] entry for " + shown(key) + " is not a table"
        level = value.get("trust_level")
        if level is None:
            continue
        if level == "trusted":
            seen.add("yes")
        elif level == "untrusted":
            seen.add("no")
        else:
            return "bad", "the trust_level of " + shown(key) + " is not trusted or untrusted"
    if seen == {"yes"}:
        return "yes", ""
    if seen == {"no"}:
        return "no", ""
    if seen:
        return "bad", "the [projects] entries for this directory, its project root and its main checkout disagree"
    return "unmarked", "no [projects] entry for this directory or its project root marks it"


def run(home, cwd, logical):
    for given in (home, cwd):
        if re.search("[\\x00-\\x1f\\x7f]", given):
            raise Refuse("%s holds a control character, so the records this reader prints could be forged" % shown(given))
    user_path = os.path.join(home, "config.toml")
    user = read_toml(user_path)
    layers = []
    if user is not None:
        entry = entry_of(user, user_path)
        if entry is not None:
            layers.append((user_path, entry))
    markers = [".git"]
    if user is not None and "project_root_markers" in user:
        markers = user["project_root_markers"]
        if not isinstance(markers, list) or not all(isinstance(m, str) and m and "/" not in m for m in markers):
            raise Refuse("project_root_markers in %s is not an array of plain names (no empty name, no slash)" % shown(user_path))
    root = marker_root(cwd, markers)
    keys = {cwd.rstrip("/") or "/", root.rstrip("/") or "/"}
    if logical.startswith("/"):
        try:
            if os.path.samefile(logical, cwd):
                keys.add(logical.rstrip("/") or "/")
        except OSError:
            pass
    main = main_worktree(root)
    if main:
        keys.add(main.rstrip("/") or "/")
    state, why = trust_of(user, keys)
    dirs = []
    here = cwd
    while True:
        dirs.append(here)
        if here == root or here == "/":
            break
        here = os.path.dirname(here) or "/"
    for directory in reversed(dirs):
        path = os.path.join(directory, ".codex", "config.toml")
        try:
            if os.path.samefile(path, user_path):
                continue
        except OSError:
            pass
        if state == "no":
            continue
        doc = read_toml(path)
        if doc is None:
            continue
        entry = entry_of(doc, path)
        if entry is None:
            continue
        if state != "yes":
            raise Refuse("%s sets an [mcp_servers.rea] entry, but whether Codex trusts the project %s cannot be confirmed from the [projects] tables of %s (%s); mark the project trusted or untrusted there" % (shown(path), shown(root), shown(user_path), why))
        layers.append((path, entry))
    out = ["ok"]
    merged = {}
    env = {}
    cwd_file = ""
    for path, entry in layers:
        out.append("f:" + path)
        for key in ("command", "args", "env_vars"):
            if key in entry:
                merged[key] = entry[key]
        if "cwd" in entry:
            merged["cwd"] = entry["cwd"]
            cwd_file = path
        env.update(entry.get("env", {}))
    if "command" in merged:
        out.append("c:" + merged["command"])
    if "args" in merged:
        out.append("h:")
        out.extend("a:" + item for item in merged["args"])
    out.extend("v:" + item for item in merged.get("env_vars", []))
    out.extend("e:%s=%s" % pair for pair in env.items())
    if "cwd" in merged:
        out.append("w:" + merged["cwd"])
        out.append("x:" + cwd_file)
    return out


def emit(lines, code):
    sys.stdout.buffer.write(("\n".join(lines) + "\n").encode("utf-8", "surrogateescape"))
    sys.stdout.buffer.flush()
    sys.exit(code)


def main():
    if len(sys.argv) != 4:
        emit(["refuse:the configuration reader was called wrongly"], 1)
    home, cwd, logical = sys.argv[1:4]
    try:
        emit(run(home, cwd, logical), 0)
    except Refuse as err:
        emit(["refuse:" + str(err)], 1)
    except Exception as err:
        emit(["refuse:the configuration reader failed (%s)" % shown(type(err).__name__)], 1)


main()'
# _rea_config: the merged [mcp_servers.rea] entry from Codex's configuration, in
# _REEMC (command), _REEMA (args, one per line, _REEMHAVE set), _REEMEV (env_vars
# names), _REEMEP (env, NAME=value per line), _REEMCW and _REEMCWFILE (cwd and
# the file that set it) and _REEFILE (the files that hold the entry, _REEANY
# set). Returns 1 after a named line when it cannot be read with certainty.
_rea_config() {
    if ! _rea_python; then
        _rea_say "found no Python 3.11 or later (with tomllib) outside $_REEROOT on PATH, so Codex's config.toml cannot be read and REA's MCP server can't be checked; nothing checked. Install Python 3.11 or later, or put it on PATH."
        return 1
    fi
    _REELOG=${PWD-}
    _REEOUT=$(cd / && MISE_AUTO_INSTALL=0 MISE_NOT_FOUND_AUTO_INSTALL=0 "$_REEPY" -I -S -c "$_REEPYSRC" "$_REEHOME" "$_REESS" "$_REELOG" 2>/dev/null)
    _REEPRC=$?
    _REEGOT=""
    while IFS= read -r _REEL; do
        case "$_REEL" in
            ok) _REEGOT=1 ;;
            refuse:*)
                _rea_say "${_REEL#refuse:}, so REA's MCP server can't be checked; nothing checked."
                return 1
                ;;
            f:*)
                _REEFILE="${_REEFILE:+$_REEFILE, }${_REEL#f:}"
                _REEANY=1
                ;;
            c:*) _REEMC=${_REEL#c:} ;;
            h:*) _REEMHAVE=1 ;;
            a:*) _REEMA="$_REEMA${_REEL#a:}$_REENL" ;;
            v:*) _REEMEV="$_REEMEV${_REEL#v:}$_REENL" ;;
            e:*) _REEMEP="$_REEMEP${_REEL#e:}$_REENL" ;;
            w:*) _REEMCW=${_REEL#w:} ;;
            x:*) _REEMCWFILE=${_REEL#x:} ;;
            *)
                _rea_say "the configuration reader printed a line this check does not know, so REA's MCP server can't be checked; nothing checked."
                return 1
                ;;
        esac
    done <<EOF
$_REEOUT
EOF
    if [ -z "$_REEGOT" ] || [ "$_REEPRC" -ne 0 ]; then
        _rea_say "the configuration reader (Python $_REEPY) did not finish, so Codex's config.toml cannot be read and REA's MCP server can't be checked; nothing checked."
        return 1
    fi
}
_rea_env_server() {
    _REEKIND=server
    _REEW="the environment of REA's MCP server"
    _REECWD=""
    _REELB=""
    _REENL='
'
    _REECR=$(printf '\r')
    _REETB=$(printf '\t')
    _REESS=$(pwd -P 2>/dev/null)
    case "$_REESS" in
        /*) ;;
        *)
            _rea_say "can't read this shell's working directory, so REA's MCP server can't be found; nothing checked."
            return 1
            ;;
    esac
    _REEHOME=${CODEX_HOME:-${HOME-}/.codex}
    case "$_REEHOME" in
        /*) ;;
        *)
            _rea_say "CODEX_HOME (or HOME) is not an absolute path, so Codex's config.toml can't be found and REA's MCP server can't be checked; nothing checked. Set it to an absolute path."
            return 1
            ;;
    esac
    _REEROOT=$_REESS
    _REEMC=""
    _REEMA=""
    _REEMHAVE=""
    _REEMEV=""
    _REEMEP=""
    _REEMCW=""
    _REEMCWFILE=""
    _REEFILE=""
    _REEANY=""
    _rea_config || return 1
    [ -n "$_REEANY" ] || {
        _rea_say "found no [mcp_servers.rea] entry in $_REEHOME/config.toml or in a trusted project's .codex/config.toml from the project root down to this directory, so REA's MCP server can't be checked; nothing checked. Run: rea setup"
        return 1
    }
    if [ -z "$_REEMC" ] || [ -z "$_REEMHAVE" ]; then
        _rea_say "the [mcp_servers.rea] entry ($_REEFILE, merged as Codex layers them) has no command or no args array, so REA's MCP server can't be checked; nothing checked."
        return 1
    fi
    _REEC=$_REEMC
    _REEARGS=$_REEMA
    _REEEV=$_REEMEV
    _REEEP=$_REEMEP
    _REECW=$_REEMCW
    _rea_cfg_isrea || {
        _rea_say "the [mcp_servers.rea] entry ($_REEFILE) does not run \"rea mcp\" in a form rea-agents $_REEPIN registers (command, then args), so it is not recognised as REA's MCP server; nothing checked."
        return 1
    }
    # What Codex gives a stdio server: its default variables and env_vars
    # from the session (this process's own environment, checked before this),
    # then the entry's env over them.
    _REEO=$(env 2>/dev/null) || {
        _rea_say "can't read this shell's environment (env failed), so what REA's MCP server would see can't be checked; nothing checked."
        return 1
    }
    _REE=""
    _REEDONE=$_REENL
    for _REEK in HOME LOGNAME PATH SHELL USER __CF_USER_TEXT_ENCODING LANG LC_ALL TERM TMPDIR TZ $_REEEV; do
        case "$_REENL$_REEEP" in
            *"$_REENL$_REEK="*) continue ;;
        esac
        # A name in both lists (env_vars may repeat a default variable) is
        # taken once.
        case "$_REEDONE" in
            *"$_REENL$_REEK$_REENL"*) continue ;;
        esac
        _REEDONE="$_REEDONE$_REEK$_REENL"
        while IFS= read -r _REEL; do
            case "$_REEL" in
                "$_REEK="*)
                    _REE="$_REE$_REEL$_REENL"
                    break
                    ;;
            esac
        done <<EOF
$_REEO
EOF
    done
    _REE="$_REE$_REEEP"
    _REE=${_REE%"$_REENL"}
    # The raw text without its separators, for the line-break check that follows.
    _REER=$(printf '%s' "$_REE" | tr -d '\n')
    if [ -n "$_REECW" ]; then
        case "$_REECW" in
            /*) ;;
            *)
                _rea_say "the cwd of the [mcp_servers.rea] entry in $_REEMCWFILE is not an absolute path, so the area around REA's MCP server is unknown; nothing checked. Write an absolute cwd."
                return 1
                ;;
        esac
        _REECWD=$(cd -P "$_REECW" 2>/dev/null && pwd -P) && [ -n "$_REECWD" ] || {
            _rea_say "the cwd of the [mcp_servers.rea] entry in $_REEMCWFILE can't be entered, so the area around REA's MCP server is unknown; nothing checked."
            return 1
        }
    else
        _REECWD=$_REESS
    fi
    _REEM="its config entry"
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
            _rea_say "the working directory of REA's MCP server (from its config entry) was removed or can't be read as a path, so the area around it is unknown; nothing checked. Restart Codex from the project directory."
            return 1
            ;;
    esac
    # The server's own area, from both names of its working directory: a
    # server started in another checkout must not run that checkout's tools.
    _atlas_slash "$_REECWD"
    _atlas_walk "$_ABS"
    _REESP=$_ABW
    # A server started in / or in $HOME (or an ancestor of it) has no
    # project around it: the walk never counts those as a repository, and
    # as an area they would make every path, or every path of the user's,
    # untrusted. The caller's area stands in.
    if _rea_no_project "$_REESP"; then
        _REESP=$_ABP
    fi
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
                    if _rea_no_project "$_REESL"; then
                        _REESL=$_ABP
                    fi
                fi
                ;;
        esac
    fi
}
# _rea_no_project <area>: true when the area is / or $HOME or one of its
# ancestors, by $HOME's name or its resolved name (_ABH, _ABHR).
_rea_no_project() {
    [ "$1" = / ] && return 0
    case "$_ABH" in "$1" | "$1"/*) [ -n "$_ABH" ] && return 0 ;; esac
    case "$_ABHR" in "$1" | "$1"/*) [ -n "$_ABHR" ] && return 0 ;; esac
    return 1
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
# a space is part of a path. Lists of directories are default-deny: a tool
# REA starts may search or load code from any of them (Qt's plugin
# directories, Lua's module paths), resolving a relative entry from its
# working directory. So PATH, every name ending in PATH or with PATH_
# (GST_PLUGIN_PATH_1_0), every *_DIRS name and GLib's module directories
# (GIO_EXTRA_MODULES, GIO_MODULE_DIR) get PATH's rule (_REESR): every
# entry is a path, bare words included, an empty one is ".", and each ":"
# entry, each ";" entry (Lua's lists) and each piece split at both is a
# candidate of its own. The Perl and Ruby library lists are
# refused above as code-loading; they are named here too so that leaving
# that list would still keep them strict. Only five names are relaxed
# (_REELS), each because nothing loads code from it: MANPATH (man pages),
# INFOPATH (info pages), NIX_PATH (Nix expressions, evaluated by nix, which
# REA never runs), TERMINFO_DIRS (compiled terminal descriptions, data)
# and WINDOWPATH (X virtual-terminal numbers, not directories, exported by
# xinit and display managers). There an empty entry is a default marker
# (manpath(5); terminfo(5): the system directory), not the working
# directory, and a name=path entry is checked by its path part.
# _rea_split_hit <value> <":" or ";">: true when an entry of the value
# between that separator names a path inside, by PATH's rule (_REESR set):
# an empty entry is ".".
_rea_split_hit() {
    _REESD="$1$2"
    while [ -n "$_REESD" ]; do
        case "$2" in
            :)
                _REEV=${_REESD%%:*}
                _REESD=${_REESD#*:}
                ;;
            *)
                _REEV=${_REESD%%;*}
                _REESD=${_REESD#*;}
                ;;
        esac
        [ -n "$_REEV" ] || _REEV=.
        _rea_cand_trim "$_REEV" && return 0
    done
    return 1
}
_rea_value_hit() {
    _REESR=""
    _rea_cand_trim "$1" && return 0
    _REELS=""
    case "$_REEN" in
        MANPATH | INFOPATH | NIX_PATH | TERMINFO_DIRS) _REELS=1 ;;
        # Only in its own shape, digits and ":", is WINDOWPATH relaxed.
        WINDOWPATH)
            case "$1" in
                *[!0-9:]*) _REESR=1 ;;
                *) _REELS=1 ;;
            esac
            ;;
        *PATH | *PATH_* | *_DIRS | PERL5LIB | PERLLIB | RUBYLIB | GIO_EXTRA_MODULES | GIO_MODULE_DIR) _REESR=1 ;;
    esac
    # Outside PATH an empty value sets no entries: unset, the default (the
    # XDG spec; VS Code's snap exports GTK_PATH_VSCODE_SNAP_ORIG= empty).
    if [ -z "$1" ] && [ "$_REEN" != PATH ]; then
        _REESR=""
        return 1
    fi
    _REEU="$1:"
    if [ -n "$_REESR" ]; then
        # Every splitting a tool might use adds candidates, none replaces
        # another: each ":" entry whole (a tool that splits only at ":" and
        # joins by text: in /proc/self/cwdx;/../cwd/bin the ".." pops
        # "cwdx;"), each ";" entry whole (Lua), then the pieces split at
        # both, below.
        if _rea_split_hit "$1" : || _rea_split_hit "$1" ';'; then
            _REESR=""
            return 0
        fi
        _REESC=$_REEU
        _REEU=""
        while :; do
            case "$_REESC" in
                *';'*)
                    _REEU="$_REEU${_REESC%%;*}:"
                    _REESC=${_REESC#*;}
                    ;;
                *)
                    _REEU="$_REEU$_REESC"
                    break
                    ;;
            esac
        done
    fi
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
# _rea_path_abs <value>: the server's PATH holds absolute entries only.
# REA resolves an empty, relative or bare entry from the server's working
# directory, and a helper from its own, so the two could find different
# tools there. Prints one refusal line per such entry, naming it (a PATH
# entry is a directory name, not a secret), and returns 1 on any.
_rea_path_abs() {
    _REEAB=0
    _REEU="$1:"
    while [ -n "$_REEU" ]; do
        _REEV=${_REEU%%:*}
        _REEU=${_REEU#*:}
        case "$_REEV" in
            /*) continue ;;
            '') _REEZ="an empty entry" ;;
            *)
                _atlas_shown "$_REEV"
                _REEZ="\"$_ABV\""
                ;;
        esac
        printf 'PATH in %s holds %s, which isn'"'"'t an absolute directory, so REA (from its own working directory) and this check could find different tools there; make every entry of PATH absolute in the env of REA'"'"'s MCP registration (or the environment Codex starts from), then restart Codex.\n' "$_REEW" "$_REEZ"
        _REEAB=1
    done
    [ "$_REEAB" = 0 ]
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
                PERL5OPT | PERL5LIB | PERLLIB | RUBYOPT | RUBYLIB | \
                QT_PLUGIN_PATH | QT_QPA_PLATFORM_PLUGIN_PATH)
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
        if [ "$_REEKIND" = server ] && [ "$_REEN" = PATH ] && ! _rea_path_abs "$_REEG"; then
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
# PATH (/bin:/usr/bin when unset), in both (_REEJN=PATH). Only absolute
# entries are searched: the scan refuses any other in the server's PATH,
# and in this process's own one resolves inside the area and is refused
# too. Returns 2, both empty, for
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
        case "$_REEV" in /*) ;; *) continue ;; esac
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

NO_PATH='the Graphify runner printed no PATH; run $atlas-doctor; nothing checked.'
FIX="REA's MCP server keeps the environment Codex started it with: change it there (or in the env of REA's MCP registration), restart Codex, then run \$rea-android again."

cut_path() {
    /bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path </dev/null
    printf 'rc=%s\n' "$?"
}

# outside <what> <path>: a refusal and exit 1 when the path, its resolved
# directory or a step of its symlinks lies inside this process's area or
# the server's own (the environment rule's union).
outside() {
    _rea_cand_hit "$2" || return 0
    _ABHIT=$_REEH
    printf 'tool-check: REA would run %s from here:\n' "$1"
    _atlas_shown "$2"
    _untrusted_line "$_ABV"
    printf '%s\n' "$FIX"
    exit 1
}

# lookup <name>: the first executable regular file of that name on the
# server's PATH (SPATH), in FOUND, as execvp finds it. The scan has refused
# any entry that isn't absolute; one that still is would be skipped.
lookup() {
    FOUND=""
    u="$SPATH:"
    while [ -n "$u" ]; do
        e=${u%%:*}
        u=${u#*:}
        case "$e" in /*) ;; *) continue ;; esac
        if [ -f "$e/$1" ] && [ -x "$e/$1" ]; then
            FOUND="$e/$1"
            break
        fi
    done
}

main() {
    IFS= read -r cut || cut=
    IFS= read -r rc || rc=
    if [ "$rc" != rc=0 ]; then
        case "$cut" in rc=* | '') cut="tool-check: $NO_PATH" ;; esac
        printf '%s\n' "$cut"
        exit 1
    fi
    case "$cut" in
        /*) ;;
        *)
            printf 'tool-check: %s\n' "$NO_PATH"
            exit 1
            ;;
    esac
    PATH=$cut
    export PATH
    _atlas_area_init || exit 1
    _REETAG=tool-check
    _rea_env_server || exit 1
    _rea_env_scan || exit 1

    # The server's PATH: unset, execvp searches /bin:/usr/bin.
    if _rea_env_get PATH; then
        SPATH=$_REEG
    else
        SPATH=/bin:/usr/bin
    fi

    status=0
    if jline=$(_rea_java); then
        jline='[ok] java'
    else
        status=1
    fi

    # apktool: REA_APKTOOL_COMMAND when it holds more than white space,
    # else apktool on PATH. REA (ApktoolConfiguration.js) runs the value
    # as it is and rejects one that isn't absolute, so a relative value is
    # missing here.
    apk=""
    apk_set=""
    if _rea_env_get REA_APKTOOL_COMMAND; then
        case "$_REEG" in *[![:space:]]*) apk_set=1 ;; esac
    fi
    if [ -n "$apk_set" ]; then
        case "$_REEG" in
            /*)
                if [ -f "$_REEG" ] && [ -x "$_REEG" ]; then
                    outside "apktool (REA_APKTOOL_COMMAND)" "$_REEG"
                    apk=$_REEG
                fi
                ;;
        esac
    else
        lookup apktool
        if [ -n "$FOUND" ]; then
            outside "apktool (on its PATH)" "$FOUND"
            apk=$FOUND
        fi
    fi

    jar=""
    if _rea_env_get REA_JADX_MCP_JAR; then
        case "$_REEG" in
            /*) [ -f "$_REEG" ] && [ -r "$_REEG" ] && jar=$_REEG ;;
        esac
    fi

    # An apktool launcher script runs java on PATH whatever JAVA_HOME says,
    # so a java there that links into the area counts too.
    lookup java
    [ -z "$FOUND" ] || outside "java (on its PATH)" "$FOUND"

    printf '%s\n' "$jline"
    if [ -n "$jar" ]; then
        printf '[ok] jadx\n'
    else
        printf '%s\n' "[missing] jadx: REA reads its JADX MCP JAR from REA_JADX_MCP_JAR, which must be the absolute path of a readable file. Set it in the env of REA's MCP registration (or where Codex starts), restart Codex, then run \$rea-android again."
        status=1
    fi
    if [ -n "$apk" ]; then
        printf '[ok] apktool\n'
    else
        printf '%s\n' "[missing] apktool: put apktool on the PATH of REA's MCP server, or set REA_APKTOOL_COMMAND there to its absolute path (in the env of REA's MCP registration, say), restart Codex, then run \$rea-android again."
        status=1
    fi
    exit "$status"
}

[ "$#" -eq 0 ] || {
    printf '%s\n' 'usage: tool-check.sh' >&2
    exit 2
}
cut_path | main
