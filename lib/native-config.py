#!/usr/bin/env python3
"""Pure candidate generation, parsed preservation and installer metadata helpers.

No third-party dependencies. TOML edits preserve untouched bytes and comments;
unusual key/table layouts fail closed instead of guessing at a rewrite.
"""
import argparse
import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import sys
import tomllib

STATUS_LINE = ["model-with-reasoning", "context-remaining", "git-branch", "current-dir"]
BEGIN = "<!-- BEGIN CODEX BOOTSTRAP -->"
END = "<!-- END CODEX BOOTSTRAP -->"
# These are merged user-owned documents, not exclusively owned core payloads.
# The legacy release put them in `managed`; normalize that format conservatively
# before making any retirement decision. Omission of a flag is never uninstall.
# These paths are relative to CODEX_HOME, the only configuration layer passed
# to global retirement. Project `managed` remains the compatible installation
# inventory (including .codex/config.toml); project files are never retired.
CONFIGURATION_FILES = {"config.toml", "hooks.json"}
OPTIONAL_MANAGED_FILES = {"hooks/session-context.py"}
CONFIGURATION_OPTIONS = {"status-line", "notifications", "hooks", "docs-mcp"}


def read(path):
    p = Path(path)
    if p.is_symlink():
        raise ValueError(f"symlink configuration: {p}")
    return p.read_text() if p.exists() else ""


def merge_instructions(existing, incoming):
    if existing.count(BEGIN) != existing.count(END) or existing.count(BEGIN) > 1:
        raise ValueError("malformed managed AGENTS.md section; reconcile markers first")
    section = incoming[incoming.index(BEGIN):incoming.index(END)+len(END)]
    if BEGIN in existing:
        if existing.index(END) < existing.index(BEGIN):
            raise ValueError("reversed AGENTS.md markers")
        return existing[:existing.index(BEGIN)] + section + existing[existing.index(END)+len(END):]
    return existing.rstrip() + "\n\n" + section + "\n" if existing else incoming


def merge_ignore(existing, incoming):
    lines = existing.splitlines()
    missing = [s for s in incoming.splitlines() if s and not s.startswith("#") and s not in lines]
    return existing + (("\n" if existing and not existing.endswith("\n") else "") +
                       "\n".join(missing) + "\n" if missing else "")


def set_key(text, table, key, value):
    data = tomllib.loads(text)
    section = data
    for part in table.split("."):
        section = section.get(part, {})
        if not isinstance(section, dict):
            raise ValueError(f"{table} is not a table; reconcile configuration manually")
    if section.get(key) == value:
        return text
    literal = json.dumps(value) if not isinstance(value, bool) else str(value).lower()
    headers = list(re.finditer(r"(?m)^\s*\[[^\n]+\]\s*(?:#[^\n]*)?$", text))
    wanted = [h for h in headers if h.group().split("#", 1)[0].strip() == f"[{table}]"]
    if not wanted:
        # Dotted/quoted/inline forms must not produce a duplicate semantic table.
        if section:
            raise ValueError(f"nonstandard {table} layout; use a normal [{table}] table for targeted updates")
        candidate = text.rstrip() + f"\n\n[{table}]\n{key} = {literal}\n"
    else:
        start = wanted[0].end()
        end = next((h.start() for h in headers if h.start() > start), len(text))
        body = text[start:end]
        matches = list(re.finditer(r"(?m)^(\s*"+re.escape(key)+r"\s*=\s*)(.*)$", body))
        if len(matches) > 1:
            raise ValueError(f"duplicate assignment for {table}.{key}")
        if matches:
            m = matches[0]
            old = m.group(2)
            # Single-line literals are safe to replace; retain their inline comment.
            try:
                tomllib.loads("v = " + old)
            except tomllib.TOMLDecodeError as exc:
                raise ValueError(f"multiline {table}.{key}; reconcile this key manually") from exc
            comment = re.search(r'\s+#.*$', old)
            replacement = m.group(1) + literal + (comment.group() if comment else "")
            body = body[:m.start()] + replacement + body[m.end():]
        else:
            if key in section:
                raise ValueError(f"quoted/dotted {table}.{key}; reconcile this key manually")
            body = "\n" + f"{key} = {literal}\n" + body.lstrip("\n")
        candidate = text[:start] + body + text[end:]
    parsed = tomllib.loads(candidate)
    before = json.loads(json.dumps(data))
    after = json.loads(json.dumps(parsed))
    for obj in (before, after):
        cur = obj
        for part in table.split("."):
            cur = cur.setdefault(part, {})
        cur.pop(key, None)
    if before != after:
        raise ValueError(f"targeted update changed unrelated settings: {table}.{key}")
    return candidate


