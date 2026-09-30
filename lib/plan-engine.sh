#!/usr/bin/env bash
# Shared fail-closed manifest engine, adapted from source f89f7f3.
# Each entry owns its source root, destination root and project/global policy.
is_protected_path() {
    local p="$1" base="${1##*/}"
    case "/$p/" in */.git/*|*/.beads/*) return 0;; esac
    case "$base" in
        .env|.env.*|*.pem|*.key|*.p12|*.pfx|id_rsa*|id_ecdsa*|id_ed25519*|credentials*|*credentials.json|.netrc|.npmrc|settings.local.json|CLAUDE.local.md|*secret*|*token*) return 0;;
    esac
    case "$p" in .codex/state/tmp/*) [[ "$p" != .codex/state/tmp/.gitignore ]] && return 0;; esac
    return 1
}
validate_entry_path() {
    local line="$1" raw="$2" comp rel="${2%/}"
    [[ -n "$rel" && "$raw" != /* && "$raw" != "~"* ]] || die "manifest line $line: invalid path $raw"
    [[ "$rel" != *$'\n'* && "$rel" != *$'\r'* ]] || die "manifest line $line: control character"
    local -a comps=()
    IFS=/ read -r -a comps <<< "$rel"
    for comp in "${comps[@]}"; do
        [[ -n "$comp" && "$comp" != . && "$comp" != .. ]] || die "manifest line $line: traversal or empty component: $raw"
    done
    is_protected_path "$rel" && die "manifest line $line: protected path: $raw"
    return 0
}
check_ancestors() {
    local root="$1" rel="$2" current comp
    current="$root"
    # Reject symlinks even when they resolve inside the root.
    while [[ "$current" != / && "$current" != . ]]; do
        [[ ! -L "$current" ]] || die "symlink ancestor: $current"
        [[ ! -e "$current" || -d "$current" ]] || die "non-directory ancestor: $current"
        current="$(dirname -- "$current")"
    done
    current="$root"
    local -a comps=()
    IFS=/ read -r -a comps <<< "$rel"
    for comp in "${comps[@]}"; do
        current="$current/$comp"
        [[ ! -L "$current" ]] || die "symlink managed path: $current"
        if [[ "$current" != "$root/$rel" ]]; then
            [[ ! -e "$current" || -d "$current" ]] || die "structural conflict: $current"
        fi
    done
}
load_manifest() {
    local manifest="$1" scaffold="$2" dest="$3" policy="${4:-project}"
    local line kind raw action desc extra rel src tabs count=0 lineno=0
    [[ -f "$manifest" && ! -L "$manifest" ]] || die "missing or symlink manifest: $manifest"
    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno+1)); line="${line%$'\r'}"
        [[ -z "$line" || "$line" == \#* ]] && continue
        tabs="${line//[^$'\t']/}"
        [[ ${#tabs} == 3 ]] || die "malformed manifest line $lineno: exactly four TSV columns required"
        IFS=$'\t' read -r kind raw action desc extra <<< "$line"
        [[ -n "${kind:-}" && -n "${raw:-}" && -n "${action:-}" && -z "${extra:-}" ]] || die "malformed manifest line $lineno"
        validate_entry_path "$lineno" "$raw"; rel="${raw%/}"
        case "$kind:$action" in
            file:copy)
                src="$scaffold/$rel"
                check_ancestors "$scaffold" "$rel"
                [[ -f "$src" ]] || die "missing regular source file: $src";;
            dir:ensure_dir|transient_dir:ensure_ignored) ;;
            *) die "unknown kind/action at manifest line $lineno: $kind/$action";;
        esac
        ENTRY_KIND+=("$kind"); ENTRY_PATH+=("$rel"); ENTRY_SRCROOT+=("$scaffold")
        ENTRY_DESTROOT+=("$dest"); ENTRY_POLICY+=("$policy")
        count=$((count+1))
    done < "$manifest"
    [[ "$count" -gt 0 ]] || die "empty manifest: $manifest"
}
detect_collisions() {
    local i j pi pj ki kj
    for ((i=0;i<${#ENTRY_PATH[@]};i++)); do
        pi="${ENTRY_DESTROOT[i]}/${ENTRY_PATH[i]}"; ki="${ENTRY_KIND[i]}"
        for ((j=i+1;j<${#ENTRY_PATH[@]};j++)); do
            pj="${ENTRY_DESTROOT[j]}/${ENTRY_PATH[j]}"; kj="${ENTRY_KIND[j]}"
            if [[ "$pi" == "$pj" ]]; then
                [[ "$ki" != file && "$kj" != file ]] || die "duplicate managed path across manifests: $pi"
            elif [[ "$ki" == file && "$pj" == "$pi/"* || "$kj" == file && "$pi" == "$pj/"* ]]; then
                die "structural collision across manifests: $pi and $pj"
            fi
        done
    done
}
build_plan() {
    local i rel tgt src policy state
    for i in "${!ENTRY_PATH[@]}"; do
        rel="${ENTRY_PATH[i]}"; tgt="${ENTRY_DESTROOT[i]}/$rel"; src="${ENTRY_SRCROOT[i]}/$rel"; policy="${ENTRY_POLICY[i]}"
        check_ancestors "${ENTRY_DESTROOT[i]}" "$rel"
        state=create
        if [[ "${ENTRY_KIND[i]}" != file ]]; then
            [[ ! -e "$tgt" || -d "$tgt" ]] || die "managed directory is a file: $tgt"
            [[ ! -d "$tgt" ]] || state=identical
        else
            [[ ! -e "$tgt" || -f "$tgt" ]] || die "managed file is not a regular file: $tgt"
            if [[ -f "$tgt" ]]; then
                if cmp -s -- "$src" "$tgt"; then state=identical
                elif [[ "$policy" == global ]]; then
                    state=keep
                    [[ "$UPDATE_GLOBAL" != 1 ]] || state=overwrite
                elif [[ "$policy" == durable ]]; then state=keep
                elif [[ "$policy" == merge ]]; then state=overwrite
                elif [[ "$FORCE" == 1 && "$policy" != pack ]]; then state=overwrite
                else state=conflict; PLAN_FATAL+=("differing managed file: $tgt (back up and reconcile; --force applies only to base/core files)")
                fi
            fi
        fi
        PLAN_STATE+=("$state")
    done
}
print_plan_and_summary() {
    local i state count=0
    for i in "${!ENTRY_PATH[@]}"; do
        state="${PLAN_STATE[i]}"
        [[ "$state" == identical ]] && continue
        printf '  %-10s %s/%s\n' "$state" "${ENTRY_DESTROOT[i]}" "${ENTRY_PATH[i]}"
        count=$((count+1))
    done
    info "$count planned non-identical operations; ${#PLAN_FATAL[@]} conflicts."
}
backup_file() {
    local file="$1" dest="$2" rel="$3"
    check_ancestors "$dest" "bootstrap-backups/$RUN_ID/$rel"
    mkdir -p -- "$dest/bootstrap-backups/$RUN_ID/$(dirname -- "$rel")"
    cp -p -- "$file" "$dest/bootstrap-backups/$RUN_ID/$rel"
}
apply_plan() {
    local i state dest rel tgt src
    for i in "${!ENTRY_PATH[@]}"; do
        state="${PLAN_STATE[i]}"; dest="${ENTRY_DESTROOT[i]}"; rel="${ENTRY_PATH[i]}"
        tgt="$dest/$rel"; src="${ENTRY_SRCROOT[i]}/$rel"
        [[ "$state" == create || "$state" == overwrite ]] || continue
        check_ancestors "$dest" "$rel"
        if [[ "${ENTRY_KIND[i]}" != file ]]; then mkdir -p -- "$tgt" || return; continue; fi
        if [[ "$state" == overwrite ]]; then backup_file "$tgt" "$dest" "$rel" || return; fi
        mkdir -p -- "$(dirname -- "$tgt")" || return
        cp -p -- "$src" "$tgt" || return
    done
}
