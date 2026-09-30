#!/usr/bin/env python3
"""Regenerate the vendored-tree digests baked into web-design-fixture-valid.

The release-valid fixture must carry vendored_tree_digest / content_hash values
that equal what the T006 validator recomputes from the scaffold bytes. Rather
than hand-maintain SHA-256s, this helper computes them with the validator's OWN
``component_tree_digest`` (identical code path) and rewrites the ``__DIGEST_*__``
placeholder tokens (first run) or the recorded digests (subsequent runs) in the
fixture's pack.yaml.

Run after editing any byte under the fixture's scaffold/:

    python3 verification/fixtures/regenerate-valid-digests.py

Idempotent: running it on an already-current fixture makes no changes.
"""

from __future__ import annotations

import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_KIT_ROOT = os.path.abspath(os.path.join(_HERE, "..", ".."))
sys.path.insert(0, os.path.join(_KIT_ROOT, "verification", "pack-validator"))

import pack_validate as v  # noqa: E402  (path set above)

FIXTURE = os.path.join(_HERE, "packs", "web-design-fixture-valid")
SCAFFOLD = os.path.join(FIXTURE, "scaffold")
PACK_YAML = os.path.join(FIXTURE, "pack.yaml")

# component id -> its vendored_paths (kept in sync with pack.yaml)
COMPONENTS = {
    "web-design-skill": ([".agents/skills/web-design/"], "__DIGEST_SKILL__"),
    "web-design-mcp": ([".codex/mcp/web-design-mcp/"], "__DIGEST_MCP__"),
}


def main() -> int:
    with open(PACK_YAML, "r", encoding="utf-8") as fh:
        text = fh.read()
    original = text

    for cid, (vendored_paths, token) in COMPONENTS.items():
        digest = v.component_tree_digest(SCAFFOLD, vendored_paths)
        # Replace the placeholder token on first run; on later runs, rewrite the
        # 64-hex digest that follows content_hash/vendored_tree_digest/scanned_tree_digest.
        if token in text:
            text = text.replace(token, digest)
        else:
            # Idempotent update: replace any prior digest bound to this component.
            # The prior value is whatever currently sits in the same fields.
            pass
        print("%s: %s" % (cid, digest))

    # Second pass: normalise any drifted recorded digests back to the freshly
    # computed values (covers the non-first-run case without placeholder tokens).
    text = _rewrite_recorded_digests(text)

    if text != original:
        with open(PACK_YAML, "w", encoding="utf-8") as fh:
            fh.write(text)
        print("pack.yaml updated.")
    else:
        print("pack.yaml already current — no changes.")
    return 0


def _rewrite_recorded_digests(text: str) -> str:
    """Rewrite recorded per-component digests to the current computed values.

    Parses the fixture just enough to map each component's block to its digest,
    then rewrites content_hash/vendored_tree_digest (and the mcp
    provenance.scanned_tree_digest, which mirrors content_hash) in place.
    """
    for cid, (vendored_paths, _token) in COMPONENTS.items():
        digest = v.component_tree_digest(SCAFFOLD, vendored_paths)
        # Only rewrite lines whose value is a bare 64-hex string (already-filled
        # digests), never the opaque sha256:-prefixed provenance placeholders.
        block_start = text.find("id: %s" % cid)
        if block_start == -1:
            continue
        block_end = text.find("\n  - id:", block_start)
        if block_end == -1:
            block_end = len(text)
        block = text[block_start:block_end]
        for field in ("content_hash", "vendored_tree_digest", "scanned_tree_digest"):
            block = re.sub(
                r'(%s: ")[0-9a-f]{64}(")' % field,
                lambda m: m.group(1) + digest + m.group(2),
                block,
            )
        text = text[:block_start] + block + text[block_end:]
    return text


if __name__ == "__main__":
    raise SystemExit(main())
