# --- Codex config (decision brief D-5, D-6) ---------------------------------
# The config.toml in CODEX_HOME: [features] multi_agent = true and an
# [mcp_servers.rea] entry. A Python 3.11 or later parses the file with tomllib,
# so a quoted key, a dotted key or an inline table reads as Codex reads it; no
# shell parses TOML. The file is never edited. The interpreter is the one the
# REA server discovery uses (_rea_python: an absolute PATH entry outside the
# repository, run isolated from /).
_DOCTOR_TOMLSRC='import sys, tomllib
try:
    with open(sys.argv[1], "rb") as handle:
        data = handle.read(1048577)
    if len(data) > 1048576:
        print("bad:is too large to read")
        sys.exit(0)
    doc = tomllib.loads(data.decode("utf-8"))
except OSError:
    print("bad:can not be read")
    sys.exit(0)
except (ValueError, RecursionError):
    print("bad:is not valid TOML")
    sys.exit(0)
features = doc.get("features")
if isinstance(features, dict) and features.get("multi_agent") is True:
    print("multi")
servers = doc.get("mcp_servers")
if isinstance(servers, dict) and "rea" in servers:
    print("rea")
    if isinstance(servers["rea"], dict) and servers["rea"].get("enabled") is False:
        print("off")'
_doctor_codex_config() {
    local cfg="${CODEX_HOME:-$HOME/.codex}/config.toml" l multi="" rea="" off="" bad="" fix="Fix the file by hand, then run again; nothing here edits it." shown out
    shown="$(_atlas_printable "$cfg")"
    case "$cfg" in
        /*) ;;
        *)
            # A relative CODEX_HOME would read the repository's config.toml.
            _doctor_warn "multi_agent: CODEX_HOME is not an absolute path, so config.toml was not read." "Set CODEX_HOME to an absolute path, then run again."
            _doctor_warn "rea-config: CODEX_HOME is not an absolute path, so config.toml was not read." "Set CODEX_HOME to an absolute path, then run again."
            return
            ;;
    esac
    if [ -f "$cfg" ]; then
        if ! _rea_python; then
            bad="was not checked: found no Python 3.11 or later (with tomllib) outside the repository on PATH"
            fix="Put a Python 3.11 or later outside the repository on PATH, then run again."
        elif out="$(cd / && MISE_AUTO_INSTALL=0 MISE_NOT_FOUND_AUTO_INSTALL=0 "$_REEPY" -I -S -c "$_DOCTOR_TOMLSRC" "$cfg" 2>/dev/null)"; then
            while IFS= read -r l; do
                case "$l" in
                    multi) multi=1 ;;
                    rea) rea=1 ;;
                    off) off=1 ;;
                    bad:*) bad="${l#bad:}" ;;
                esac
            done <<EOF
$out
EOF
        else
            bad="was not checked: the TOML reader did not finish"
            fix="Run again; if it repeats, check that the Python 3.11 or later on PATH runs with -I -S."
        fi
    fi
    if [ -n "$bad" ]; then
        _doctor_warn "multi_agent: ${shown} ${bad}." "$fix"
        _doctor_warn "rea-config: ${shown} ${bad}." "$fix"
        return
    fi
    if [ -n "$multi" ]; then
        printf '[ok] multi_agent\n'
    else
        _doctor_warn "multi_agent: ${shown} does not set [features] multi_agent = true, so Graphify's parallel semantic extraction runs serially." \
            "Add these two lines to ${shown} by hand (if it already has a [features] table, add only the second line there; nothing here edits the file):
[features]
multi_agent = true"
    fi
    if [ -n "$off" ]; then
        _doctor_warn "rea-config: the [mcp_servers.rea] entry in ${shown} has enabled = false, so Codex does not start REA's MCP server." "Set enabled = true there by hand (nothing here edits the file), then restart Codex."
    elif [ -n "$rea" ]; then
        printf '[ok] rea-config\n'
    else
        _doctor_warn "rea-config: ${shown} has no [mcp_servers.rea] entry." "Run: rea setup"
    fi
}

# --- Migration (decision brief D-4) -----------------------------------------
# _doctor_stamped <name>: true when the atlas pack's install record lists the
# skill's SKILL.md. The installer never adopts an identical file that was
# already there, so a copy from before the pack stays unlisted.
_doctor_stamped() {
    local record="${ATLAS_CONFIG_DIR}/bootstrap/packs/atlas.json" l
    [ -f "$record" ] || return 1
    while IFS= read -r l || [ -n "$l" ]; do
        case "$l" in *"\"skills/$1/SKILL.md\""*) return 0 ;; esac
    done 2>/dev/null <"$record"
    return 1
}

_doctor_migration() {
    local link f name dir retired
    retired="${ATLAS_CONFIG_DIR}/retired"
    for name in archify graphify; do
        link="${ATLAS_CONFIG_DIR}/skills/${name}"
        if [ -L "$link" ]; then
            _doctor_warn "migration-${name}-link: $(_atlas_printable "$link") is a symlink to $(_doctor_target "$link"); the installer refuses to install through a link." \
                "Move or remove the link, not its target: rm $(_doctor_q "$link"); then reinstall the atlas pack (codex-bootstrap --global-only --pack atlas) and check $(_doctor_q "$(_doctor_target "$link")") for pack files."
        else
            printf '[ok] migration-%s-link\n' "$name"
        fi
    done
    f="${ATLAS_CONFIG_DIR}/skills/graphify/.graphify_version"
    if [ -e "$f" ] || [ -L "$f" ]; then
        _doctor_warn "migration-stamp-agents: $(_atlas_printable "$f") exists; a bare graphify command can then overwrite the pack's Graphify skill." \
            "Delete it by hand: rm $(_doctor_q "$f")"
    else
        printf '[ok] migration-stamp-agents\n'
    fi
    for name in archify graphify; do
        dir="${ATLAS_CONFIG_DIR}/skills/${name}"
        if [ -L "$dir" ] || [ ! -d "$dir" ] || _doctor_stamped "$name"; then
            printf '[ok] migration-unstamped-%s\n' "$name"
        else
            _doctor_warn "migration-unstamped-${name}: $(_atlas_printable "$dir") is not in the atlas pack's install record, so the pack neither refreshes nor removes it." \
                "Move it out of the skills directory, then install the pack: mkdir -p $(_doctor_q "$retired") && mv $(_doctor_q "$dir") $(_doctor_q "${retired}/${name}") && codex-bootstrap --global-only --pack atlas"
        fi
    done
}

