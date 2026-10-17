#!/bin/sh
# atlas-preflight.sh: the atlas pack's preflight for the vendored Graphify
# skill (PRD Part III FR-031, FR-029; AC-065, AC-100, AC-102, AC-103,
# AC-107, AC-109, AC-111, AC-113).
#
# Kit-authored, not vendored: the pack lists it in pack_paths, and each call
# to it from a vendored Graphify file is a recorded patch. Every entry path
# of the skill runs it before its first Graphify call: Step 1, the
# interpreter guard at the start of the fast path and of every subcommand
# flow (again at each one, and again for a hand-off to another scan root),
# and Step 2's narrowing to a subfolder, which changes the scan root.
#
# It does, in this order, and stops at the first miss:
#   1. the runner's checks (atlas-graphify.sh --resolve, beside this file):
#      no inherited GRAPHIFY_* variable but GRAPHIFY_NO_AUTO_REFRESH and
#      GRAPHIFY_QUERY_LOG_DISABLE (refused by name, never by value); the graphify executable and the
#      interpreter beside it outside the untrusted area (FR-031); and the pin,
#      through that interpreter ("$PY" -I -m graphify --version must print
#      exactly "graphify 0.9.85", a newer CLI being a mismatch), else the
#      matching FR-029 graphify fix line. The runner's --resolve also
#      applies the git environment rule before this script's first git
#      call: a git-steering variable set non-empty (GIT_CONFIG*, GIT_DIR,
#      GIT_WORK_TREE and the rest; GIT_CONFIG even empty) is refused,
#      naming it, so the check
#      below reads the configuration git really uses;
#   1a. the lazy-fetch rule (after the scan roots pass step 2 chain checks):
#      the settings above stop git fetching a missing object from a promisor
#      remote, but git older than 2.45 ignores GIT_NO_LAZY_FETCH, so a
#      partial clone (a promisor remote, or extensions.partialClone) is
#      refused there, for the working directory and each scan root;
#   1b. the git-configuration check (after the scan roots pass step 2 chain
#      checks): a repository-local core.fsmonitor that is not a boolean (a
#      command git would run), or one from a file inside the untrusted area
#      in any scope (a global file XDG_CONFIG_HOME or HOME points there), is
#      refused for the working directory and each
#      scan root (Graphify lists files with plain git ls-files, which runs
#      no hook, so core.hooksPath, set by Husky, is not refused);
#   2. the output-root check: every scan root (stdin, one per line; none
#      means ".") must be a directory inside the working directory, reached
#      without a symlink and without "..". Then ./graphify-out and
#      <scan root>/graphify-out for each scan root must not be, contain or
#      sit below a symlink, and must resolve inside the working directory.
#      graphify-out/.graphify_python, .graphify_root and each output root's
#      .graphify_build.json are exempt from the symlink scan, since step 3
#      removes them; a directory at a .graphify_build.json is a stop. Then
#      the symlink gate (FR-031, "Symlinked inputs"; AC-125): each scan root
#      is walked whole, its output roots skipped, and every symlink there
#      that Graphify's ignored_predicate doesn't exclude must resolve to a
#      regular file under the scan root that git tracks (mode 100644 or
#      100755) and that Graphify reads on its own (not excluded, not
#      _is_sensitive, typed by classify_file, no Google Workspace
#      shortcut). Each other link gets one line, naming it from the scan
#      root and never its target; outside a git work tree, or without git,
#      every link does;
#   3. the run-local state files: it creates graphify-out/.graphify_python
#      and graphify-out/.graphify_root exclusively, with this run's
#      interpreter and the first scan root, resolved, and empties
#      graphify-out/.graphify_values/, where the agent writes free-text
#      values with its file tool before the blocks that read them. Before
#      any detection reads it, it replaces .graphify_build.json in every
#      output root (creating the root when missing) with exactly
#      {"excludes": [".archify/"], "gitignore": true} (BUILD_EXCLUDES
#      below), so Graphify skips every .archify/ directory and a
#      repository's own config never shapes the corpus (FR-031, AC-118).
# Before any check, it removes graphify-out/.graphify_python,
# graphify-out/.graphify_root, graphify-out/.graphify_build.json and the
# detection results .graphify_detect.json and .graphify_incremental.json (a
# symlink included) when ./graphify-out is a real directory, so a stop never
# leaves a repository's own state files, or an earlier run's detection, there
# for a later block to run. --links removes nothing. A
# scan root's own graphify-out/.graphify_build.json is replaced only in
# step 3, once that root has passed the checks: removing it earlier would
# act on a path not yet checked for symlinks. Nothing else is written before
# every check has passed. On a stop it prints one line (the gate, one per
# link), which the skill tells the agent to show as printed, and exits 1.
# On success it prints nothing and exits 0.
#
# The runner finds the interpreter beside the real graphify executable (uv
# tool, pipx or a venv), following its symlinks; the executable's first line
# is never read, so a /bin/sh trampoline under a path with a space works.
# Before any external command runs, here and in the runner, PATH is cut to
# its absolute entries outside the untrusted area (FR-031: the outermost git
# checkout around the working directory, or the working directory outside
# git), so neither a relative entry (./bin, node_modules/.bin) nor an
# absolute one into the repository supplies rm or any other command; a
# graphify found on such an absolute entry is refused, naming it. Every scan
# root lies inside the working directory (step 2), so inside the area, and
# that refusal covers the scan roots.
#
# Usage (the skill's blocks pass every path through a quoted heredoc):
#   /bin/sh atlas-preflight.sh <<'GRAPHIFY_ROOTS_EOF'
#   <scan root>
#   [<further scan root> ...]
#   GRAPHIFY_ROOTS_EOF
# With --links (the runner's call before every update), the same scan roots
# on stdin get step 1, the checks of step 2 and the gate, and nothing is
# written or removed; it prints nothing and exits 0 when the gate passes.
# Before the gate, it stops unless each scan root's
# graphify-out/.graphify_build.json, which the update of Graphify reads, is
# BUILD_CONFIG byte for byte, so the gate and Graphify skip the same files.

