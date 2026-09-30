# Architecture Decision Records

Create one file per durable decision.

Filename format (see `.agents/templates/artifacts/adr.md` for the body
template and `grill-with-docs` ADR-FORMAT for authoring guidance):

```text
NNNN-short-decision-title.md
```

Number sequentially from `0001`. File an ADR only when a decision passes the
three-part ADR test: (1) hard to reverse AND (2) surprising without context
AND (3) the result of a real trade-off. Each record should state the context,
decision, consequences, and the verification needed to prove the decision
still holds.
