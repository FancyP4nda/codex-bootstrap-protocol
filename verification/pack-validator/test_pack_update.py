#!/usr/bin/env python3
"""Test matrix for pack_update.py (T016, PRD FR-008 / AC-016 / AC-017).

Self-contained; exit 0 iff every case passes. All cases run on a temp copy of
web-design-fixture-valid with a gate environment (staging evidence + promoted
trees) constructed on the fly, so no gate-side digests are checked in.

Proves the three FR-008 outcome paths end-to-end on the validator-passing
fixture variant:
* updated     — adjudicated pass re-vendors, refreshes pin/evidence/hashes, and
                the pack re-validates to a stamp.
* quarantined — adjudicated fail flips verdict to quarantined with a
                byte-identical vendored tree, removes the stamp, and the
                validator then refuses release.
* no-change   — scanner error / pending changes nothing (stamp included).

Plus the invariants: vendored bytes are edited ONLY on the promoted pass, and a
mutation that would yield a schema-invalid pack.yaml is refused before any write.
"""

from __future__ import annotations

import os
import shutil
import sys
import tempfile

import yaml

_HERE = os.path.dirname(os.path.abspath(__file__))
_KIT_ROOT = os.path.abspath(os.path.join(_HERE, "..", ".."))
sys.path.insert(0, _HERE)

import pack_validate as pv  # noqa: E402
import pack_update as pu  # noqa: E402

FIXTURES = os.path.join(_KIT_ROOT, "verification", "fixtures")
VALID = os.path.join(FIXTURES, "packs", "web-design-fixture-valid")
EVIDENCE = os.path.join(FIXTURES, "evidence")

_results: list[tuple[bool, str]] = []


def check(cond: bool, label: str) -> None:
    _results.append((bool(cond), label))
    print(("PASS" if cond else "FAIL") + ": " + label)


def _copy_valid(parent: str) -> str:
    dst = os.path.join(parent, "pack")
    shutil.copytree(VALID, dst)
    stamp = os.path.join(dst, pv.STAMP_NAME)
    if os.path.isfile(stamp):
        os.remove(stamp)
    return dst


