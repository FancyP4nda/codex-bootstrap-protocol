#!/bin/sh
# bead-names.sh: the bead side of $map-impact (PRD Part III FR-034; AC-072).
#
#   bead-names.sh [--] <bead-id>
#     One line per name the bead names, in the order it first names it,
#     each once: "path <path>" or "symbol <name>". Nothing for a bead
#     naming none.
#   bead-names.sh --title [--] <bead-id>
#     The bead's title on one line, control characters as spaces, for the
#     fallback query.
#   bead-names.sh --comment [--] <bead-id> <report>
#     Posts <report> as one comment on the bead (bd comments add), for the
#     Command's step 7, which runs only when the user asked for a comment.
#
# The names: it reads `bd show --json` (a one-element list in bd 1.0; a
# bare object is accepted too) and scans the title, description, design,
# acceptance criteria and notes, never comments or labels. Fenced code
# blocks are skipped whole, and a code span never crosses a blank line. A
# path is a backticked token holding a "/" (not a slash command such as
# $map-repo), a backticked or prose file name with a known extension, or a
# prose token holding a "/" that ends in "/" or in such a file name, so
# "and/or" and "0.9.85" are not paths. A symbol is a backticked
# identifier, optionally qualified with ".", "::" or "#" and ending in
# "()", that isn't a plain lowercase word: `detect()` and `AuthService` are
# symbols, `none` and `query` are words. A location after a backticked
# name (`src/a.py:42`, `a.py#L3`, `a.py:L42`, `tests/t.py::test_x`) is
# dropped and the name kept. Backticked text with a space, a leading "-"
# or "$", or other punctuation is neither, and URLs are dropped.
#
# The repository is untrusted (R-023 in the pack notes): before it looks up
# bd or python3, it takes PATH from the Graphify runner's --path, which
# prints the agent's PATH cut to its absolute entries outside FR-031's
# untrusted area, so neither tool can come from the repository. When the
# runner refuses instead (a non-zero status, which this script reads), it
# prints the refusal and stops. Every bd call runs with BD_NO_HOOKS=true,
# so bd runs none of the repository's .beads/hooks/ scripts, and the read
# runs with --readonly --sandbox. Its Python runs with -I and the bead's
# JSON on stdin, from a script held in a variable that no value enters.
#
# Exit 0 on a result (empty included) or a posted comment; 1 on a runner
# refusal, without bd ("bd not found; pass a symbol instead."), when bd
# fails, or when its output holds no single bead; 2 on a usage error or a
# value that isn't a bead ID, before bd runs. It writes nothing itself; it
# runs only `bd show`, which records the bead in bd's git-ignored
# .beads/last-touched, and `bd comments add` with --comment.

usage() {
    printf '%s\n' 'usage: bead-names.sh [--title] [--] <bead-id> | --comment [--] <bead-id> <report>' >&2
    exit 2
}

mode=names
case "${1:-}" in
    --title) mode=title; shift ;;
    --comment) mode=comment; shift ;;
esac
[ "${1:-}" = -- ] && shift
if [ "$mode" = comment ]; then
    [ "$#" -eq 2 ] || usage
    report=$2
else
    [ "$#" -eq 1 ] || usage
fi
id=$1
# A bead ID: letters, digits, ".", "_" and "-", starting with a letter or
# digit, so it can't be read as an option or carry shell text.
case "$id" in
    '' | [!A-Za-z0-9]* | *[!A-Za-z0-9._-]*)
        printf '%s\n' 'map-impact: that is not a bead ID; pass a bead ID such as proj-a1b2, or a symbol.'
        exit 2
        ;;
esac

# The parser, as data: no value is ever written into its source. It sits
# in a single-quoted string, so it holds no apostrophe.
parser='
import json, re, sys

