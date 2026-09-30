#!/usr/bin/env python3
"""pack-validate — pre-release mission-pack validator (PRD FR-005, task T006).

Fails a mission pack on any FR-005 violation class and, in release mode
(``--evidence-root``), writes the single tamper-evident stamp on a clean pass.

Two modes
---------
* **Test mode** ``pack_validate.py <pack-dir>`` — runs every check EXCEPT the
  evidence-root verbatim comparison, and writes NO stamp. Exit 0 on pass.
* **Release mode** ``pack_validate.py --evidence-root <dir> <pack-dir>`` — runs
  every check including verbatim accepted-risk equality against the gate-side
  evidence bundle, and writes the sole release stamp on a clean pass.

On failure the tool prints one violation-specific line per problem to stderr and
exits non-zero. The exit code is 1 for validation failures and 2 for usage /
load errors.

Design constraints (FR-004 / FR-005 / C-002)
--------------------------------------------
* The whole-pack stamp digest is computed over the EXACT on-disk bytes of
  ``manifest.txt`` + ``pack.yaml`` + every regular file under ``scaffold/``
  (the stamp file itself excluded). No YAML canonicalization — a bash verifier
  reproduces it with ``sha256sum`` alone (see ``tree_digest``/``STAMP_NAME``).
* ``pack.yaml`` is never parsed by the installer; only this tooling-side
  validator (python3 + jsonschema + pyyaml) reads it.

This file is intentionally an importable module: the fixture builder and the
test runner reuse :func:`tree_digest`, :func:`whole_pack_digest`, and
:func:`component_tree_digest` so fixture digests and validator digests are
computed by identical code.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import sys
from typing import Iterable

try:
    import yaml
    import jsonschema
except ImportError as exc:  # pragma: no cover - environment guard
    sys.stderr.write(
        "pack-validate: missing toolchain (%s). Install with:\n"
        "  python3 -m pip install -r verification/pack-validator/requirements.txt\n"
        % exc.name
    )
    raise SystemExit(2)

# --------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------

#: Top-level stamp filename. FR-001 allowlists exactly {manifest.txt, pack.yaml,
#: scaffold/, <stamp>}. Excluded from the whole-pack digest by basename.
STAMP_NAME = "pack.stamp"

#: FR-001 top-level allowlist. Any other top-level entry is a release failure.
TOP_LEVEL_ALLOWLIST = frozenset({"manifest.txt", "pack.yaml", "scaffold", STAMP_NAME})

_HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_SCHEMA = os.path.join(_HERE, "pack.schema.json")
DEFAULT_ALLOWLIST = os.path.join(_HERE, "license-allowlist.txt")

#: Evidence-bearing fields that must be non-null at release time (design
#: principle 2 of the pack.yaml schema doc). content_hash / vendored_tree_digest
#: are handled by the dedicated hash check; the rest are pointer/record fields.
_EVIDENCE_POINTER_FIELDS = ("airlock_evidence_id", "engine_pin", "scan_date")
_PROVENANCE_FIELDS = (
    "tarball_digest",
    "attestation_record",
    "transformation_record",
    "generated_lockfile_digest",
    "scanned_tree_digest",
)
_DEP_AUDIT_EVIDENCE_FIELDS = ("lockfile_digest", "report_digest", "report_location")


# --------------------------------------------------------------------------
# Digest algorithm (FR-005 normative recipe — shared with any bash verifier)
# --------------------------------------------------------------------------

def _sha256_file(path: str) -> str:
    """Return the hex SHA-256 of a file's exact on-disk bytes."""
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def tree_digest(base_dir: str, rel_files: Iterable[str]) -> str:
    """SHA-256 over a sorted ``sha256sum``-format manifest.

    ``rel_files`` are paths relative to ``base_dir`` — exactly the strings that
    must appear in the manifest. The manifest is byte-reproducible by GNU
    ``sha256sum``: for each file, ``"<hexdigest>  <rel>\\n"`` (two spaces, the
    coreutils text-mode separator), lines sorted bytewise (``LC_ALL=C``) by the
    relative path, and the concatenation hashed once more.
    """
    lines = []
    for rel in sorted(rel_files, key=lambda p: p.encode("utf-8")):
        digest = _sha256_file(os.path.join(base_dir, rel))
        lines.append(("%s  %s\n" % (digest, rel)).encode("utf-8"))
    return hashlib.sha256(b"".join(lines)).hexdigest()


