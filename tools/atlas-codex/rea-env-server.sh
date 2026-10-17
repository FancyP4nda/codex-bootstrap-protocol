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
# _rea_cfg_read <file>: the [mcp_servers.rea] keys of one config file.
# Returns 0 with the keys it sets in _REEC (command), _REEARGS (one per line,
# _REEHAVE set), _REEEV (env_vars names, one per line, _REEEVSET set), _REEEP
# (env, NAME=value per line) and _REECW (cwd), each empty when the file does
# not set it; 1 when the file has no such entry; 2 with the reason in
# _REEWHY.
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
    _REEEVSET=""
    _REEENVT=""
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
                    mcp_servers.rea.env)
                        _REEBL=env
                        _REEENVT=1
                        ;;
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
                            _REEEVSET=1
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
    # A layer may hold only part of the entry (Codex merges the layers per
    # key), so completeness is checked on the merged entry, not here.
    if [ -n "$_REEFOUND$_REEENVT" ]; then
        return 0
    fi
    if [ -n "$_REEFORM" ]; then
        _REEWHY="is written in a form this check can't read; write it as a [mcp_servers.rea] table"
        return 2
    fi
    return 1
}
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
# _rea_layer <file> <project>: one config layer's [mcp_servers.rea] keys,
# merged over the earlier layers as Codex does: per key, the later layer
# wins, an array (args, env_vars) is replaced whole, and the env table is
# merged name by name. Returns 0 when the layer was merged, 1 when it
# holds no entry or is ignored (a project layer of an untrusted project),
# 2 after a named line when it can't be read.
_rea_layer() {
    _rea_cfg_read "$1"
    _REERC=$?
    if [ "$2" = project ] && [ "$_REERC" -ne 1 ] && [ "$_REETRUST" != yes ]; then
        if [ "$_REETRUST" = no ]; then
            return 1
        fi
        _rea_say "$1 sets an [mcp_servers.rea] entry, but whether Codex trusts the project $_REEROOT can't be read from the [projects] tables of $_REEHOME/config.toml, so REA's MCP server can't be checked; nothing checked."
        return 2
    fi
    case $_REERC in
        0) ;;
        2)
            _rea_say "the [mcp_servers.rea] entry in $1 $_REEWHY, so REA's MCP server can't be checked; nothing checked."
            return 2
            ;;
        *) return 1 ;;
    esac
    [ -z "$_REEC" ] || _REEMC=$_REEC
    if [ -n "$_REEHAVE" ]; then
        _REEMA=$_REEARGS
        _REEMHAVE=1
    fi
    [ -z "$_REEEVSET" ] || _REEMEV=$_REEEV
    if [ -n "$_REECW" ]; then
        _REEMCW=$_REECW
        _REEMCWFILE=$1
    fi
    _REEMT=""
    while IFS= read -r _REEL; do
        [ -n "$_REEL" ] || continue
        case "$_REENL$_REEEP" in
            *"$_REENL${_REEL%%=*}="*) continue ;;
        esac
        _REEMT="$_REEMT$_REEL$_REENL"
    done <<EOF
