# --- Codex config (decision brief D-5, D-6) ---------------------------------
# The config.toml in CODEX_HOME: [features] multi_agent = true and an
# [mcp_servers.rea] entry. Read with bash builtins; the file is never edited.
_doctor_codex_config() {
    local cfg="${CODEX_HOME:-$HOME/.codex}/config.toml" l table="" key val multi="" rea="" shown
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
        while IFS= read -r l || [ -n "$l" ]; do
            _doctor_strip "$l"
            case "$_DL" in '' | '#'*) continue ;; esac
            case "$_DL" in
                '['*)
                    table="${_DL#\[}"
                    table="${table%%]*}"
                    table="${table//[[:space:]]/}"
                    case "$table" in mcp_servers.rea | mcp_servers.rea.*) rea=1 ;; esac
                    continue
                    ;;
            esac
            case "$_DL" in *=*) ;; *) continue ;; esac
            key="${_DL%%=*}"
            val="${_DL#*=}"
            key="${key//[[:space:]]/}"
            val="${val%%#*}"
            val="${val//[[:space:]]/}"
            case "$table:$key" in
                features:multi_agent | :features.multi_agent)
                    if [ "$val" = true ]; then multi=1; else multi=""; fi
                    ;;
                :features)
                    case "$val" in *multi_agent=true*) multi=1 ;; esac
                    ;;
                :mcp_servers.rea | :mcp_servers.rea.* | mcp_servers:rea | mcp_servers:rea.*)
                    rea=1
                    ;;
            esac
        done 2>/dev/null <"$cfg"
    fi
    if [ -n "$multi" ]; then
        printf '[ok] multi_agent\n'
    else
        _doctor_warn "multi_agent: ${shown} does not set [features] multi_agent = true, so Graphify's parallel semantic extraction runs serially." \
            "Add these two lines to ${shown} by hand (if it already has a [features] table, add only the second line there; nothing here edits the file):
[features]
multi_agent = true"
    fi
    if [ -n "$rea" ]; then
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