def config_candidate(text, status=False, notifications=False, docs_mcp=False):
    tomllib.loads(text)
    if status:
        text = set_key(text, "tui", "status_line", STATUS_LINE)
    if notifications:
        text = set_key(text, "tui", "notifications", True)
    if docs_mcp:
        existing = tomllib.loads(text).get("mcp_servers", {}).get("openai_docs", {})
        if existing and existing.get("url") != "https://developers.openai.com/mcp":
            raise ValueError("openai_docs MCP name collision; rename the existing integration")
        text = set_key(text, "mcp_servers.openai_docs", "url", "https://developers.openai.com/mcp")
    return text


def hooks_candidate(text, command, config):
    if tomllib.loads(config).get("hooks"):
        raise ValueError("inline hooks already exist; choose one representation in this layer before enabling bootstrap hooks")
    data = json.loads(text) if text else {"hooks": {}}
    if not isinstance(data, dict) or not isinstance(data.get("hooks", {}), dict):
        raise ValueError("hooks.json must contain an object of event arrays")
    hooks = data.setdefault("hooks", {})
    handlers = hooks.setdefault("SessionStart", [])
    if not isinstance(handlers, list):
        raise ValueError("SessionStart hooks must be an array")
    marker = "Codex bootstrap orientation"
    for entry in handlers:
        if not isinstance(entry, dict) or not isinstance(entry.get("hooks"), list):
            raise ValueError("invalid existing SessionStart hook group")
    retained = []
    for entry in handlers:
        own = [h for h in entry["hooks"] if h.get("statusMessage") == marker]
        if own:
            other = [h for h in entry["hooks"] if h.get("statusMessage") != marker]
            if other:
                retained.append({**entry, "hooks": other})
        else:
            retained.append(entry)
    retained.append({"matcher": "startup|resume|clear|compact", "hooks": [
        {"type": "command", "command": command, "timeout": 10,
         "statusMessage": marker, "additionalContextLimit": 5000}]})
    hooks["SessionStart"] = retained
    return json.dumps(data, indent=2) + "\n"


def load_stamp(path):
    text = read(path)
    if not text:
        return {"format": 1, "managed": {}}
    value = json.loads(text)
    if not isinstance(value, dict) or value.get("format") != 1 or not isinstance(value.get("managed"), dict):
        raise ValueError(f"unknown bootstrap metadata format: {path}")
    for category in ("managed", "configuration", "optional_managed"):
        entries = value.setdefault(category, {})
        if not isinstance(entries, dict):
            raise ValueError(f"unsafe {category} metadata: {path}")
        for rel, digest in entries.items():
            parts = Path(rel).parts
            if Path(rel).is_absolute() or ".." in parts or not parts or not isinstance(digest,str) or not re.fullmatch(r"[a-f0-9]{64}", digest):
                raise ValueError(f"unsafe managed stamp entry: {rel}")
            if category == "configuration" and rel not in CONFIGURATION_FILES:
                raise ValueError(f"unknown merged configuration entry: {rel}")
            if category == "optional_managed" and rel not in OPTIONAL_MANAGED_FILES:
                raise ValueError(f"unknown optional managed entry: {rel}")
    for rel in CONFIGURATION_FILES:
        if rel in value["managed"]:
            value["configuration"].setdefault(rel, value["managed"].pop(rel))
    for rel in OPTIONAL_MANAGED_FILES:
        if rel in value["managed"]:
            value["optional_managed"].setdefault(rel, value["managed"].pop(rel))
    options = value.setdefault("configuration_options", [])
    if not isinstance(options, list) or any(not isinstance(option, str) or option not in CONFIGURATION_OPTIONS for option in options):
        raise ValueError(f"unsafe configuration options metadata: {path}")
    if value.get("core_mode", "global") not in ("global", "local"):
        raise ValueError(f"unsafe core mode metadata: {path}")
    packs = value.get("packs", [])
    if not isinstance(packs,list) or any(p not in ("falcon","herald","web-design") for p in packs):
        raise ValueError(f"unsafe pack metadata: {path}")
    return value


