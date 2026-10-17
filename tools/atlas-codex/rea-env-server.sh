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
_REEPYSRC='@@REA-ENV-PY@@'
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
            d:*) _REEDIS=1 ;;
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
    _REEDIS=""
    _rea_config || return 1
    [ -n "$_REEANY" ] || {
        _rea_say "found no [mcp_servers.rea] entry in $_REEHOME/config.toml or in a trusted project's .codex/config.toml from the project root down to this directory, so REA's MCP server can't be checked; nothing checked. Run: rea setup"
        return 1
    }
    if [ -n "$_REEDIS" ]; then
        _rea_say "REA's MCP server is disabled in the Codex config (enabled = false in the [mcp_servers.rea] entry, merged as Codex layers it: $_REEFILE), so Codex does not start it and its environment can't be checked; nothing checked. Enable it in that config (enabled = true), then restart Codex."
        return 1
    fi
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
    if [ "${_ATLAS_ORIG_PATH+set}" != set ]; then
        _rea_say "can't tell what PATH REA's MCP server inherits (this process did not record the PATH it was started with), so its environment can't be checked; nothing checked."
        return 1
    fi
    case "$_ATLAS_ORIG_PATH" in
        *"$_REENL"* | *"$_REECR"*)
            _rea_say "the PATH REA's MCP server inherits holds a line break, so its environment can't be checked; nothing checked."
            return 1
            ;;
    esac
    _REEINH=$_ATLAS_ORIG_PATH
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
        # The server starts with the caller's original PATH, not the cut one this
        # process runs with (_ATLAS_ORIG_PATH, taken before any filtering).
        if [ "$_REEK" = PATH ]; then
            _REE="${_REE}PATH=$_REEINH$_REENL"
            continue
        fi
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
