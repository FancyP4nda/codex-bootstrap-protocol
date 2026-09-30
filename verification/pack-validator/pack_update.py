#!/usr/bin/env python3
"""pack-update — per-component pack lifecycle command (PRD FR-008, task T016).

Drives one component of a mission pack through a re-vet cycle. It is a **stateless
re-invocation**: each run reads the component's current airlock evidence state
from the staging-evidence root and acts on it. It NEVER adjudicates — airlock
adjudication is a human act (C-004); this tool only reads the recorded outcome.

Three outcome paths (FR-008)
----------------------------
* **updated**    — adjudicated, promoted pass (adjudication ``accepted`` AND
  verdict ``pass`` / ``pass-with-accepted-risk``): re-vendor from the promoted
  tree, refresh ``pack.yaml`` (pin, evidence id, engine pin, scan date, verdict,
  content hash, recomputed vendored-tree digest).
* **quarantined** — adjudicated fail (adjudication ``rejected`` / ``fix-required``
  or verdict ``quarantined`` / ``fail``): set the component verdict to
  ``quarantined``, leave the vendored tree byte-identical.
* **no-change**  — scanner error / pending / awaiting adjudication: change nothing.

Every WRITE path first removes the T006 validator stamp (FR-008: any change
requires a fresh release-mode validator pass). The no-change path leaves the
stamp untouched. Vendored bytes are edited ONLY on the promoted-pass path.

All ``pack.yaml`` writes go through a schema-valid check first — a mutation that
would produce a schema-invalid pack is refused before anything is written.

Reuses the T006 validator's digest code (``pack_validate``) so the refreshed
``vendored_tree_digest`` is computed by identical logic to what the validator
later checks.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys

try:
    import yaml
    import jsonschema
except ImportError as exc:  # pragma: no cover
    sys.stderr.write(
        "pack-update: missing toolchain (%s). Install with:\n"
        "  python3 -m pip install -r verification/pack-validator/requirements.txt\n"
        % exc.name
    )
    raise SystemExit(2)

import pack_validate as pv

# Outcome constants
UPDATED = "updated"
QUARANTINED = "quarantined"
NO_CHANGE = "no-change"

_ADJUDICATION_ACCEPTED = "accepted"
_ADJUDICATION_FAIL = frozenset({"rejected", "fix-required"})
_VERDICT_PASS = frozenset({"pass", "pass-with-accepted-risk"})
_VERDICT_FAIL = frozenset({"quarantined", "fail"})


class PackUpdateError(Exception):
    """Fatal, actionable error (bad roots, schema-invalid result, missing data)."""


def _load_evidence(staging_evidence: str, component_id: str) -> dict | None:
    """Read the component's current staging evidence bundle, or None if absent."""
    path = os.path.join(staging_evidence, "%s.yaml" % component_id)
    if not os.path.isfile(path):
        return None
    with open(path, "r", encoding="utf-8") as fh:
        return yaml.safe_load(fh) or {}


def _classify(evidence: dict | None) -> str:
    """Map evidence adjudication/verdict to one of the three outcomes (FR-008)."""
    if not evidence:
        return NO_CHANGE
    adjudication = evidence.get("adjudication")
    verdict = evidence.get("verdict")
    # Fail dominates: a rejected/failed audit can never ride a passing verdict.
    if adjudication in _ADJUDICATION_FAIL or verdict in _VERDICT_FAIL:
        return QUARANTINED
    if adjudication == _ADJUDICATION_ACCEPTED and verdict in _VERDICT_PASS:
        return UPDATED
    # pending / error / anything else -> change nothing.
    return NO_CHANGE


def _find_component(pack: dict, component_id: str) -> dict:
    for comp in pack.get("components", []):
        if comp.get("id") == component_id:
            return comp
    raise PackUpdateError("component %r not found in pack.yaml" % component_id)


def _schema_validate(pack: dict, schema_path: str) -> None:
    with open(schema_path, "r", encoding="utf-8") as fh:
        schema = json.load(fh)
    errors = sorted(jsonschema.Draft202012Validator(schema).iter_errors(pack),
                    key=lambda e: list(e.absolute_path))
    if errors:
        loc = "/".join(str(p) for p in errors[0].absolute_path) or "<root>"
        raise PackUpdateError("refusing write: result would be schema-invalid (%s: %s)"
                              % (loc, errors[0].message))


def _remove_stamp(pack_dir: str) -> None:
    stamp = os.path.join(pack_dir, pv.STAMP_NAME)
    if os.path.isfile(stamp):
        os.remove(stamp)


def _revendor(pack_dir: str, promoted_root: str, component_id: str, vendored_paths: list[str]) -> None:
    """Replace each vendored subtree in the pack scaffold with the promoted tree.

    The promoted tree mirrors scaffold-relative paths under
    ``<promoted_root>/<component_id>/``.
    """
    scaffold = os.path.join(pack_dir, "scaffold")
    src_root = os.path.join(promoted_root, component_id)
    if not os.path.isdir(src_root):
        raise PackUpdateError("promoted tree not found: %s" % src_root)
    for vp in vendored_paths:
        rel = vp.strip("/")
        src = os.path.join(src_root, rel)
        dst = os.path.join(scaffold, rel)
        if not os.path.exists(src):
            raise PackUpdateError("promoted tree missing vendored path %r (%s)" % (vp, src))
        if os.path.exists(dst):
            shutil.rmtree(dst) if os.path.isdir(dst) else os.remove(dst)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)


