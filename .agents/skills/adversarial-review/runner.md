# Bounded adversarial review

1. Read the artifact and its parent evidence. Record missing evidence as a risk.
2. Run `python3 <skill-directory>/scripts/review.py <artifact>`. Review output
   contains the provider and whether critique is cross-provider or same-provider.
3. The owner accepts valid findings and rejects unsupported ones with evidence,
   then edits only the authorized artifact and review log.
4. Run at most five rounds, or the user's requested smaller limit. Stop on a
   clear APPROVED verdict. After failure or timeout, report no verdict and use
   an explicit `--provider codex` invocation for a labeled fallback.
5. Unresolved blocking findings mean REVISE/deadlock, never implicit approval.
   Preserve prior critiques. Report round count, changes, remaining risks and
   any skipped provider. Only the owner edits the plan or log.