def _walk_rel_files(base_dir: str, start: str, exclude_basename: str | None = None):
    """Yield regular-file paths under ``base_dir/start`` relative to base_dir."""
    root = os.path.join(base_dir, start)
    if os.path.isfile(root):
        if exclude_basename is None or os.path.basename(root) != exclude_basename:
            yield start
        return
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            if exclude_basename is not None and name == exclude_basename:
                continue
            full = os.path.join(dirpath, name)
            if os.path.islink(full) or not os.path.isfile(full):
                continue
            yield os.path.relpath(full, base_dir)


def whole_pack_digest(pack_dir: str) -> str:
    """Canonical whole-pack digest recorded in the stamp.

    Covers ``manifest.txt`` + ``pack.yaml`` + every regular file under
    ``scaffold/``, excluding the stamp by basename. Byte-reproducible via::

        (cd <pack> && find manifest.txt pack.yaml scaffold -type f \\
            ! -name pack.stamp -print0 | LC_ALL=C sort -z \\
            | xargs -0 sha256sum | sha256sum)
    """
    rel_files: list[str] = []
    for top in ("manifest.txt", "pack.yaml"):
        p = os.path.join(pack_dir, top)
        if os.path.isfile(p) and os.path.basename(p) != STAMP_NAME:
            rel_files.append(top)
    rel_files.extend(_walk_rel_files(pack_dir, "scaffold", exclude_basename=STAMP_NAME))
    return tree_digest(pack_dir, rel_files)


def component_tree_digest(scaffold_dir: str, vendored_paths: Iterable[str]) -> str:
    """Per-component vendored-tree digest, paths relative to the scaffold root.

    Same tree-hash algorithm airlock uses for ``content_hash`` so the recorded
    ``vendored_tree_digest`` and ``content_hash`` are directly comparable.
    """
    rel_files: list[str] = []
    for vp in vendored_paths:
        vp_norm = vp.strip("/")
        rel_files.extend(_walk_rel_files(scaffold_dir, vp_norm))
    return tree_digest(scaffold_dir, rel_files)


# --------------------------------------------------------------------------
# Validation
# --------------------------------------------------------------------------