export GRAPHIFY_NO_AUTO_REFRESH=1
# No helper, no lazy fetch and no transport for this script's git calls and
# the runner's (the settings every skill block exports, and the runner sets
# for Graphify): the git helper variables are unset, not refused.
unset GIT_ASKPASS SSH_ASKPASS GIT_SSH GIT_SSH_COMMAND GIT_TERMINAL_PROMPT GIT_EXTERNAL_DIFF
export GIT_NO_LAZY_FETCH=1 GIT_PROTOCOL_FROM_USER=0 GIT_ALLOW_PROTOCOL=

# The runner's PATH (its absolute entries outside the untrusted area)
# before any external command runs, rm below included, so no command this
# script runs comes from the repository. /bin/sh, an absolute path, runs
# the runner, which uses only shell builtins until it has cut PATH.
case "$0" in */*) _GHERE="${0%/*}" ;; *) _GHERE=. ;; esac
if ! PATH=$(/bin/sh "$_GHERE/atlas-graphify.sh" --path </dev/null) || [ -z "$PATH" ]; then
    printf '%s\n' "${PATH:-atlas-preflight.sh: the runner atlas-graphify.sh is missing beside this file; reinstall the atlas pack.}"
    exit 1
fi
export PATH

# --links: the symlink gate alone (FR-031, "Symlinked inputs"): step 1,
# the checks of step 2 and the gate, with nothing written, the removal
# below included. The runner runs it before every update.
_GLINKS=""
if [ "${1:-}" = --links ]; then
    if [ "$#" -ne 1 ]; then
        printf '%s\n' "atlas-preflight.sh: --links takes nothing else." >&2
        exit 2
    fi
    _GLINKS=--links
    shift
fi

# The state files are this run's or none: a check that stops below must not
# leave the repository's own for a later block (or a fallback the agent
# reaches for) to run. rm -f removes a symlink, never its target. The
# --update flow's pending manifest goes too: only this flow's merge, after
# this preflight, may write the one its Step 4 reads.
if [ -z "$_GLINKS" ] && [ -d graphify-out ] && [ ! -L graphify-out ]; then
    rm -f graphify-out/.graphify_python graphify-out/.graphify_root graphify-out/.graphify_update_pending.json \
        graphify-out/.graphify_build.json graphify-out/.graphify_detect.json graphify-out/.graphify_incremental.json 2>/dev/null
fi

if [ "$#" -ne 0 ]; then
    printf '%s\n' "atlas-preflight.sh: unknown argument: $1" >&2
    exit 2
fi

# The pinned-version check, the interpreter resolution and the refusals of
# a graphify or interpreter inside the untrusted area and of an inherited
# GRAPHIFY_* variable are the runner's (atlas-graphify.sh, beside this file), so the
# version checked here is the code every later operation runs. It prints
# the interpreter, or the one line to show, which this script passes on.
if ! PYTHON=$(/bin/sh "$_GHERE/atlas-graphify.sh" --resolve </dev/null) || [ -z "$PYTHON" ]; then
    printf '%s\n' "${PYTHON:-atlas-preflight.sh: the runner atlas-graphify.sh is missing beside this file; reinstall the atlas pack.}"
    exit 1
fi

# Steps 2 and 3 in the pinned interpreter, isolated. The scan roots arrive
# on stdin as data and are never part of any command line.
exec "$PYTHON" -I -c '
import json, os, sys

# The build config every output root gets (FR-031, AC-118): Graphify 0.9.85
# reads graphify-out/.graphify_build.json for every detection the pack runs
# (the skill blocks through _read_build_excludes and _read_build_gitignore,
# the runner update through watch._rebuild_code), and a "<dir>/" pattern
# drops that directory at any depth. These are the directories
# atlas-check.sh leaves out of the provenance capture and state diff, minus
# graphify-out/, which Graphify skips itself; a static check holds the two
# equal (verification/atlas-build-config-check.py). gitignore true keeps a
# committed config from making Graphify read git-ignored files. The symlink
# gate judges links under these same two constants, and --links runs only
# when the config on disk is BUILD_CONFIG, so the gate and Graphify skip the
# same files (the same check holds that).
BUILD_EXCLUDES = [".archify/"]
BUILD_GITIGNORE = True
BUILD_CONFIG = json.dumps({"excludes": BUILD_EXCLUDES, "gitignore": BUILD_GITIGNORE})
LINKS = sys.argv[1:] == ["--links"]

def stop(message):
    sys.stdout.write(message + "\n")
    sys.exit(1)

cwd = os.getcwd()

def shown(path):
    return os.path.relpath(path, cwd)

def inside(path):
    return os.path.commonpath([cwd, path]) == cwd

def chain(given):
    """The absolute path of a path given relative to (or inside) the working
    directory, refused when it uses "..", lies outside it, or is reached
    through a symlink (the path itself included)."""
    if given.startswith("-"):
        stop("%s starts with \"-\"; write it as ./%s, then run /graphify again." % (given, given))
    if ".." in given.split("/"):
        stop("%s uses \"..\"; give a path inside the working directory without it." % given)
    full = os.path.normpath(os.path.join(cwd, given))
    if not inside(full):
        stop("%s lies outside the working directory; run /graphify from a directory that contains it." % given)
    cur = cwd
    for part in os.path.relpath(full, cwd).split(os.sep):
        if part == ".":
            continue
        cur = os.path.join(cur, part)
        if os.path.islink(cur):
            stop("%s is a symlink; remove it, then run /graphify again." % shown(cur))
        if not os.path.lexists(cur):
            break
    if not inside(os.path.realpath(full)):
        stop("%s lies outside the working directory; run /graphify from a directory that contains it." % given)
    return full

roots = [line for line in sys.stdin.read().split("\n") if line] or ["."]
scan = []
for given in roots:
    full = chain(given)
    if not os.path.isdir(full):
        stop("%s is not a directory in the working directory." % given)
    scan.append(full)

# Git settings that run a command (or a hook path) when Graphify lists the
# files: detect() calls plain "git ls-files", which starts core.fsmonitor.
# A value from the own configuration of the repository (local or worktree scope)
# is chosen by the repository author, so it is refused unless it is off. So is
# one from a file inside the untrusted area in any scope (a global file that
# XDG_CONFIG_HOME or HOME points into the repository). The global and system
# settings of the operator, outside it, are theirs. The refusal names the
# setting (and such a file), never its value. The runner refused every git
# variable that would make this query read other files than the listing does.
import re, shutil, subprocess
# false words, and the true words that select git own built-in daemon (no command)
OK_WORDS = ("", "false", "0", "no", "off", "true", "1", "yes", "on")

def pathname(path):
    # A control character could drive the terminal; a byte that is not UTF-8
    # (a surrogate here) could not be printed.
    bad = any(ord(c) < 32 or ord(c) == 127 or 0xDC80 <= ord(c) <= 0xDCFF for c in path)
    return "(a path with control characters)" if bad else path

# FR-031 untrusted area, as the runner ATLAS-BOUNDARY block finds it: the
# outermost directory around a directory that holds a .git entry, never /,
# $HOME or an ancestor of it, else the directory itself; for the working
# directory, each scan root and ATLAS_START_DIR, by physical and logical name.
homes = set()
if os.environ.get("HOME", "").startswith("/"):
    homes = {os.path.normpath(os.environ["HOME"]), os.path.realpath(os.environ["HOME"])}

def at_or_above_home(d):
    return any(h == d or h.startswith(d.rstrip("/") + "/") for h in homes)

def area(d):
    found, cur = None, d
    while cur != "/":
        if os.path.lexists(os.path.join(cur, ".git")) and not at_or_above_home(cur):
            found = cur
        cur = os.path.dirname(cur)
    return found or d

def names(d):
    # Both names, with leading slashes cut to one (normpath keeps "//").
    return {"/" + os.path.normpath(d).lstrip("/"), os.path.realpath(d)}

areas = set()
for d in [cwd, os.environ.get("PWD", "")] + scan:
    if d.startswith("/"):
        areas |= {area(n) for n in names(d)}
# As the block: a start at $HOME or above it adds no area.
start = os.environ.get("ATLAS_START_DIR", "")
if start.startswith("/"):
    areas |= {a for a in (area(n) for n in names(start)) if not at_or_above_home(a)}

def in_area(path):
    return any(a == "/" or os.path.commonpath([a, p]) == a for a in areas
               for p in (os.path.normpath(path), os.path.realpath(path)))

git = shutil.which("git")
if git:
    # GIT_CONFIG reaches git config alone; the runner refused it, and it is
    # dropped here too, so the query reads the files the listing reads.
    env = {k: v for k, v in os.environ.items() if k != "GIT_CONFIG"}
    env["GIT_OPTIONAL_LOCKS"] = "0"
    for helper in ("GIT_ASKPASS", "SSH_ASKPASS", "GIT_SSH", "GIT_SSH_COMMAND", "GIT_TERMINAL_PROMPT", "GIT_EXTERNAL_DIFF"):
        env.pop(helper, None)
    env.update(GIT_NO_LAZY_FETCH="1", GIT_PROTOCOL_FROM_USER="0", GIT_ALLOW_PROTOCOL="")

    def git_output(args, root=None):
        try:
            res = subprocess.run([git] + (["-C", root] if root else []) + args, stdin=subprocess.DEVNULL,
                                 stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env, timeout=30)
        except (OSError, subprocess.SubprocessError):
            return None
        return res

    # Git before 2.45 ignores GIT_NO_LAZY_FETCH.
    old_git = True
    res = git_output(["--version"])
    if res is not None and res.returncode == 0:
        m = re.match(rb"git version (\d+)\.(\d+)", res.stdout)
        old_git = not m or (int(m.group(1)), int(m.group(2))) < (2, 45)

    def partial_clone(root):
        """A promisor remote: extensions.partialclone set, a
        partialclonefilter on a remote, or a remote.<name>.promisor that
        reads as true (a key with no value counts as true)."""
        res = git_output(["config", "-z", "--get-regexp", r"^(extensions\.partialclone|remote\..+\.(partialclonefilter|promisor))$"], root)
        if res is None or res.returncode not in (0, 1):
            return True
        for entry in res.stdout.decode("utf-8", "surrogateescape").split("\0"):
            key, nl, value = entry.partition("\n")
            if not key:
                continue
            if not key.lower().endswith(".promisor") or not nl or value.lower() in ("true", "yes", "on", "1"):
                return True
        return False

    seen = set()
    for root in [cwd] + scan:
        key = os.path.realpath(root)
        if key in seen:
            continue
        seen.add(key)
        if old_git and partial_clone(root):
            stop("%s is a partial clone, and the installed git is older than 2.45, which can still fetch a missing file from its promisor remote while Graphify lists the files; update git, or run /graphify in a full clone, then run /graphify again." % shown(root))
        for setting in ("core.fsmonitor",):
            try:
                res = subprocess.run([git, "-C", root, "config", "-z", "--show-scope", "--show-origin", "--get-all", setting],
                                     stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                     env=env, timeout=30)
            except (OSError, subprocess.SubprocessError):
                stop("cannot read the git configuration for %s; fix git, then run /graphify again." % shown(root))
            if res.returncode == 1:
                continue
            if res.returncode != 0:
                stop("cannot read the git configuration for %s; fix git, then run /graphify again." % shown(root))
            # With -z the output is scope NUL origin NUL value NUL, so a value
            # that holds a line break stays one value; it is compared exactly
            # as git reads it.
            fields = res.stdout.decode("utf-8", "surrogateescape").split("\0")
            if fields and fields[-1] == "":
                fields.pop()
            if len(fields) % 3:
                stop("cannot read the git configuration for %s; fix git, then run /graphify again." % shown(root))
            for scope, origin, value in zip(fields[0::3], fields[1::3], fields[2::3]):
                if value.lower() in OK_WORDS:
                    continue
                if scope in ("local", "worktree"):
                    stop("The git configuration of this repository sets %s, which git would run while Graphify lists the files; remove it (git config --unset-all %s) or set it to false, then run /graphify again." % (setting, setting))
                # A relative origin (a relative XDG_CONFIG_HOME or HOME) is
                # relative to the work-tree top git moved to, not to this
                # root; the own files of the operator are absolute, so it is unknown.
                cfg_file = origin[len("file:"):] if origin.startswith("file:") else ""
                if not cfg_file.startswith("/"):
                    stop("cannot tell where the git configuration for %s sets %s; fix git, then run /graphify again." % (shown(root), setting))
                if in_area(cfg_file):
                    stop("A git configuration file inside the repository (%s) sets %s, which git would run while Graphify lists the files; remove the setting from that file, or the variable that points git at it, then run /graphify again." % (pathname(shown(os.path.normpath(cfg_file))), setting))

out = os.path.join(cwd, "graphify-out")
outputs = []
for root in [out] + [os.path.join(s, "graphify-out") for s in scan]:
    if root not in outputs:
        outputs.append(root)
# Removed and written afresh below, so a symlink at any of them is no stop;
# --links writes nothing, so there every symlink is one.
state = {os.path.join(out, ".graphify_python"), os.path.join(out, ".graphify_root")}
state |= {os.path.join(root, ".graphify_build.json") for root in outputs}
if LINKS:
    state = set()
for root in outputs:
    chain(shown(root))
    if not os.path.lexists(root):
        continue
    if not os.path.isdir(root):
        stop("%s is not a directory; remove it, then run /graphify again." % shown(root))
    def unreadable(exc, root=root):
        stop("cannot read all of %s; fix its permissions, then run /graphify again." % shown(root))
    for dirpath, dirnames, filenames in os.walk(root, onerror=unreadable):
        for name in dirnames + filenames:
            path = os.path.join(dirpath, name)
            if os.path.islink(path) and path not in state:
                stop("%s is a symlink; remove it, then run /graphify again." % shown(path))

for root in outputs:
    config = os.path.join(root, ".graphify_build.json")
    if os.path.isdir(config) and not os.path.islink(config):
        stop("%s is a directory; remove it, then run /graphify again." % shown(config))

# The symlink gate (FR-031, "Symlinked inputs"; AC-125). Graphify 0.9.85
# runs its ignore, sensitivity and type checks on the path of a link, never
# on its target, and reads files inside detect itself (Office conversion,
# word counts) and inside its update. So, before anything is written or
# detected, each scan root is walked (os.walk, links not followed), skipping
# only the output roots. No directory is pruned by the ignored_predicate of
# Graphify: it also excludes a path by its name alone (_SKIP_FILES such as
# yarn.lock, an installed graphify.mdc), a directory included, where detect
# still walks that directory. Instead the predicate, under the build config
# of the pack, judges each symlink, ancestors included, as detect would.
# Every symlink it does not exclude is a candidate, a link to a directory and
# a dangling one included. A candidate passes only when its resolved target is
# a regular file under the scan root that git tracks as one (mode 100644 or
# 100755) and that Graphify would read on its own: not excluded, not
# sensitive, typed by classify_file, and no Google Workspace shortcut. Any
# other gets one line, naming the link from the scan root and never its
# target, and the run stops. A re-pin re-checks these Graphify functions.
GATE_GIT = "%s is a symlink to a file atlas won\x27t read through; remove the link, or add it to .graphifyignore."
GATE_NO_GIT = "%s is a symlink, and atlas follows none outside a git work tree; remove the link, or add it to .graphifyignore."

def printable(text):
    return "".join(c if c.isprintable() else "?" for c in text)

def git_tracked(root):
    """The paths under root, relative to it, that git tracks as regular
    files, from one git ls-files -s -z (no pathspec); None outside a git
    work tree or without a usable git. git comes from the cut PATH and runs
    as the shared script runs it: no optional locks, no fsmonitor."""
    import shutil, subprocess
    git = shutil.which("git")
    if not git:
        return None
    base = [git, "-C", root, "-c", "core.fsmonitor=false"]
    opts = {"stdin": subprocess.DEVNULL, "stdout": subprocess.PIPE, "stderr": subprocess.DEVNULL,
            "env": dict(os.environ, GIT_OPTIONAL_LOCKS="0")}
    try:
        probe = subprocess.run(base + ["rev-parse", "--is-inside-work-tree"], **opts)
        if probe.returncode != 0 or probe.stdout.strip() != b"true":
            return None
        listing = subprocess.run(base + ["ls-files", "-s", "-z"], **opts)
    except OSError:
        return None
    if listing.returncode != 0:
        return None
    tracked = set()
    for entry in listing.stdout.split(b"\0"):
        meta, tab, name = entry.partition(b"\t")
        if tab and meta.split(b" ", 1)[0] in (b"100644", b"100755"):
            tracked.add(name)
    return tracked

def symlinks(root, skip):
    """Every symlink under root, links not followed, outside the directories
    in skip."""
    links = []
    for dirpath, dirnames, filenames in os.walk(root):
        kept = []
        for name in dirnames:
            path = os.path.join(dirpath, name)
            if os.path.islink(path):
                links.append(path)
            elif path not in skip:
                kept.append(name)
        dirnames[:] = kept
        links += [p for p in (os.path.join(dirpath, n) for n in filenames) if os.path.islink(p)]
    return links

def gate():
    import stat
    from pathlib import Path
    skip = {os.path.realpath(o) for o in outputs}
    lines = []
    for given in scan:
        root = os.path.realpath(given)
        links = symlinks(root, skip)
        # A tree with no symlink passes without importing Graphify.
        if not links:
            continue
        try:
            from graphify.detect import GOOGLE_WORKSPACE_EXTENSIONS, _is_sensitive, classify_file, ignored_predicate
        except ImportError as exc:
            stop("the symlink gate cannot import what it needs from graphify.detect (%s); run \$atlas-doctor for the Graphify install line, then run /graphify again." % exc)
        predicate = ignored_predicate(Path(root), extra_excludes=list(BUILD_EXCLUDES), gitignore=BUILD_GITIGNORE)

        def excluded(path):
            return predicate(Path(path))

        links = [link for link in links if not excluded(link)]
        if not links:
            continue
        tracked = git_tracked(root)

        def passes(link):
            target = os.path.realpath(link)
            if tracked is None or target == root or os.path.commonpath([root, target]) != root:
                return False
            try:
                if not stat.S_ISREG(os.stat(target).st_mode):
                    return False
            except OSError:
                return False
            if os.fsencode(os.path.relpath(target, root)) not in tracked:
                return False
            t = Path(target)
            # classify_file last: it may read the opening text of the file.
            return (not excluded(t) and not _is_sensitive(t)
                    and t.suffix.lower() not in GOOGLE_WORKSPACE_EXTENSIONS and classify_file(t) is not None)

        line = GATE_NO_GIT if tracked is None else GATE_GIT
        lines += [line % printable(os.path.relpath(link, root)) for link in sorted(links) if not passes(link)]
    if lines:
        stop("\n".join(lines))

# --links runs before the update of the runner, and the update of Graphify
# 0.9.85 reads <path>/graphify-out/.graphify_build.json from disk (no file:
# no extra excludes), while the gate judges links under BUILD_CONFIG. So the
# update runs only on that config, byte for byte, as a full build or the
# --update guard leaves it; else a link the gate skips as excluded (under
# .archify/) could reach Graphify. Step 2 has already stopped on a symlink
# or a directory there.
CONFIG_LINE = ("%s is missing or isn\x27t the build config the atlas pack writes, so Graphify could skip other "
               "files than the symlink gate checked; run \$map-repo --update, which writes it first.")

def config_matches(path):
    import stat
    want = os.fsencode(BUILD_CONFIG)
    try:
        if not stat.S_ISREG(os.lstat(path).st_mode):
            return False
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | getattr(os, "O_NOFOLLOW", 0))
        try:
            return os.read(fd, len(want) + 1) == want
        finally:
            os.close(fd)
    except OSError:
        return False

if LINKS:
    for given in scan:
        config = os.path.join(given, "graphify-out", ".graphify_build.json")
        if not config_matches(config):
            stop(CONFIG_LINE % printable(shown(config)))

gate()
if LINKS:
    sys.exit(0)

try:
    for root in outputs:
        if not os.path.lexists(root):
            os.mkdir(root)
    for path in sorted(state):
        if os.path.lexists(path):
            os.unlink(path)
    values = os.path.join(out, ".graphify_values")
    if os.path.lexists(values):
        if not os.path.isdir(values):
            stop("graphify-out/.graphify_values is not a directory; remove it, then run /graphify again.")
        names = sorted(os.listdir(values))
        for name in names:
            if os.path.isdir(os.path.join(values, name)):
                stop("graphify-out/.graphify_values/%s is a directory; remove it, then run /graphify again." % name)
        for name in names:
            os.unlink(os.path.join(values, name))
    else:
        os.mkdir(values)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
    writes = [(os.path.join(out, ".graphify_python"), sys.executable),
              (os.path.join(out, ".graphify_root"), os.path.realpath(scan[0]))]
    writes += [(os.path.join(root, ".graphify_build.json"), BUILD_CONFIG) for root in outputs]
    for path, value in writes:
        fd = os.open(path, flags, 0o644)
        os.write(fd, os.fsencode(value))
        os.close(fd)
except OSError as exc:
    stop("cannot write the run-local state files in graphify-out (%s); fix it, then run /graphify again." % exc.strerror)
' $_GLINKS
