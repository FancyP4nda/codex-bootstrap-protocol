# The Codex configuration of the REA MCP server, read with tomllib (T053 round 7).
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


main()