FIELDS = ("title", "description", "design", "acceptance_criteria", "notes")
# Longer fields are cut, so a pathological bead can not stall the scan.
FIELD_MAX = 100000
EXTENSIONS = set("""
    sh bash zsh fish ps1 py pyi ipynb md mdx rst txt adoc yaml yml json jsonl toml ini cfg conf env
    js mjs cjs mts cts ts tsx jsx vue svelte astro go rs rb java kt kts scala groovy gradle c h cc
    cpp cxx hpp hh cs fs swift m mm php pl pm lua r jl sql html htm css scss sass less xml svg proto
    graphql gql tf hcl ex exs erl hrl hs ml clj cljs dart nim zig mk cmake lock dockerfile
""".split())
CHARS = re.compile(r"[A-Za-z0-9_./-]+\Z")
SLASH_COMMAND = re.compile(r"/[A-Za-z0-9_-]+\Z")
SYMBOL = re.compile(r"[A-Za-z_$][A-Za-z0-9_$]*(?:(?:\.|::|#)[A-Za-z_$][A-Za-z0-9_$]*)*(?:\(\))?\Z")
WORD = re.compile(r"[a-z]+\Z")
# A URL starts a word and stops at a backtick, so a backticked URL leaves
# its span intact.
URL = re.compile(r"(?<![A-Za-z0-9+.-])[A-Za-z][A-Za-z0-9+.-]*://[^\s`]*")
# A code span (a run of up to 16 backticks, then text that crosses no blank
# line, then the same run), or a run of path characters.
SCAN = re.compile(r"(?<!`)(`{1,16})(?!`)((?:(?!\n[ \t]*\n).)+?)(?<!`)\1(?!`)|[A-Za-z0-9_./-]+", re.S)
FENCE = re.compile(r" {0,3}(`{3,}|~{3,})")
# A location after a name (src/a.py:42, a.py:3-9, a.py#L3-L9, a.py:L42):
# the name alone is what the graph knows. Bounded repeats keep the search
# linear in the span.
LOCATION = re.compile(r"(?::[0-9]{1,9}(?:[-:][0-9]{1,9}){0,2}|[#:]L[0-9]{1,9}(?:-L?[0-9]{1,9})?)\Z")
# No real path or symbol is longer.
SPAN_MAX = 512


def unfenced(text):
    out, fence = [], None
    for line in text.split("\n"):
        m = FENCE.match(line)
        if fence is None:
            if m and not (m.group(1)[0] == "`" and "`" in line[m.end():]):
                fence = m.group(1)
                continue
            out.append(line)
        elif m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) and not line[m.end():].strip():
            fence = None
    return "\n".join(out)


def has_extension(name):
    base = name.rsplit("/", 1)[-1]
    stem, dot, ext = base.rpartition(".")
    return bool(dot and stem.strip(".") and ext.lower() in EXTENSIONS)


def as_path(token):
    while token.startswith("./"):
        token = token[2:]
    if not token or token.startswith("-"):
        return None
    return ("path", token)


def code_name(span):
    span = span.strip()
    # A shell variable ($HOME, $PATH) names no node.
    if len(span) > SPAN_MAX or span.startswith("$"):
        return None
    span = LOCATION.sub("", span)
    # A test id (pkg/test_a.py::test_x) names its file.
    head, sep, _ = span.partition("::")
    if sep and CHARS.match(head) and ("/" in head or has_extension(head)):
        span = head
    pathlike = bool(CHARS.match(span))
    if not span or span.startswith("-") or not (pathlike or SYMBOL.match(span)):
        return None
    if pathlike and "/" in span and "//" not in span and not SLASH_COMMAND.match(span):
        return as_path(span)
    if pathlike and has_extension(span):
        return as_path(span)
    if SYMBOL.match(span) and not WORD.match(span):
        name = span[:-2] if span.endswith("()") else span
        if name not in ("True", "False", "None", "NULL", "TODO"):
            return ("symbol", name)
    return None