def _load(pack_dir: str) -> dict:
    with open(os.path.join(pack_dir, "pack.yaml"), "r", encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def _component(pack_dir: str, cid: str) -> dict:
    return next(c for c in _load(pack_dir)["components"] if c["id"] == cid)


def _make_gate(parent: str) -> tuple[str, str]:
    staging = os.path.join(parent, "staging-evidence")
    promoted = os.path.join(parent, "promoted")
    os.makedirs(staging)
    os.makedirs(promoted)
    return staging, promoted


def _write_evidence(staging: str, cid: str, data: dict) -> None:
    with open(os.path.join(staging, "%s.yaml" % cid), "w", encoding="utf-8") as fh:
        yaml.safe_dump(data, fh, sort_keys=False)


def _build_promoted_from_scaffold(pack_dir: str, promoted: str, cid: str,
                                  vendored_paths: list[str], mutate=None) -> str:
    """Copy the component's current scaffold subtree into the promoted root,
    optionally mutating it. Returns the digest the command will compute after
    re-vendoring (so evidence content_hash can be made consistent)."""
    scaffold = os.path.join(pack_dir, "scaffold")
    comp_root = os.path.join(promoted, cid)
    for vp in vendored_paths:
        rel = vp.strip("/")
        shutil.copytree(os.path.join(scaffold, rel), os.path.join(comp_root, rel))
    if mutate is not None:
        mutate(comp_root)
    return pv.component_tree_digest(comp_root, vendored_paths)


# --------------------------------------------------------------------------
# Case 1: updated (adjudicated promoted pass)
# --------------------------------------------------------------------------

def case_updated() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        pack = _copy_valid(tmp)
        staging, promoted = _make_gate(tmp)
        cid = "web-design-skill"
        vps = _component(pack, cid)["vendored_paths"]

        def mutate(root):  # prove re-vendoring actually replaces bytes
            f = os.path.join(root, ".agents", "skills", "web-design", "SKILL.md")
            with open(f, "a", encoding="utf-8") as fh:
                fh.write("\n<!-- promoted revision -->\n")

        new_digest = _build_promoted_from_scaffold(pack, promoted, cid, vps, mutate)
        _write_evidence(staging, cid, {
            "adjudication": "accepted",
            "verdict": "pass-with-accepted-risk",
            "airlock_evidence_id": "evidence-refreshed-001",
            "engine_pin": "fixture-scanner@2.0.0",
            "scan_date": "2026-07-23",
            "content_hash": new_digest,
            "pinned_commit": "2222222222222222222222222222222222222222",
        })

        # stamp the pack first so we can prove the write path removes it
        pv.Validator(pack, EVIDENCE, pv.DEFAULT_SCHEMA, pv.DEFAULT_ALLOWLIST).run()
        report = pu.update(pack, cid, staging, promoted, gate_root=None)

        comp = _component(pack, cid)
        scaffold_file = os.path.join(pack, "scaffold", ".agents", "skills", "web-design", "SKILL.md")
        revendored = "promoted revision" in open(scaffold_file).read()
        refreshed = (comp["pinned_commit"] == "2222222222222222222222222222222222222222"
                     and comp["airlock_evidence_id"] == "evidence-refreshed-001"
                     and comp["engine_pin"] == "fixture-scanner@2.0.0"
                     and comp["scan_date"] == "2026-07-23"
                     and comp["content_hash"] == new_digest
                     and comp["vendored_tree_digest"] == new_digest)
        no_stamp = not os.path.isfile(os.path.join(pack, pv.STAMP_NAME))
        check(report["outcome"] == pu.UPDATED and revendored and refreshed and no_stamp,
              "updated: re-vendors, refreshes pin/evidence/hashes, removes stamp")

        # and the refreshed pack re-validates to a fresh stamp
        code = pv.Validator(pack, EVIDENCE, pv.DEFAULT_SCHEMA, pv.DEFAULT_ALLOWLIST).run()
        check(code == 0 and pv.verify_stamp(pack),
              "updated: refreshed pack re-validates release-mode to a stamp")


# --------------------------------------------------------------------------
# Case 2: quarantined (adjudicated fail)
# --------------------------------------------------------------------------

def case_quarantined() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        pack = _copy_valid(tmp)
        staging, promoted = _make_gate(tmp)
        cid = "web-design-mcp"
        vps = _component(pack, cid)["vendored_paths"]

        before_digest = pv.component_tree_digest(os.path.join(pack, "scaffold"), vps)
        _write_evidence(staging, cid, {"adjudication": "rejected", "verdict": "fail"})

        pv.Validator(pack, EVIDENCE, pv.DEFAULT_SCHEMA, pv.DEFAULT_ALLOWLIST).run()  # stamp it
        report = pu.update(pack, cid, staging, promoted, gate_root=None)

        comp = _component(pack, cid)
        after_digest = pv.component_tree_digest(os.path.join(pack, "scaffold"), vps)
        no_stamp = not os.path.isfile(os.path.join(pack, pv.STAMP_NAME))
        check(report["outcome"] == pu.QUARANTINED and comp["verdict"] == "quarantined"
              and before_digest == after_digest and no_stamp,
              "quarantined: verdict flipped, vendored tree byte-identical, stamp removed")

        code = pv.Validator(pack, EVIDENCE, pv.DEFAULT_SCHEMA, pv.DEFAULT_ALLOWLIST).run()
        check(code == 1, "quarantined: validator then refuses release (verdict quarantined)")


# --------------------------------------------------------------------------
# Case 3: no-change (scanner error / pending)
# --------------------------------------------------------------------------

def case_no_change() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        pack = _copy_valid(tmp)
        staging, promoted = _make_gate(tmp)
        cid = "web-design-mcp"

        pv.Validator(pack, EVIDENCE, pv.DEFAULT_SCHEMA, pv.DEFAULT_ALLOWLIST).run()  # stamp it
        pack_yaml_before = open(os.path.join(pack, "pack.yaml"), "rb").read()
        stamp_digest_before = pv.read_stamp_digest(pack)

        _write_evidence(staging, cid, {"adjudication": "pending", "verdict": "pass"})
        report = pu.update(pack, cid, staging, promoted, gate_root=None)

        pack_yaml_after = open(os.path.join(pack, "pack.yaml"), "rb").read()
        stamp_intact = pv.read_stamp_digest(pack) == stamp_digest_before and pv.verify_stamp(pack)
        check(report["outcome"] == pu.NO_CHANGE and pack_yaml_before == pack_yaml_after
              and stamp_intact,
              "no-change: pending adjudication touches nothing (pack.yaml + stamp intact)")

        # absent evidence file is also no-change
        report2 = pu.update(pack, "web-design-skill", staging, promoted, gate_root=None)
        check(report2["outcome"] == pu.NO_CHANGE,
              "no-change: absent evidence bundle is treated as awaiting adjudication")


# --------------------------------------------------------------------------
# Case 4: schema-valid-write guard
# --------------------------------------------------------------------------

def case_schema_guard() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        pack = _copy_valid(tmp)
        staging, promoted = _make_gate(tmp)
        cid = "web-design-skill"
        vps = _component(pack, cid)["vendored_paths"]
        new_digest = _build_promoted_from_scaffold(pack, promoted, cid, vps)
        _write_evidence(staging, cid, {
            "adjudication": "accepted",
            "verdict": "pass-with-accepted-risk",
            "airlock_evidence_id": "e",
            "engine_pin": "e",
            "scan_date": "2026-07-23",
            "content_hash": new_digest,
            "pinned_commit": "NOT-A-VALID-SHA",  # violates the schema pattern
        })
        pack_yaml_before = open(os.path.join(pack, "pack.yaml"), "rb").read()
        raised = False
        try:
            pu.update(pack, cid, staging, promoted, gate_root=None)
        except pu.PackUpdateError:
            raised = True
        pack_yaml_after = open(os.path.join(pack, "pack.yaml"), "rb").read()
        check(raised and pack_yaml_before == pack_yaml_after,
              "schema guard: a would-be schema-invalid write is refused, pack.yaml untouched")


# --------------------------------------------------------------------------
# Case 5: bad-root guard
# --------------------------------------------------------------------------

def case_bad_root() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        pack = _copy_valid(tmp)
        raised = False
        try:
            pu.update(pack, "web-design-skill", os.path.join(tmp, "nope"),
                      os.path.join(tmp, "nope2"), gate_root=None)
        except pu.PackUpdateError:
            raised = True
        check(raised, "bad-root guard: missing gate roots are rejected before acting")


def main() -> int:
    case_updated()
    case_quarantined()
    case_no_change()
    case_schema_guard()
    case_bad_root()

    total = len(_results)
    failed = [label for ok, label in _results if not ok]
    print("\n%d/%d checks passed." % (total - len(failed), total))
    if failed:
        print("FAILURES:")
        for label in failed:
            print("  - " + label)
        return 1
    print("Lifecycle verification passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