class Validator:
    """Collects violations for one pack. One named line per violation."""

    def __init__(self, pack_dir: str, evidence_root: str | None,
                 schema_path: str, allowlist_path: str):
        self.pack_dir = os.path.abspath(pack_dir)
        self.scaffold_dir = os.path.join(self.pack_dir, "scaffold")
        self.evidence_root = evidence_root
        self.schema_path = schema_path
        self.allowlist_path = allowlist_path
        self.violations: list[str] = []
        self.pack: dict | None = None

    def fail(self, cls: str, message: str) -> None:
        self.violations.append("%s: %s" % (cls, message))

    # -- loaders ----------------------------------------------------------

    def _load_allowlist(self) -> set[str]:
        allowed: set[str] = set()
        with open(self.allowlist_path, "r", encoding="utf-8") as fh:
            for line in fh:
                s = line.strip()
                if s and not s.startswith("#"):
                    allowed.add(s)
        return allowed

    # -- checks -----------------------------------------------------------

    def check_schema(self) -> bool:
        """Load + schema-validate pack.yaml. Returns False if unusable."""
        pack_yaml = os.path.join(self.pack_dir, "pack.yaml")
        if not os.path.isfile(pack_yaml):
            self.fail("schema", "pack.yaml is missing")
            return False
        try:
            with open(pack_yaml, "r", encoding="utf-8") as fh:
                data = yaml.safe_load(fh)
        except yaml.YAMLError as exc:
            self.fail("schema", "pack.yaml is not valid YAML: %s" % exc)
            return False
        with open(self.schema_path, "r", encoding="utf-8") as fh:
            import json
            schema = json.load(fh)
        errors = sorted(
            jsonschema.Draft202012Validator(schema).iter_errors(data),
            key=lambda e: list(e.absolute_path),
        )
        if errors:
            for err in errors:
                loc = "/".join(str(p) for p in err.absolute_path) or "<root>"
                self.fail("schema", "%s: %s" % (loc, err.message))
            return False
        self.pack = data
        return True

    def check_top_level_allowlist(self) -> None:
        for entry in sorted(os.listdir(self.pack_dir)):
            if entry not in TOP_LEVEL_ALLOWLIST:
                self.fail("top-level",
                          "top-level entry %r is outside the FR-001 allowlist "
                          "(manifest.txt, pack.yaml, scaffold/, %s)" % (entry, STAMP_NAME))

    def check_verdict(self) -> None:
        for comp in self.pack["components"]:
            verdict = comp.get("verdict")
            if verdict is None:
                self.fail("verdict", "component %r has no verdict" % comp.get("id"))
            elif verdict == "quarantined":
                self.fail("verdict", "component %r is quarantined" % comp.get("id"))

    def check_evidence_present(self) -> None:
        """Every evidence-bearing pointer/record field must be non-null."""
        for comp in self.pack["components"]:
            cid = comp.get("id")
            for field in _EVIDENCE_POINTER_FIELDS:
                if comp.get(field) is None:
                    self.fail("evidence-null",
                              "component %r field %r is null (evidence absent)" % (cid, field))
            if comp.get("scan_target") == "npm-artifact":
                prov = comp.get("provenance") or {}
                for field in _PROVENANCE_FIELDS:
                    if prov.get(field) is None:
                        self.fail("evidence-null",
                                  "component %r provenance.%s is null (evidence absent)" % (cid, field))
            if comp.get("kind") == "mcp":
                audit = comp.get("dependency_audit") or {}
                for field in _DEP_AUDIT_EVIDENCE_FIELDS:
                    if audit.get(field) is None:
                        self.fail("evidence-null",
                                  "component %r dependency_audit.%s is null (evidence absent)" % (cid, field))

    def check_hashes(self) -> None:
        """content_hash / vendored_tree_digest absent or mismatched."""
        for comp in self.pack["components"]:
            cid = comp.get("id")
            recorded = comp.get("vendored_tree_digest")
            content_hash = comp.get("content_hash")
            if recorded is None:
                self.fail("hash", "component %r vendored_tree_digest is absent" % cid)
            if content_hash is None:
                self.fail("hash", "component %r content_hash is absent" % cid)
            if recorded is None or content_hash is None:
                continue
            try:
                actual = component_tree_digest(self.scaffold_dir, comp.get("vendored_paths", []))
            except OSError as exc:
                self.fail("hash", "component %r vendored tree unreadable: %s" % (cid, exc))
                continue
            if actual != recorded:
                self.fail("hash",
                          "component %r vendored_tree_digest mismatch: recorded %s, recomputed %s"
                          % (cid, recorded, actual))
            if actual != content_hash:
                self.fail("hash",
                          "component %r content_hash mismatch: airlock %s, recomputed %s"
                          % (cid, content_hash, actual))

    def check_docs(self) -> None:
        """FR-007 mandatory docs/rules artifacts declared AND present."""
        pack_meta = self.pack["pack"]
        for field in ("mission_guide", "component_notes", "rules_file"):
            value = pack_meta.get(field)
            if value is None:
                self.fail("docs", "pack.%s is not declared (FR-007 artifact missing)" % field)
                continue
            paths = []
            if isinstance(value, str):
                paths = [value]
            elif isinstance(value, dict):
                paths = list(value.values())
            for rel in paths:
                if not os.path.isfile(os.path.join(self.scaffold_dir, rel.lstrip("/"))):
                    self.fail("docs",
                              "pack.%s declares %r but the file is absent from scaffold/" % (field, rel))

    def check_license(self) -> None:
        allowed = self._load_allowlist()
        for comp in self.pack["components"]:
            cid = comp.get("id")
            lic = comp.get("license")
            if not lic:
                self.fail("license", "component %r has no license (fails closed)" % cid)
                continue
            if lic.startswith("LicenseRef-"):
                self.fail("license", "component %r license %r is a LicenseRef-* (fails closed)" % (cid, lic))
                continue
            # SPDX expression operands must ALL be allowlisted; otherwise fail closed.
            if any(op in lic for op in (" AND ", " OR ", " WITH ", "(", ")")):
                operands = (lic.replace("(", " ").replace(")", " ")
                            .replace(" AND ", " ").replace(" OR ", " ")
                            .replace(" WITH ", " ").split())
                unlisted = [o for o in operands if o not in allowed]
                if unlisted:
                    self.fail("license",
                              "component %r license expression %r has unlisted operand(s) %s (fails closed)"
                              % (cid, lic, ", ".join(unlisted)))
                continue
            if lic not in allowed:
                self.fail("license",
                          "component %r license %r is outside the SPDX redistribution allowlist" % (cid, lic))

    def check_ownership_partition(self) -> None:
        """Every scaffold byte owned by exactly one of {vendored_paths, pack_paths}."""
        scaffold_files = set()
        if os.path.isdir(self.scaffold_dir):
            for dirpath, _dirs, files in os.walk(self.scaffold_dir):
                for name in files:
                    full = os.path.join(dirpath, name)
                    if os.path.isfile(full) and not os.path.islink(full):
                        scaffold_files.add(os.path.relpath(full, self.scaffold_dir))

        owners: dict[str, list[str]] = {f: [] for f in scaffold_files}

        def claim(owner: str, rel_root: str) -> None:
            rel_root = rel_root.strip("/")
            for f in scaffold_files:
                if f == rel_root or f.startswith(rel_root + "/"):
                    owners[f].append(owner)

        for comp in self.pack["components"]:
            for vp in comp.get("vendored_paths", []):
                claim("component:%s" % comp.get("id"), vp)
        for pp in self.pack["pack"].get("pack_paths", []):
            claim("pack_paths", pp)

        for f in sorted(scaffold_files):
            n = len(owners[f])
            if n == 0:
                self.fail("ownership", "scaffold file %r is owned by zero owners" % f)
            elif n > 1:
                self.fail("ownership",
                          "scaffold file %r is owned by %d owners (%s)" % (f, n, ", ".join(owners[f])))

    def check_accepted_risk(self) -> None:
        for comp in self.pack["components"]:
            if comp.get("verdict") != "pass-with-accepted-risk":
                continue
            cid = comp.get("id")
            ar = comp.get("accepted_risk")
            if not ar:
                self.fail("accepted-risk", "component %r is pass-with-accepted-risk but has no accepted_risk block" % cid)
                continue
            if not ar.get("reason"):
                self.fail("accepted-risk", "component %r accepted_risk.reason is missing" % cid)
            for i, cond in enumerate(ar.get("deployment_conditions", [])):
                for key in ("condition", "enforced_by", "enforcement_ref"):
                    if not cond.get(key):
                        self.fail("accepted-risk",
                                  "component %r deployment_conditions[%d].%s is missing" % (cid, i, key))

    def check_dependency_audit(self) -> None:
        for comp in self.pack["components"]:
            if comp.get("kind") != "mcp":
                continue
            cid = comp.get("id")
            audit = comp.get("dependency_audit")
            if not audit:
                self.fail("dep-audit", "mcp component %r has no dependency_audit record" % cid)
                continue
            adj = audit.get("adjudication")
            if adj != "accepted":
                self.fail("dep-audit", "mcp component %r dependency_audit.adjudication is %r (must be accepted)" % (cid, adj))
            self._walk_lockfiles(comp)

    def _walk_lockfiles(self, comp: dict) -> None:
        """Mechanical lockfile walk: every resolved dependency node must be
        registry-resolved with an integrity hash. The root project record
        (no resolution, no integrity) is exempt; git/URL/file/workspace nodes fail."""
        import json
        cid = comp.get("id")
        for vp in comp.get("vendored_paths", []):
            base = os.path.join(self.scaffold_dir, vp.strip("/"))
            for dirpath, _dirs, files in os.walk(base):
                if "package-lock.json" not in files:
                    continue
                lock_path = os.path.join(dirpath, "package-lock.json")
                try:
                    with open(lock_path, "r", encoding="utf-8") as fh:
                        lock = json.load(fh)
                except (OSError, json.JSONDecodeError) as exc:
                    self.fail("dep-audit", "mcp component %r lockfile unreadable (%s)" % (cid, exc))
                    continue
                for pkg_path, node in (lock.get("packages") or {}).items():
                    if pkg_path == "":
                        continue  # root project record — exempt
                    for form in ("git", "tarball", "file", "link", "workspace"):
                        if node.get(form):
                            self.fail("dep-audit",
                                      "mcp component %r lockfile node %r uses forbidden %r form" % (cid, pkg_path, form))
                    resolved = node.get("resolved")
                    if resolved is not None and not resolved.startswith(("http://", "https://")):
                        self.fail("dep-audit",
                                  "mcp component %r lockfile node %r is not registry-resolved (%s)" % (cid, pkg_path, resolved))
                    if node.get("resolved") is not None and not node.get("integrity"):
                        self.fail("dep-audit",
                                  "mcp component %r lockfile node %r has no integrity hash" % (cid, pkg_path))

    def check_evidence_root(self) -> None:
        """Release-mode only: accepted_risk reason + conditions compared verbatim
        against the authoritative evidence bundle under <evidence-root>/<id>.yaml."""
        for comp in self.pack["components"]:
            if comp.get("verdict") != "pass-with-accepted-risk":
                continue
            cid = comp.get("id")
            ar = comp.get("accepted_risk") or {}
            bundle_path = os.path.join(self.evidence_root, "%s.yaml" % cid)
            if not os.path.isfile(bundle_path):
                self.fail("evidence-root", "no evidence bundle for component %r at %s" % (cid, bundle_path))
                continue
            with open(bundle_path, "r", encoding="utf-8") as fh:
                bundle = yaml.safe_load(fh) or {}
            if ar.get("reason") != bundle.get("residual_risk_accepted_reason"):
                self.fail("evidence-root",
                          "component %r accepted_risk.reason does not match the evidence bundle verbatim" % cid)
            pack_conds = [c.get("condition") for c in ar.get("deployment_conditions", [])]
            eb_conds = list(bundle.get("deployment_conditions", []))
            if pack_conds != eb_conds:
                self.fail("evidence-root",
                          "component %r deployment conditions do not match the evidence bundle verbatim" % cid)

    # -- driver -----------------------------------------------------------

    def run(self) -> int:
        # Remove any existing stamp BEFORE validating (re-stamp only on clean pass).
        stamp_path = os.path.join(self.pack_dir, STAMP_NAME)
        if os.path.isfile(stamp_path):
            os.remove(stamp_path)

        self.check_top_level_allowlist()
        if not self.check_schema():
            return self._finish(stamp_path, wrote=False)

        self.check_verdict()
        self.check_evidence_present()
        self.check_hashes()
        self.check_docs()
        self.check_license()
        self.check_ownership_partition()
        self.check_accepted_risk()
        self.check_dependency_audit()
        if self.evidence_root is not None:
            self.check_evidence_root()

        if self.violations:
            return self._finish(stamp_path, wrote=False)

        # Clean pass. Only release mode writes the stamp.
        if self.evidence_root is not None:
            digest = whole_pack_digest(self.pack_dir)
            self._write_stamp(stamp_path, digest)
        return self._finish(stamp_path, wrote=self.evidence_root is not None)

    def _write_stamp(self, stamp_path: str, digest: str) -> None:
        with open(stamp_path, "w", encoding="utf-8") as fh:
            fh.write("# pack-validate release stamp (FR-005). Verify with sha256sum; do not edit.\n")
            fh.write("# reproduce: (cd <pack> && find manifest.txt pack.yaml scaffold -type f "
                     "! -name %s -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum)\n" % STAMP_NAME)
            fh.write("stamp_version: 1\n")
            fh.write("pack_name: %s\n" % self.pack["pack"]["name"])
            fh.write("whole_pack_digest: sha256:%s\n" % digest)

    def _finish(self, stamp_path: str, wrote: bool) -> int:
        if self.violations:
            for v in self.violations:
                sys.stderr.write(v + "\n")
            return 1
        mode = "release" if self.evidence_root is not None else "test"
        if wrote:
            sys.stdout.write("PASS (%s mode): stamp written to %s\n" % (mode, stamp_path))
        else:
            sys.stdout.write("PASS (%s mode): no stamp written (test mode)\n" % mode)
        return 0