def update(pack_dir: str, component_id: str, staging_evidence: str,
           promoted_root: str, gate_root: str | None,
           schema_path: str = pv.DEFAULT_SCHEMA) -> dict:
    """Run one stateless update cycle. Returns a report dict:
    ``{"outcome": ..., "component": ..., "detail": ...}``."""
    for label, root in (("--staging-evidence", staging_evidence),
                        ("--promoted-root", promoted_root)):
        if not os.path.isdir(root):
            raise PackUpdateError("%s root not found: %s" % (label, root))
    if gate_root is not None and not os.path.isdir(gate_root):
        raise PackUpdateError("--gate-root not found: %s" % gate_root)

    pack_yaml = os.path.join(pack_dir, "pack.yaml")
    if not os.path.isfile(pack_yaml):
        raise PackUpdateError("pack.yaml not found in %s" % pack_dir)
    with open(pack_yaml, "r", encoding="utf-8") as fh:
        pack = yaml.safe_load(fh)
    comp = _find_component(pack, component_id)

    evidence = _load_evidence(staging_evidence, component_id)
    outcome = _classify(evidence)

    if outcome == NO_CHANGE:
        # Stateless: awaiting adjudication or scanner error. Touch nothing.
        return {"outcome": NO_CHANGE, "component": component_id,
                "detail": "no adjudicated result to act on (awaiting adjudication / scanner error)"}

    # Both write paths invalidate the stamp first (FR-008).
    _remove_stamp(pack_dir)

    if outcome == QUARANTINED:
        comp["verdict"] = "quarantined"  # vendored bytes left byte-identical
        _schema_validate(pack, schema_path)
        _write_pack(pack_yaml, pack)
        return {"outcome": QUARANTINED, "component": component_id,
                "detail": "adjudicated fail; verdict set to quarantined, vendored tree untouched, stamp removed"}

    # outcome == UPDATED (adjudicated, promoted pass)
    _revendor(pack_dir, promoted_root, component_id, comp.get("vendored_paths", []))
    scaffold = os.path.join(pack_dir, "scaffold")
    new_digest = pv.component_tree_digest(scaffold, comp.get("vendored_paths", []))

    # Refresh airlock-authoritative + derived fields from the evidence bundle.
    comp["vendored_tree_digest"] = new_digest
    for field in ("airlock_evidence_id", "engine_pin", "scan_date", "verdict", "content_hash"):
        if field in evidence and evidence[field] is not None:
            comp[field] = evidence[field]
    if evidence.get("pinned_commit") is not None and "pinned_commit" in comp:
        comp["pinned_commit"] = evidence["pinned_commit"]
    if evidence.get("version") is not None and "version" in comp:
        comp["version"] = evidence["version"]

    # Invariant the validator will enforce: recorded vendored digest must equal
    # the airlock content_hash. Surface a mismatch here with an actionable message
    # rather than letting the later validator fail opaquely.
    if comp.get("content_hash") not in (None, new_digest):
        raise PackUpdateError(
            "promoted tree digest %s does not match evidence content_hash %s "
            "(the scanned tree must equal the vendored tree)" % (new_digest, comp.get("content_hash")))
    comp["content_hash"] = new_digest

    _schema_validate(pack, schema_path)
    _write_pack(pack_yaml, pack)
    return {"outcome": UPDATED, "component": component_id,
            "detail": "adjudicated pass; re-vendored from promoted tree, refreshed pin/evidence/hashes, stamp removed"}


def _write_pack(pack_yaml: str, pack: dict) -> None:
    with open(pack_yaml, "w", encoding="utf-8") as fh:
        fh.write("# Managed by pack-update (T016) / pack-validate (T006). "
                 "Component fields are refreshed from airlock evidence; do not hand-edit machine fields.\n")
        yaml.safe_dump(pack, fh, sort_keys=False)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="pack-update",
        description="Per-component pack lifecycle command (PRD FR-008). Stateless: "
                    "reads the component's current airlock evidence and acts. Never adjudicates.",
    )
    parser.add_argument("pack_dir", help="mission-pack directory")
    parser.add_argument("component", help="component id to update")
    parser.add_argument("--staging-evidence", required=True, metavar="DIR",
                        help="staging evidence root (e.g. ~/hermes-staging/vetting)")
    parser.add_argument("--promoted-root", required=True, metavar="DIR",
                        help="promoted-tree root the audited source is re-vendored from (e.g. ~/hermes-prod)")
    parser.add_argument("--gate-root", default=None, metavar="DIR",
                        help="airlock gate tooling root (e.g. ~/airlock); validated if given")
    parser.add_argument("--schema", default=pv.DEFAULT_SCHEMA)
    args = parser.parse_args(argv)

    if not os.path.isdir(args.pack_dir):
        sys.stderr.write("pack-update: pack directory not found: %s\n" % args.pack_dir)
        return 2
    try:
        report = update(args.pack_dir, args.component, args.staging_evidence,
                        args.promoted_root, args.gate_root, args.schema)
    except PackUpdateError as exc:
        sys.stderr.write("pack-update: %s\n" % exc)
        return 1
    sys.stdout.write("%s: %s (%s)\n" % (report["outcome"], report["component"], report["detail"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
