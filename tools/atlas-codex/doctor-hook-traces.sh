# _doctor_hook_traces <id> <uninstall> <file>...: a graphify string inside a
# PreToolUse array of any of the JSON files (the clients' hook settings).
_doctor_hook_traces() {
    local id="$1" uninstall="$2" f st found=""
    shift 2
    for f in "$@"; do
        st=0
        _doctor_pretooluse "$f" || st=$?
        case "$st" in
            0)
                _doctor_trace_warn "$id" "$(_doctor_where "$f" "uninstall writes through") has a graphify PreToolUse hook" "$uninstall"
                found=1
                ;;
            2)
                _doctor_warn "${id}: $(_atlas_printable "$f") is larger than ${ATLAS_DOCTOR_SCAN_BYTES} bytes, so it was not scanned." \
                    "Check its PreToolUse entries for graphify by hand; to remove one, run from $(_atlas_printable "$_DOCTOR_TOP"): $(_doctor_uninstall "$uninstall")"
                found=1
                ;;
        esac
    done
    [ -n "$found" ] || printf '[ok] %s\n' "$id"
}