# --------------------------------------------------------------------------
# Stamp verification helper (reused by tamper tests and any installer check)
# --------------------------------------------------------------------------

def read_stamp_digest(pack_dir: str) -> str | None:
    """Return the digest recorded in the stamp, or None if no valid stamp."""
    stamp_path = os.path.join(pack_dir, STAMP_NAME)
    if not os.path.isfile(stamp_path):
        return None
    with open(stamp_path, "r", encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("whole_pack_digest:"):
                val = line.split(":", 1)[1].strip()
                return val[len("sha256:"):] if val.startswith("sha256:") else val
    return None


def verify_stamp(pack_dir: str) -> bool:
    """True iff a stamp exists and its recorded digest matches the recomputed
    whole-pack digest. Any post-stamp change to a covered file breaks this."""
    recorded = read_stamp_digest(pack_dir)
    if recorded is None:
        return False
    return recorded == whole_pack_digest(pack_dir)


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="pack-validate",
        description="Pre-release mission-pack validator (PRD FR-005). "
                    "Release mode (--evidence-root) writes the sole tamper-evident stamp.",
    )
    parser.add_argument("pack_dir", help="path to the mission-pack directory")
    parser.add_argument("--evidence-root", metavar="DIR", default=None,
                        help="gate-side evidence tree; enables release mode + stamp write")
    parser.add_argument("--schema", default=DEFAULT_SCHEMA, help="path to pack.schema.json")
    parser.add_argument("--license-allowlist", default=DEFAULT_ALLOWLIST,
                        help="path to the SPDX redistribution allowlist")
    args = parser.parse_args(argv)

    if not os.path.isdir(args.pack_dir):
        sys.stderr.write("pack-validate: pack directory not found: %s\n" % args.pack_dir)
        return 2
    if args.evidence_root is not None and not os.path.isdir(args.evidence_root):
        sys.stderr.write("pack-validate: --evidence-root not found: %s\n" % args.evidence_root)
        return 2

    validator = Validator(args.pack_dir, args.evidence_root, args.schema, args.license_allowlist)
    return validator.run()


if __name__ == "__main__":
    raise SystemExit(main())