def hash_file(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def hook_health(root):
    """Inspect our configured handler without executing arbitrary commands/trusting it."""
    text = read(Path(root)/"hooks.json")
    config = read(Path(root)/"config.toml")
    documents = []
    if text:
        documents.append(("hooks.json", json.loads(text)))
    if config:
        documents.append(("config.toml", tomllib.loads(config)))
    if not any("hooks" in data for _, data in documents if isinstance(data, dict)):
        if any(not isinstance(data, dict) for _, data in documents):
            raise ValueError(f"invalid hooks document object at {root}")
        return f"Optional orientation hook at {root}: not configured; trust/execution not inferred.\n"
    own = []
    events = []
    for filename, data in documents:
        if not isinstance(data, dict) or not isinstance(data.get("hooks", {}), dict):
            raise ValueError(f"invalid hooks object in {filename} at {root}")
        events.extend(data.get("hooks", {}).items())
    for event, groups in events:
        if not isinstance(groups, list):
            raise ValueError(f"invalid {event} hooks at {root}: expected an array")
        for group in groups:
            if not isinstance(group, dict) or not isinstance(group.get("hooks"), list):
                raise ValueError(f"invalid {event} hook group at {root}")
            if "matcher" in group and not isinstance(group["matcher"], str):
                raise ValueError(f"invalid {event} hook matcher at {root}")
            for handler in group["hooks"]:
                if not isinstance(handler, dict):
                    raise ValueError(f"invalid {event} hook handler at {root}")
                kind = handler.get("type")
                if kind not in ("command", "mcp_tool", "prompt", "agent"):
                    raise ValueError(f"unsupported {event} hook type at {root}")
                required = ("command",) if kind == "command" else ("server", "tool") if kind == "mcp_tool" else ("prompt",)
                for key in required:
                    if not isinstance(handler.get(key), str) or not handler[key].strip():
                        raise ValueError(f"invalid {event} hook {key} at {root}: expected a nonempty string")
                if event == "SessionStart" and handler.get("statusMessage") == "Codex bootstrap orientation":
                    own.append(handler)
    if not own:
        return f"Optional orientation hook at {root}: not configured; existing user hooks preserved.\n"
    for handler in own:
        command = handler.get("command", "")
        if not isinstance(command, str):
            raise ValueError(f"invalid bootstrap orientation command at {root}")
        words = shlex.split(command)
        helper = Path(root)/"hooks/session-context.py"
        if str(helper) in words and (helper.is_symlink() or not helper.is_file()):
            raise ValueError(f"configured orientation helper missing/unsafe: {helper}; rerun bootstrap --hooks in this layer")
    return f"Optional orientation hook at {root}: configured; trust/execution UNKNOWN. Review /hooks; no handler was run.\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["instructions", "ignore", "config", "hooks", "record", "obsolete", "prefix", "check", "core-mode", "hook-health", "retained-helpers"])
    parser.add_argument("path")
    parser.add_argument("extra", nargs="*")
    parser.add_argument("--status-line", action="store_true")
    parser.add_argument("--notifications", action="store_true")
    parser.add_argument("--docs-mcp", action="store_true")
    parser.add_argument("--configuration-option", action="append", choices=sorted(CONFIGURATION_OPTIONS), default=[])
    parser.add_argument("--core-mode", choices=["global", "local"])
    args = parser.parse_args()
    if args.mode == "instructions":
        result = merge_instructions(read(args.path), read(args.extra[0]))
    elif args.mode == "ignore":
        result = merge_ignore(read(args.path), read(args.extra[0]))
    elif args.mode == "config":
        result = config_candidate(read(args.path), args.status_line, args.notifications, args.docs_mcp)
    elif args.mode == "hooks":
        result = hooks_candidate(read(args.path), args.extra[0], read(args.extra[1]))
    elif args.mode == "prefix":
        words = re.findall(r"[A-Za-z0-9]+", Path(args.path).name)
        result = "".join(w[0].upper() for w in words) or "PROJECT"
    elif args.mode == "check":
        load_stamp(args.path)
        return
    elif args.mode == "core-mode":
        stamp = load_stamp(args.path)
        result = "local" if stamp.get("core_mode") == "local" or (
            ".agents/skills/session-start/SKILL.md" in stamp["managed"]) else "global"
    elif args.mode == "hook-health":
        result = hook_health(args.path)
    elif args.mode == "retained-helpers":
        result = "".join(rel+"\n" for rel in sorted(load_stamp(args.path).get("optional_managed", {})))
    elif args.mode == "obsolete":
        stamp = load_stamp(args.path)
        current = set(sys.stdin.read().splitlines())
        for rel, digest in stamp["managed"].items():
            if rel not in current:
                p = Path(args.extra[0]) / rel
                if p.is_file() and not p.is_symlink():
                    print(("remove" if hash_file(p) == digest else "keep_modified")+"\t"+rel+"\t"+digest)
        return
    else:
        stamp = load_stamp(args.path)
        # Input rows use relative paths in this stamp's layer, state, absolute file.
        for line in sys.stdin:
            rel, state, full = line.rstrip("\n").split("\t")
            if state == "remove":
                stamp["managed"].pop(rel, None)
            elif state in ("create", "overwrite", "identical") and Path(full).is_file():
                category = ("configuration" if rel in CONFIGURATION_FILES else
                            "optional_managed" if rel in OPTIONAL_MANAGED_FILES else "managed")
                stamp.setdefault(category, {})[rel] = hash_file(full)
        packs = list(dict.fromkeys([*stamp.get("packs", []), *args.extra[1:]]))
        stamp.update({"format": 1, "version": "1.0.0", "source_commit": args.extra[0], "packs": packs})
        stamp["configuration_options"] = list(dict.fromkeys([
            *stamp.get("configuration_options", []), *args.configuration_option]))
        if args.core_mode:
            stamp["core_mode"] = args.core_mode
        result = json.dumps(stamp, indent=2, sort_keys=True) + "\n"
    sys.stdout.write(result)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, IndexError) as exc:
        print(f"bootstrap: {exc}; nothing applied by native-config helper", file=sys.stderr)
        sys.exit(2)
