# Codex's discovery of REA's MCP server (T053 round 5). The Claude kit finds
# the server as a child of its agent's process and reads that process's
# environment from /proc; a Codex session has no such agent id, and an
# inherited one would name another agent's server. Here the snapshot comes from the configuration Codex starts
# the server from: the [mcp_servers.rea] entry of the closest .codex/config.toml
# on the way up from this directory, else $CODEX_HOME/config.toml (default
# ~/.codex). Its command and args must run "rea mcp", its cwd is the server's
# working directory (default: this one), and its environment is what Codex
# gives a stdio server: the variables of its default list and the entry's
# env_vars, taken from this process's own environment (already checked), then
# the entry's env table over them. Only plain TOML is read: [mcp_servers.rea]
# and [mcp_servers.rea.env] tables, one-line strings without backslash
# escapes, one-line arrays and inline tables. Anything else, and a missing
# entry, fails closed with a line that names the file.
_rea_ltrim() {
    while :; do
        case "$_REETR" in
            ' '* | "$_REETB"*) _REETR=${_REETR#?} ;;
            *) break ;;
        esac
    done
}
# _rea_tstr <text>: the one-line quoted string at the start of text, in
# _REETV, the rest in _REETR. A basic string with a backslash is refused.
_rea_tstr() {
    _REETR=$1
    case "$_REETR" in
        \"*) _REETQ='"' ;;
        \'*) _REETQ="'" ;;
        *) return 1 ;;
    esac
    _REETR=${_REETR#?}
    _REETV=${_REETR%%"$_REETQ"*}
    [ "$_REETV" != "$_REETR" ] || return 1
    case "$_REETV" in
        *\\*) [ "$_REETQ" != '"' ] || return 1 ;;
    esac
    _REETR=${_REETR#"$_REETV"?}
}
# _rea_tend: nothing but a comment follows.
_rea_tend() {
    _rea_ltrim
    case "$_REETR" in '' | '#'*) return 0 ;; esac
    return 1
}
# _rea_tarr <text>: a one-line array of strings, one per line in _REETL.
_rea_tarr() {
    _REETR=${1#\[}
    _REETL=""
    while :; do
        _rea_ltrim
        case "$_REETR" in
            \]*)
                _REETR=${_REETR#?}
                break
                ;;
            ,*)
                _REETR=${_REETR#?}
                continue
                ;;
        esac
        _rea_tstr "$_REETR" || return 1
        _REETL="$_REETL$_REETV$_REENL"
    done
    _rea_tend
}
# _rea_tname <text>: the text without quotes and blanks, in _REEN (a table
# or key name as TOML's dotted form writes it).
_rea_tname() {
    _REEN=$1
    while :; do
        case "$_REEN" in
            *\"*) _REEN=${_REEN%%\"*}${_REEN#*\"} ;;
            *\'*) _REEN=${_REEN%%\'*}${_REEN#*\'} ;;
            *' '*) _REEN=${_REEN%%' '*}${_REEN#*' '} ;;
            *"$_REETB"*) _REEN=${_REEN%%"$_REETB"*}${_REEN#*"$_REETB"} ;;
            *) break ;;
        esac
    done
}
# _rea_tpair <name> <text>: NAME=value of a string value, appended to _REEEP.
_rea_tpair() {
    case "$1" in '' | *[!A-Za-z0-9_]* | [0-9]*) return 1 ;; esac
    _rea_tstr "$2" && _rea_tend || return 1
    _REEEP="$_REEEP$1=$_REETV$_REENL"
}
# _rea_ttab <text>: a one-line inline table of strings, appended to _REEEP.
_rea_ttab() {
    _REETR=${1#\{}
    while :; do
        _rea_ltrim
        case "$_REETR" in
            \}*)
                _REETR=${_REETR#?}
                break
                ;;
            ,*)
                _REETR=${_REETR#?}
                continue
                ;;
        esac
        _REETK=${_REETR%%[!A-Za-z0-9_-]*}
        if [ -n "$_REETK" ]; then
            _REETR=${_REETR#"$_REETK"}
        else
            _rea_tstr "$_REETR" || return 1
            _REETK=$_REETV
        fi
        _rea_ltrim
        case "$_REETR" in =*) _REETR=${_REETR#?} ;; *) return 1 ;; esac
        _rea_ltrim
        _rea_tstr "$_REETR" || return 1
        case "$_REETK" in '' | *[!A-Za-z0-9_]* | [0-9]*) return 1 ;; esac
        _REEEP="$_REEEP$_REETK=$_REETV$_REENL"
    done
    _rea_tend
}
# _rea_cfg_read <file>: the [mcp_servers.rea] entry of one config file.
# Returns 0 with the entry in _REEC (command), _REEARGS (one per line),
# _REEEV (env_vars names, one per line), _REEEP (env, NAME=value per line)
# and _REECW (cwd, empty when absent); 1 when the file has no such entry;
# 2 with the reason in _REEWHY.
_rea_cfg_read() {
    _REEWHY=""
    _REEFOUND=""
    _REEFORM=""
    _REEC=""
    _REEARGS=""
    _REEEV=""
    _REEEP=""
    _REECW=""
    _REEHAVE=""
    _REEBL=top
    [ -r "$1" ] || return 1
    while IFS= read -r _REEL || [ -n "$_REEL" ]; do
        _REEL=${_REEL%"$_REECR"}
        _REETR=$_REEL
        _rea_ltrim
        _REEL=$_REETR
        case "$_REEL" in
            '' | '#'*) continue ;;
            '[['*)
                _REEBL=other
                continue
                ;;
            '['*)
                _REEN=${_REEL#\[}
                _REEN=${_REEN%%\]*}
                _rea_tname "$_REEN"
                case "$_REEN" in
                    mcp_servers.rea)
                        if [ -n "$_REEFOUND" ]; then
                            _REEWHY="is set in two tables"
                            return 2
                        fi
                        _REEFOUND=1
                        _REEBL=main
                        ;;
                    mcp_servers.rea.env) _REEBL=env ;;
                    mcp_servers.rea.*)
                        _REEBL=other
                        _REEFORM=1
                        ;;
                    mcp_servers) _REEBL=servers ;;
                    *) _REEBL=other ;;
                esac
                continue
                ;;
        esac
        case "$_REEL" in *=*) ;; *) continue ;; esac
        _REEK=${_REEL%%=*}
        _REETR=${_REEL#*=}
        _rea_ltrim
        _REEV=$_REETR
        _rea_tname "$_REEK"
        _REEK=$_REEN
        case "$_REEBL" in
            top)
                case "$_REEK" in mcp_servers.rea | mcp_servers.rea.*) _REEFORM=1 ;; esac
                ;;
            servers)
                case "$_REEK" in rea | rea.*) _REEFORM=1 ;; esac
                ;;
            env)
                if ! _rea_tpair "$_REEK" "$_REEV"; then
                    _REEWHY="has an [mcp_servers.rea.env] line this check can't read (one NAME = \"value\" per line)"
                    return 2
                fi
                ;;
            main)
                case "$_REEK" in
                    command)
                        if [ -n "$_REEC" ] || ! { _rea_tstr "$_REEV" && _rea_tend; }; then
                            _REEWHY="has a command that is not set once as a one-line string without backslashes"
                            return 2
                        fi
                        _REEC=$_REETV
                        ;;
                    cwd)
                        if ! { _rea_tstr "$_REEV" && _rea_tend; }; then
                            _REEWHY="has a cwd that is not a one-line string without backslashes"
                            return 2
                        fi
                        _REECW=$_REETV
                        ;;
                    args)
                        if ! _rea_tarr "$_REEV"; then
                            _REEWHY="has args that are not a one-line array of strings"
                            return 2
                        fi
                        _REEARGS=$_REETL
                        _REEHAVE=1
                        ;;
                    env_vars)
                        # The names Codex passes on from the session. They
                        # only widen the snapshot with variables the session's
                        # own check covered, so a list spread over lines is
                        # left out rather than refused.
                        if _rea_tarr "$_REEV"; then
                            _REEEV=$_REETL
                        fi
                        ;;
                    env)
                        if ! _rea_ttab "$_REEV"; then
                            _REEWHY="has an env table that is not a one-line inline table of strings"
                            return 2
                        fi
                        ;;
                    env.*)
                        if ! _rea_tpair "${_REEK#env.}" "$_REEV"; then
                            _REEWHY="has an env line that is not a one-line string"
                            return 2
                        fi
                        ;;
                esac
                ;;
        esac
    done <"$1"
    if [ -n "$_REEFOUND" ]; then
        if [ -z "$_REEC" ] || [ -z "$_REEHAVE" ]; then
            _REEWHY="has no command, or no args array on one line"
            return 2
        fi
        return 0
    fi
    if [ -n "$_REEFORM" ]; then
        _REEWHY="is written in a form this check can't read; write it as a [mcp_servers.rea] table"
        return 2
    fi
    return 1
}
# _rea_cfg_isrea: command and args run "rea mcp", directly or by an
# interpreter (node .../bin/rea mcp), as REA's setup registers it.
_rea_cfg_isrea() {
    _REE1=""
    _REE2=""
    {
        IFS= read -r _REE1
        IFS= read -r _REE2
    } <<EOF
$_REEARGS
EOF
    [ "${_REEC##*/}:$_REE1" = rea:mcp ] && return 0
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
    # The closest project config first, as Codex layers them, then the user's.
    _REED=$_REESS
    _REEPASS=""
    while :; do
        if [ "$_REED" = / ]; then
            _REEPASS="$_REEPASS /.codex/config.toml"
            break
        fi
        _REEPASS="$_REEPASS $_REED/.codex/config.toml"
        _REED=${_REED%/*}
        [ -n "$_REED" ] || _REED=/
    done
    _REEFILE=""
    for _REEF in $_REEPASS "$_REEHOME/config.toml"; do
        _rea_cfg_read "$_REEF"
        case $? in
            0)
                _REEFILE=$_REEF
                break
                ;;
            2)
                _rea_say "the [mcp_servers.rea] entry in $_REEF $_REEWHY, so REA's MCP server can't be checked; nothing checked."
                return 1
                ;;
        esac
    done
    [ -n "$_REEFILE" ] || {
        _rea_say "found no [mcp_servers.rea] entry in $_REEHOME/config.toml or in a .codex/config.toml above this directory, so REA's MCP server can't be checked; nothing checked. Run: rea setup"
        return 1
    }
    _rea_cfg_isrea || {
        _rea_say "the [mcp_servers.rea] entry in $_REEFILE does not run \"rea mcp\" (command, then args), so it is not recognised as REA's MCP server; nothing checked."
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
    for _REEK in HOME LOGNAME PATH SHELL USER __CF_USER_TEXT_ENCODING LANG LC_ALL TERM TMPDIR TZ $_REEEV; do
        case "$_REENL$_REEEP" in
            *"$_REENL$_REEK="*) continue ;;
        esac
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
                _rea_say "the cwd of the [mcp_servers.rea] entry in $_REEFILE is not an absolute path, so the area around REA's MCP server is unknown; nothing checked. Write an absolute cwd."
                return 1
                ;;
        esac
        _REECWD=$(cd -P "$_REECW" 2>/dev/null && pwd -P) && [ -n "$_REECWD" ] || {
            _rea_say "the cwd of the [mcp_servers.rea] entry in $_REEFILE can't be entered, so the area around REA's MCP server is unknown; nothing checked."
            return 1
        }
    else
        _REECWD=$_REESS
    fi
    _REEM="its config entry"
