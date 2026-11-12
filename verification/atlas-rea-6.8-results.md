# Atlas REA 6.8.0 verification — 2026-11-12

Scope: REA pin and compatibility text, prerequisite/version fixtures, and the corresponding Codex MCP registration parser. Codex's derived pack also receives the Claude source's existing notice and locale safeguards.

Executed on Omarchy Linux x86_64:

- Claude: `verification/run-static-checks.sh` passed, including all 22 Atlas test groups. Node's resolved installation bin directory was prepended to PATH because the browser test fixtures intentionally restrict PATH and cannot run the mise shim. Earlier failures from that environment and incomplete version-fixture edits were corrected; the full final run passed.
- Codex: `python3 -m unittest discover -s verification -p test_atlas.py` with `ATLAS_SOURCE_KIT` set to the sibling Claude checkout: 131 tests, zero failures, one skipped installed-package inspection. Mirror/converter tests executed.
- Codex: `python3 verification/check-assets.py` passed (56 skills, 10 agents; manifests, references, mirrors and safety scan).
- REA 6.8.0: both selected client registrations and matching skills pass; Ghidra, JADX, Kuna, and Hopper scoped provider readiness checks pass.
- Installed Atlas doctor for each client recognizes REA 6.8.0 and reports no missing prerequisite. The broad REA audit still warns about unsupplied IDA and unconfigured clients outside Claude/Codex.

Provider versions: Ghidra 12.1.2, JDK 21.0.13, jadx-headless-mcp 0.7.1 (JADX GUI/CLI 1.5.6), Kuna 1.833, Hopper 6.6.2 demo. Downloads of Kuna and the JADX bridge were verified against release SHA-256 metadata; Hopper was installed by REA's publisher-verifying installer.

Not claimed: full native decompilation workflow, licensed IDA, cross-platform engine verification, or a new third-party release certification. Existing unverified-pack status is unchanged. Beads CLI was unavailable (`bd prime`: command not found); no Beads database or issue state was changed.