def prose_name(token):
    token = token.rstrip(".")
    if not token or token.startswith("-") or "//" in token:
        return None
    if "/" in token:
        if token.endswith("/") and token.strip("./"):
            return as_path(token)
        if has_extension(token) and not SLASH_COMMAND.match(token):
            return as_path(token)
        return None
    if has_extension(token) and token[0].isalpha():
        return as_path(token)
    return None


def names(bead):
    seen, found = set(), []
    for field in FIELDS:
        text = bead.get(field)
        if not isinstance(text, str):
            continue
        text = URL.sub(" ", unfenced(text[:FIELD_MAX]))
        for m in SCAN.finditer(text):
            hit = code_name(m.group(2)) if m.group(1) else prose_name(m.group(0))
            if hit and hit not in seen:
                seen.add(hit)
                found.append(hit)
    return found


try:
    data = json.loads(sys.stdin.read())
except ValueError:
    data = None
if isinstance(data, list) and len(data) == 1:
    data = data[0]
# A bead has a string id; anything else (an envelope, say) is no bead.
if not isinstance(data, dict) or not isinstance(data.get("id"), str):
    print("map-impact: bd show printed no bead for that ID.")
    sys.exit(1)
if sys.argv[1] == "title":
    title = data.get("title") if isinstance(data.get("title"), str) else ""
    print(" ".join("".join(c if c.isprintable() else " " for c in title).split()))
else:
    for kind, name in names(data):
        print(kind, name)
'

NO_PATH='map-impact: the Graphify runner printed no PATH; run $atlas-doctor.'

# cut_path: the runner's one line (the cut PATH, or its refusal), then its
# exit status as "rc=<n>" on a line of its own, since a pipe drops it and
# every refusal the runner prints can start with "/". The runner runs in
# command position here, the one form Command text may call it in.
cut_path() {
    /bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path </dev/null
    printf 'rc=%s\n' "$?"
}

# main: reads cut_path's two lines on stdin, then does the work with that
# PATH. A refusal is shown as the runner printed it.
main() {
    IFS= read -r cut || cut=
    IFS= read -r rc || rc=
    if [ "$rc" != rc=0 ]; then
        case "$cut" in rc=* | '') cut=$NO_PATH ;; esac
        printf '%s\n' "$cut"
        exit 1
    fi
    case "$cut" in
        /*) ;;
        *) printf '%s\n' "$NO_PATH"; exit 1 ;;
    esac
    PATH=$cut
    export PATH
    # bd runs the repository's .beads/hooks/ scripts after a write, and the
    # repository's own config decides whether hooks run; this variable
    # wins over that config (bd 1.3.0; see "Not covered" in the pack notes
    # for older bd), so a comment runs no hook. A mise shim for python3 or
    # node (bd's launcher) on the cut PATH would otherwise install a
    # version the repository's .tool-versions names.
    BD_NO_HOOKS=true
    MISE_AUTO_INSTALL=0
    MISE_NOT_FOUND_AUTO_INSTALL=0
    export BD_NO_HOOKS MISE_AUTO_INSTALL MISE_NOT_FOUND_AUTO_INSTALL

    if ! command -v bd >/dev/null 2>&1; then
        printf '%s\n' 'bd not found; pass a symbol instead.'
        exit 1
    fi
    if [ "$mode" = comment ]; then
        # --sandbox: no Dolt auto-push, whatever the repository's config.
        bd --sandbox comments add -- "$id" "$report"
        exit
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        printf '%s\n' 'map-impact: python3 not found; it reads the bead with python3.'
        exit 1
    fi
    # Read-only, and no Dolt auto-push: the read can't write or reach out.
    if ! json=$(bd --readonly --sandbox show --json --id="$id"); then
        printf '%s\n' 'map-impact: bd could not show that bead (its error is above).'
        exit 1
    fi
    printf '%s\n' "$json" | python3 -I -c "$parser" "$mode"
}

cut_path | main