$_REEMEP
EOF
    _REEMEP="$_REEMT$_REEEP"
    _REEFILE="${_REEFILE:+$_REEFILE, }$1"
    _REEANY=1
    return 0
}
# _rea_layers <dir>: the project layers from the project root down to dir,
# the root's first. Each candidate path is read directly, quoted, as the
# recursion unwinds; no list of paths is built.
_rea_layers() {
    if [ "$1" != "$_REEROOT" ]; then
        _REEUP=${1%/*}
        [ -n "$_REEUP" ] || _REEUP=/
        _rea_layers "$_REEUP" || return 2
    fi
    _rea_layer "$1/.codex/config.toml" project
    [ $? -ne 2 ]
}
# _rea_user_scan <file>: from the user's config.toml, project_root_markers
# (in _REEMARK, one per line, default ".git") and whether Codex trusts the
# project at _REEROOT (_REETRUST: yes, no, or unknown when the file's
# [projects] tables are in a form this reader can't take).
_rea_user_scan() {
    _REEMARK=".git"
    _REETRUST=no
    [ -r "$1" ] || return 0
    _REEPB=""
    _REEPU=""
    _REEPL=""
    _REETOPL=1
    while IFS= read -r _REEL || [ -n "$_REEL" ]; do
        _REEL=${_REEL%"$_REECR"}
        _REETR=$_REEL
        _rea_ltrim
        _REEL=$_REETR
        case "$_REEL" in
            '' | '#'*) continue ;;
            '[['*)
                _REEPB=""
                _REETOPL=""
                continue
                ;;
            '['*)
                _REEPB=""
                _REETOPL=""
                case "$_REEL" in
                    '[projects]'* | '[ projects ]'*) _REEPU=1 ;;
                    '[projects.'*)
                        if _rea_tstr "${_REEL#\[projects.}" && case "$_REETR" in \]*) true ;; *) false ;; esac; then
                            if [ -n "$_REEROOT" ] && { [ "$_REETV" = "$_REEROOT" ] || [ "$_REETV" = "$_REEROOT/" ]; }; then
                                _REEPB=1
                            fi
                        else
                            _REEPU=1
                        fi
                        ;;
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
        case "$_REEN" in
            project_root_markers)
                if [ -z "$_REETOPL" ]; then
                    :
                elif _rea_tarr "$_REEV"; then
                    _REEMARK=$_REETL
                else
                    _REEPU=1
                fi
                ;;
            projects | projects.*) _REEPU=1 ;;
            trust_level)
                if [ -n "$_REEPB" ]; then
                    if _rea_tstr "$_REEV" && _rea_tend; then
                        _REEPL=$_REETV
                    else
                        _REEPU=1
                    fi
                fi
                ;;
        esac
    done <"$1"
    if [ -n "$_REEPL" ]; then
        [ "$_REEPL" = trusted ] && _REETRUST=yes
    elif [ -n "$_REEPU" ]; then
        _REETRUST=unknown
    fi
    return 0
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
    # Codex's layering (Advanced Configuration, "Project config files"): the
    # user's config.toml, then the .codex/config.toml of each directory from the
    # project root down to this one, closest last, merged per key. Project
    # layers count only when the user's config marks the project trusted.
    _REEROOT=""
    _rea_user_scan "$_REEHOME/config.toml"
    _REED=$_REESS
    while :; do
        while IFS= read -r _REEMK; do
            case "$_REEMK" in '' | */*) continue ;; esac
            if [ -e "$_REED/$_REEMK" ]; then
                _REEROOT=$_REED
                break
            fi
        done <<EOF
$_REEMARK
EOF
        [ -z "$_REEROOT" ] || break
        [ "$_REED" = / ] && break
        _REED=${_REED%/*}
        [ -n "$_REED" ] || _REED=/
    done
    [ -n "$_REEROOT" ] || _REEROOT=$_REESS
    _rea_user_scan "$_REEHOME/config.toml"
    _REEMC=""
    _REEMA=""
    _REEMHAVE=""
    _REEMEV=""
    _REEMEP=""
    _REEMCW=""
    _REEMCWFILE=""
    _REEFILE=""
    _REEANY=""
    _rea_layer "$_REEHOME/config.toml" user
    [ $? -ne 2 ] || return 1
    _rea_layers "$_REESS" || return 1
    [ -n "$_REEANY" ] || {
        _rea_say "found no [mcp_servers.rea] entry in $_REEHOME/config.toml or in a trusted project's .codex/config.toml from $_REEROOT down to this directory, so REA's MCP server can't be checked; nothing checked. Run: rea setup"
        return 1
    }
    if [ -z "$_REEMC" ] || [ -z "$_REEMHAVE" ]; then
        _rea_say "the [mcp_servers.rea] entry ($_REEFILE, merged as Codex layers them) has no command, or no args array on one line, so REA's MCP server can't be checked; nothing checked."
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
