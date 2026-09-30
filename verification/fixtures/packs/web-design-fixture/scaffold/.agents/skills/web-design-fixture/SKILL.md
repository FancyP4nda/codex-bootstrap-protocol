---
name: web-design-fixture
description: "TEST FIXTURE — fake skill installed only by the pack-install verification suite. Never released; does nothing."
---

# web-design-fixture (test fixture skill)

This is a fake skill shipped by the `web-design-fixture` fixture pack under
`verification/fixtures/packs/`. It exists so installer tests have a concrete
skill file to plan, copy, and collision-check. It has no behavior.

If you find this file in a real project outside a verification temp
directory, a test fixture leaked: delete it and file a bug against the
bootstrap kit's pack-install verification suite.
