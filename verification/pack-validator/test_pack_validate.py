#!/usr/bin/env python3
"""Test matrix for pack_validate.py (T006, PRD FR-005 / AC-009 / AC-010).

Self-contained; no third-party test framework. Exit 0 iff every case passes.

Structure
---------
* **Violation matrix** — each FR-005 violation class has an isolated fixture: a
  copy of ``web-design-fixture-valid`` with exactly one documented mutation.
  Each asserts the class-specific violation fires (and, where the mutation is
  cleanly isolable, that NO other class fires). This is "one independent
  fixture per class" — generated deterministically rather than stored as ~10
  redundant on-disk pack trees.
* **Stamp / tamper matrix** — release-mode stamp write, no-stamp-in-test-mode,
  and the seven-way tamper matrix (each breaks stamp verification).
* **Bash parity** — the python whole-pack digest equals the FR-005 bash
  one-liner byte-for-byte.
* **T004 negative fixture** — ``web-design-fixture`` fails for its expected
  classes only.

Note on the accepted-risk class: its STRUCTURE (reason present, each deployment
condition fully mapped) is enforced by the JSON schema's conditional block, so
its isolated fixture fails at the schema layer naming ``accepted_risk``; the
validator's distinct release-time accepted-risk teeth are the evidence-root
verbatim comparison (its own class below). ``check_accepted_risk`` remains as
post-schema defense-in-depth.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

import yaml

_HERE = os.path.dirname(os.path.abspath(__file__))
_KIT_ROOT = os.path.abspath(os.path.join(_HERE, "..", ".."))
sys.path.insert(0, _HERE)

import pack_validate as v  # noqa: E402

FIXTURES = os.path.join(_KIT_ROOT, "verification", "fixtures")
VALID = os.path.join(FIXTURES, "packs", "web-design-fixture-valid")
EVIDENCE = os.path.join(FIXTURES, "evidence")
T004 = os.path.join(FIXTURES, "packs", "web-design-fixture")

_results: list[tuple[bool, str]] = []


def check(cond: bool, label: str) -> None:
    _results.append((bool(cond), label))
    print(("PASS" if cond else "FAIL") + ": " + label)


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

def _copy_valid(dst_parent: str) -> str:
    dst = os.path.join(dst_parent, "pack")
    shutil.copytree(VALID, dst)
    stamp = os.path.join(dst, v.STAMP_NAME)
    if os.path.isfile(stamp):
        os.remove(stamp)  # start from a clean, unstamped copy
    return dst


def _load_yaml(pack_dir: str) -> dict:
    with open(os.path.join(pack_dir, "pack.yaml"), "r", encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def _dump_yaml(pack_dir: str, data: dict) -> None:
    with open(os.path.join(pack_dir, "pack.yaml"), "w", encoding="utf-8") as fh:
        yaml.safe_dump(data, fh, sort_keys=False)


def _run(pack_dir: str, evidence_root: str | None = None) -> tuple[int, list[str]]:
    val = v.Validator(pack_dir, evidence_root, v.DEFAULT_SCHEMA, v.DEFAULT_ALLOWLIST)
    code = val.run()
    return code, val.violations


def _classes(violations: list[str]) -> set[str]:
    return {line.split(":", 1)[0] for line in violations}


# --------------------------------------------------------------------------
# Violation matrix — each case: (label, mutate_fn, expected_class, strict)
# strict=True asserts the expected class is the ONLY class that fires.
# --------------------------------------------------------------------------

def _mut_schema(pack_dir):
    d = _load_yaml(pack_dir)
    d["pack"]["name"] = "Bad Name"  # violates ^[a-z0-9][a-z0-9-]*$
    _dump_yaml(pack_dir, d)


def _mut_verdict(pack_dir):
    d = _load_yaml(pack_dir)
    d["components"][0]["verdict"] = "quarantined"
    _dump_yaml(pack_dir, d)


def _mut_evidence_null(pack_dir):
    d = _load_yaml(pack_dir)
    d["components"][0]["airlock_evidence_id"] = None
    _dump_yaml(pack_dir, d)


def _mut_hash(pack_dir):
    d = _load_yaml(pack_dir)
    d["components"][0]["vendored_tree_digest"] = "0" * 64
    _dump_yaml(pack_dir, d)


def _mut_docs_null(pack_dir):
    d = _load_yaml(pack_dir)
    d["pack"]["mission_guide"] = None
    _dump_yaml(pack_dir, d)


def _mut_docs_absent(pack_dir):
    d = _load_yaml(pack_dir)
    d["pack"]["mission_guide"] = "docs/does-not-exist.md"
    _dump_yaml(pack_dir, d)


def _mut_license_unlisted(pack_dir):
    d = _load_yaml(pack_dir)
    d["components"][0]["license"] = "GPL-3.0-only"
    _dump_yaml(pack_dir, d)


def _mut_license_expression(pack_dir):
    d = _load_yaml(pack_dir)
    d["components"][0]["license"] = "MIT OR GPL-3.0-only"
    _dump_yaml(pack_dir, d)


def _mut_license_licenseref(pack_dir):
    d = _load_yaml(pack_dir)
    d["components"][0]["license"] = "LicenseRef-Proprietary"
    _dump_yaml(pack_dir, d)


def _mut_ownership_zero(pack_dir):
    with open(os.path.join(pack_dir, "scaffold", "orphan.txt"), "w") as fh:
        fh.write("owned by nobody\n")


def _mut_ownership_two(pack_dir):
    d = _load_yaml(pack_dir)
    # A vendored file also declared as pack-authored -> two owners.
    d["pack"]["pack_paths"].append(".agents/skills/web-design/SKILL.md")
    _dump_yaml(pack_dir, d)


def _mut_accepted_risk(pack_dir):
    d = _load_yaml(pack_dir)
    del d["components"][0]["accepted_risk"]  # verdict stays pass-with-accepted-risk
    _dump_yaml(pack_dir, d)


def _mut_dep_audit_adjudication(pack_dir):
    d = _load_yaml(pack_dir)
    d["components"][1]["dependency_audit"]["adjudication"] = "pending"
    _dump_yaml(pack_dir, d)


def _mut_dep_audit_lockfile(pack_dir):
    lock = os.path.join(pack_dir, "scaffold", ".codex", "mcp", "web-design-mcp", "package-lock.json")
    import json
    with open(lock, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    data["packages"]["node_modules/evil"] = {
        "version": "1.0.0",
        "resolved": "git+https://example.invalid/evil.git",
        "git": True,
    }
    with open(lock, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)
    # Recompute the mcp digest so ONLY dep-audit fires (isolate from hash).
    d = _load_yaml(pack_dir)
    digest = v.component_tree_digest(os.path.join(pack_dir, "scaffold"),
                                     d["components"][1]["vendored_paths"])
    d["components"][1]["content_hash"] = digest
    d["components"][1]["vendored_tree_digest"] = digest
    _dump_yaml(pack_dir, d)


def _mut_top_level(pack_dir):
    with open(os.path.join(pack_dir, "EXTRA.txt"), "w") as fh:
        fh.write("not allowlisted\n")


VIOLATION_CASES = [
    ("schema",             _mut_schema,               "schema",        True),
    ("verdict-quarantined", _mut_verdict,             "verdict",       True),
    ("evidence-null",      _mut_evidence_null,         "evidence-null", True),
    ("hash-mismatch",      _mut_hash,                  "hash",          True),
    ("docs-null",          _mut_docs_null,             "docs",          True),
    ("docs-absent",        _mut_docs_absent,           "docs",          True),
    ("license-unlisted",   _mut_license_unlisted,      "license",       True),
    ("license-expression", _mut_license_expression,    "license",       True),
    ("license-licenseref", _mut_license_licenseref,    "license",       True),
    ("ownership-zero",     _mut_ownership_zero,        "ownership",     True),
    ("ownership-two",      _mut_ownership_two,         "ownership",     True),
    ("accepted-risk(schema)", _mut_accepted_risk,      "schema",        True),
    ("dep-audit-adjudication", _mut_dep_audit_adjudication, "dep-audit", True),
    ("dep-audit-lockfile", _mut_dep_audit_lockfile,    "dep-audit",     True),
    ("top-level-allowlist", _mut_top_level,            "top-level",     True),
]


def run_violation_matrix() -> None:
    for label, mutate, expected, strict in VIOLATION_CASES:
        with tempfile.TemporaryDirectory() as tmp:
            pack = _copy_valid(tmp)
            mutate(pack)
            code, violations = _run(pack)
            classes = _classes(violations)
            ok = code == 1 and expected in classes
            if strict:
                ok = ok and classes == {expected}
            if label == "accepted-risk(schema)":
                ok = ok and any("accepted_risk" in x for x in violations)
            check(ok, "violation[%s] -> class %r (got %s, exit %d)"
                  % (label, expected, sorted(classes), code))


# --------------------------------------------------------------------------
# Evidence-root class
# --------------------------------------------------------------------------

def run_evidence_root_case() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        pack = _copy_valid(tmp)
        wrong = os.path.join(tmp, "wrong-evidence")
        os.makedirs(wrong)
        code, violations = _run(pack, evidence_root=wrong)
        classes = _classes(violations)
        check(code == 1 and classes == {"evidence-root"},
              "violation[evidence-root] -> class 'evidence-root' (got %s, exit %d)"
              % (sorted(classes), code))


# --------------------------------------------------------------------------
# Stamp / tamper matrix
# --------------------------------------------------------------------------

def run_stamp_matrix() -> None:
    # Test-mode pass writes NO stamp.
    with tempfile.TemporaryDirectory() as tmp:
        pack = _copy_valid(tmp)
        code, _ = _run(pack)
        check(code == 0 and not os.path.isfile(os.path.join(pack, v.STAMP_NAME)),
              "test-mode pass writes NO stamp (stamp-bypass path closed)")

    # Release-mode pass writes the stamp and it verifies.
    with tempfile.TemporaryDirectory() as tmp:
        pack = _copy_valid(tmp)
        code, violations = _run(pack, evidence_root=EVIDENCE)
        stamped = os.path.isfile(os.path.join(pack, v.STAMP_NAME))
        check(code == 0 and stamped and v.verify_stamp(pack),
              "release-mode pass writes the sole stamp and it verifies (viol=%s)" % violations)


TAMPERS = {
    "content-edit": lambda p: _append(os.path.join(p, "scaffold", ".agents", "skills", "web-design", "SKILL.md"), "x"),
    "file-rename": lambda p: os.rename(
        os.path.join(p, "scaffold", ".agents", "skills", "web-design", "SKILL.md"),
        os.path.join(p, "scaffold", ".agents", "skills", "web-design", "SKILL2.md")),
    "file-add": lambda p: _append(os.path.join(p, "scaffold", "added.txt"), "new"),
    "file-delete": lambda p: os.remove(os.path.join(p, "scaffold", ".agents", "skills", "web-design", "SKILL.md")),
    "empty-file-swap": lambda p: _truncate(os.path.join(p, "scaffold", ".agents", "skills", "web-design", "SKILL.md")),
    "verdict-flip": lambda p: _flip_verdict(p),
    "manifest-edit": lambda p: _append(os.path.join(p, "manifest.txt"), "# tamper\n"),
}


def _append(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(text)


def _truncate(path):
    open(path, "w").close()


def _flip_verdict(pack_dir):
    d = _load_yaml(pack_dir)
    d["components"][1]["verdict"] = "quarantined"
    _dump_yaml(pack_dir, d)


def run_tamper_matrix() -> None:
    for name, tamper in TAMPERS.items():
        with tempfile.TemporaryDirectory() as tmp:
            pack = _copy_valid(tmp)
            code, _ = _run(pack, evidence_root=EVIDENCE)
            assert code == 0 and v.verify_stamp(pack), "setup: stamp should verify before tamper"
            tamper(pack)
            check(not v.verify_stamp(pack), "tamper[%s] invalidates the stamp" % name)


# --------------------------------------------------------------------------
# Bash-parity + T004 negative fixture
# --------------------------------------------------------------------------

def run_bash_parity() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        pack = _copy_valid(tmp)
        _run(pack, evidence_root=EVIDENCE)  # stamp it (excluded from digest)
        py_digest = v.whole_pack_digest(pack)
        one_liner = (
            "cd %s && find manifest.txt pack.yaml scaffold -type f ! -name %s "
            "-print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum"
            % (pack, v.STAMP_NAME)
        )
        out = subprocess.check_output(["bash", "-c", one_liner], text=True)
        bash_digest = out.split()[0]
        check(py_digest == bash_digest,
              "bash one-liner reproduces the whole-pack digest byte-for-byte")


def run_t004_negative() -> None:
    code, violations = _run(T004)
    classes = _classes(violations)
    expected_only = {"evidence-null", "hash", "docs"}
    check(code == 1 and classes <= expected_only and classes,
          "T004 fixture fails for expected classes only (got %s)" % sorted(classes))


def run_kit_authored_case() -> None:
    """A pack with no vendored components validates when pack_paths owns the scaffold."""
    with tempfile.TemporaryDirectory() as tmp:
        pack = os.path.join(tmp, "kit-authored")
        guide = os.path.join(pack, "scaffold", ".agents", "skills", "demo")
        os.makedirs(guide)
        for name in ("SKILL.md", "NOTES.md", "RULES.md"):
            with open(os.path.join(guide, name), "w", encoding="utf-8") as fh:
                fh.write("# %s\n" % name)
        with open(os.path.join(pack, "manifest.txt"), "w", encoding="utf-8") as fh:
            fh.write("file\t.agents/skills/demo/SKILL.md\tcopy\tDemo.\n")
        _dump_yaml(pack, {
            "pack": {
                "name": "kit-authored",
                "description": "Kit-authored pack with no vendored components.",
                "mission_guide": ".agents/skills/demo/SKILL.md",
                "component_notes": ".agents/skills/demo/NOTES.md",
                "rules_file": ".agents/skills/demo/RULES.md",
                "pack_paths": [".agents/skills/demo/"],
            },
            "components": [],
        })
        code, violations = _run(pack)
        check(code == 0 and not violations,
              "kit-authored pack with components: [] passes (got %s)" % violations)


# --------------------------------------------------------------------------

def main() -> int:
    run_violation_matrix()
    run_evidence_root_case()
    run_stamp_matrix()
    run_tamper_matrix()
    run_bash_parity()
    run_t004_negative()
    run_kit_authored_case()

    total = len(_results)
    failed = [label for ok, label in _results if not ok]
    print("\n%d/%d checks passed." % (total - len(failed), total))
    if failed:
        print("FAILURES:")
        for label in failed:
            print("  - " + label)
        return 1
    print("Validator verification passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
