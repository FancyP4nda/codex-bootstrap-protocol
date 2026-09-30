# Pack Fixtures (TEST-ONLY — NEVER RELEASE)

Fixture mission packs for the pack-install verification suite
(`verification/run-pack-checks.sh`). Everything under this directory is test
infrastructure (T004) and is permanently excluded from any release path:

- Release packs live under `assets/packs/` (PRD FR-001). Nothing under
  `verification/fixtures/` is ever copied there by the kit itself; the
  verification suite copies fixtures into *temporary* kit roots only.
- Fixture packs carry **no airlock evidence bundle, no validator stamp, and
  placeholder metadata**. The pre-release validator (T006) MUST fail them —
  that failure is itself a T006 test case, not a defect.
- Fixture scaffold content is authored in-repo for this kit: no third-party
  code, nothing to vet, no network access required (PRD constraint: the
  fixture contains nothing vettable by design).

## web-design-fixture (release-INVALID negative fixture)

A stub pack shaped per PRD FR-001 (`manifest.txt`, `pack.yaml`, `scaffold/` —
no stamp, intentionally):

- `manifest.txt` — install-path fragment in the kit's TSV manifest grammar.
- `pack.yaml` — minimal-but-shaped metadata per the PRD FR-004 field list. It
  conforms to the formal `pack.yaml` schema (T005:
  `docs/pack-yaml-schema.md` + `verification/pack-validator/pack.schema.json`)
  and is that schema's conformance fixture, but it must never be treated as
  schema documentation.
- `scaffold/` — one fake skill file and one fake MCP directory with a
  trivial `package.json` + `package-lock.json` (no dependencies).

Deliberately release-INVALID: its `null` evidence fields, `null` digests,
`null` FR-007 declarations, and absent stamp are T006 test cases. The validator
(`verification/run-validator-checks.sh`) asserts it fails for those classes
**only**. Consumed by `verification/run-pack-checks.sh`, and reused by T002
(`--pack` flag) and T003.

## web-design-fixture-valid (release-VALID variant, T006)

The positive counterpart, shaped to **pass** release-mode validation against
its own fixture evidence tree so the stamp / tamper / evidence-root cases run
end-to-end:

- Two components — a `pass-with-accepted-risk` vendored skill (exercises the
  `accepted_risk` block + evidence-root verbatim comparison) and a `pass`
  npm-artifact MCP server (exercises provenance + a clean dependency audit).
- Genuinely computed `vendored_tree_digest` / `content_hash` values, kept in
  sync with the scaffold bytes by
  `verification/fixtures/regenerate-valid-digests.py` (rerun it after editing
  any scaffold byte — it recomputes via the validator's own digest code).
- Real FR-007 artifacts (mission guide, component notes, rules file) present
  under `scaffold/`, and a self-consistent ownership partition.

It still never ships (test infrastructure) and, by construction, FAILS release
validation against any *real* evidence root — itself a T006 test case. Its
release-mode `pack.stamp` is a test artifact and is git-ignored.

## evidence/ (fixture evidence tree)

`verification/fixtures/evidence/<component-id>.yaml` stands in for the gate-side
airlock evidence bundle. Release mode
(`pack_validate.py --evidence-root verification/fixtures/evidence`) compares
each `pass-with-accepted-risk` component's `accepted_risk.reason` and
deployment conditions **verbatim** against these files.
