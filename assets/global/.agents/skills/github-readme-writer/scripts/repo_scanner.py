#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# ///
"""Scan a repository and print JSON context for writing its README.md.

Stdlib only. In a git work tree the file list comes from `git ls-files`
(tracked plus untracked-but-not-ignored), so ignored files such as `.env`
never appear. Outside git it falls back to a filesystem walk that skips
IGNORED_DIRS and `.env*` files.
"""

import argparse
import fnmatch
import json
import os
import subprocess
import sys
import tomllib
from pathlib import PurePosixPath
from urllib.parse import urlsplit, urlunsplit

DEFAULT_DEPTH = 2
MAX_DEPTH_MARKER = "... (max depth reached)"
GIT_TIMEOUT_SECONDS = 30

# Used only by the filesystem-walk fallback; git mode trusts .gitignore.
IGNORED_DIRS = {
    ".git", "node_modules", "__pycache__", ".venv", "venv", "env",
    "dist", "build", ".terraform", ".mypy_cache", ".pytest_cache",
}
IGNORED_FILE_GLOBS = (".env*",)


def _git(root_dir, *args):
    """Run a git command in root_dir. Returns stdout bytes, or None on any failure."""
    try:
        result = subprocess.run(
            ["git", "-C", root_dir, *args],
            capture_output=True,
            timeout=GIT_TIMEOUT_SECONDS,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return result.stdout if result.returncode == 0 else None


def is_git_work_tree(root_dir):
    out = _git(root_dir, "rev-parse", "--is-inside-work-tree")
    return out is not None and out.strip() == b"true"


def list_files_git(root_dir):
    """Paths relative to root_dir, from git (tracked + untracked, not ignored)."""
    out = _git(root_dir, "ls-files", "-z", "--cached", "--others", "--exclude-standard")
    if out is None:
        return None
    paths = set()
    for raw in out.split(b"\0"):
        if not raw:
            continue
        rel = os.fsdecode(raw)
        # --cached still lists files deleted from the work tree; skip those.
        if os.path.lexists(os.path.join(root_dir, rel)):
            paths.add(rel)
    return sorted(paths)


def list_files_walk(root_dir):
    """Paths relative to root_dir from os.walk, skipping IGNORED_DIRS and .env* files."""
    paths = []
    for current, dirs, files in os.walk(root_dir, onerror=lambda _err: None):
        dirs[:] = sorted(d for d in dirs if d not in IGNORED_DIRS)
        for name in sorted(files):
            if any(fnmatch.fnmatch(name, g) for g in IGNORED_FILE_GLOBS):
                continue
            rel = os.path.relpath(os.path.join(current, name), root_dir)
            paths.append(PurePosixPath(*rel.split(os.sep)).as_posix())
    return paths


def build_tree(paths, max_depth=DEFAULT_DEPTH):
    """Nested dict of the file list; directories at max_depth collapse to a marker."""
    tree = {}
    for rel in paths:
        parts = PurePosixPath(rel).parts
        node = tree
        for level, part in enumerate(parts, start=1):
            if level == len(parts):
                node.setdefault(part, "file")
                break
            if level == max_depth:
                node[part] = MAX_DEPTH_MARKER
                break
            child = node.get(part)
            if not isinstance(child, dict):
                child = node[part] = {}
            node = child
    return tree


def _matches(name, *globs):
    return any(fnmatch.fnmatch(name, g) for g in globs)


def detect_stack(paths):
    """Identify the stack from manifest and tooling files in the file list."""
    root_files = {p for p in paths if "/" not in p}
    names = [PurePosixPath(p).name for p in paths]
    stack = []

    def add(label, found):
        if found and label not in stack:
            stack.append(label)

    add("Node.js / NPM", "package.json" in root_files)
    add("Python", bool(root_files & {"requirements.txt", "pyproject.toml"}))
    add("Rust", "Cargo.toml" in root_files)
    add("Go", "go.mod" in root_files)
    add("Java", bool(root_files & {"pom.xml", "build.gradle", "build.gradle.kts"}))
    add("Conda", bool(root_files & {"environment.yml", "environment.yaml"}))
    add("Make", bool(root_files & {"Makefile", "GNUmakefile", "makefile"}))
    add("Docker", any(_matches(n, "Dockerfile", "Dockerfile.*", "*.dockerfile") for n in names))
    add("Docker Compose", any(_matches(n, "docker-compose*.y*ml", "compose*.y*ml") for n in names))
    add("Terraform", any(n.endswith(".tf") for n in names))
    add("Ansible", any(
        PurePosixPath(p).name == "ansible.cfg"
        or _matches(PurePosixPath(p).name, "playbook*.y*ml")
        or ("playbooks" in PurePosixPath(p).parts[:-1] and _matches(p, "*.yml", "*.yaml"))
        for p in paths
    ))
    return stack


def detect_scripts(root_dir, warnings):
    """Names of package.json `scripts` and pyproject `[project.scripts]` entries."""
    scripts = {"npm": [], "python": []}

    package_json = os.path.join(root_dir, "package.json")
    if os.path.isfile(package_json):
        try:
            with open(package_json, encoding="utf-8") as fh:
                data = json.load(fh)
            npm = data.get("scripts") if isinstance(data, dict) else None
            if isinstance(npm, dict):
                scripts["npm"] = sorted(str(k) for k in npm)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            warnings.append(f"package.json not parsed: {exc}")

    pyproject = os.path.join(root_dir, "pyproject.toml")
    if os.path.isfile(pyproject):
        try:
            with open(pyproject, "rb") as fh:
                data = tomllib.load(fh)
            project = data.get("project")
            py = project.get("scripts") if isinstance(project, dict) else None
            if isinstance(py, dict):
                scripts["python"] = sorted(str(k) for k in py)
        except (OSError, tomllib.TOMLDecodeError) as exc:
            warnings.append(f"pyproject.toml not parsed: {exc}")

    return scripts


def remote_url(root_dir):
    """`origin` remote URL with any embedded credentials removed, or None."""
    out = _git(root_dir, "remote", "get-url", "origin")
    if not out:
        return None
    url = out.decode("utf-8", "replace").strip()
    parts = urlsplit(url)
    if parts.scheme and "@" in parts.netloc:
        host = parts.netloc.rsplit("@", 1)[1]
        url = urlunsplit((parts.scheme, host, parts.path, parts.query, parts.fragment))
    return url or None


def main():
    parser = argparse.ArgumentParser(description="Scan a repository to extract context for a README.")
    parser.add_argument("--dir", type=str, default=".", help="Directory to scan (the repo root)")
    parser.add_argument("--depth", type=int, default=DEFAULT_DEPTH,
                        help=f"Max depth for the file tree (default {DEFAULT_DEPTH})")
    args = parser.parse_args()

    if args.depth < 1:
        parser.error("--depth must be 1 or more")

    root_dir = os.path.abspath(args.dir)
    if not os.path.isdir(root_dir):
        print(json.dumps({"error": f"Directory not found: {root_dir}"}))
        sys.exit(1)

    warnings = []
    in_git = is_git_work_tree(root_dir)
    paths = list_files_git(root_dir) if in_git else None
    if paths is None:
        if in_git:
            warnings.append("git ls-files failed; fell back to a filesystem walk")
        paths = list_files_walk(root_dir)
        source = "filesystem walk"
    else:
        source = "git ls-files"

    output = {
        "repository_path": root_dir,
        "detected_stack": detect_stack(paths),
        "file_tree": build_tree(paths, max_depth=args.depth),
        "file_source": source,
        "scripts": detect_scripts(root_dir, warnings),
        "remote_url": remote_url(root_dir) if in_git else None,
        "warnings": warnings,
        "advice_to_agent": "Use this structured directory and stack information to populate the README.md placeholders rather than hallucinating the context.",
    }

    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
