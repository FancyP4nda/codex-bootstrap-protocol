# Agile User Story Guidelines for AI-Readable PRDs

When generating functional requirements for downstream planning and coding agents, format user stories with Behavior-Driven Development (BDD) syntax: `Given`, `When`, `Then`.

The goal is not to predict implementation. The goal is to describe observable product behavior so the downstream planner can create vertical slices and the implementation agent can test through public interfaces.

Traditional "As a [user]" narratives are useful for stakeholder communication, but they are often too vague for agentic execution. Use BDD scenarios for the canonical acceptance criteria.

## Required Shape

```markdown
### US-001: [Short behavior title]

**Requirement coverage:** FR-001

**Scenario:** [Specific context or state being modeled]

- **Given** [Initial observable state from the user's, API client's, CLI user's, or system actor's perspective]
- **When** [The specific public action, API call, CLI command, scheduled event, or system trigger]
- **Then** [The exact observable result]

**Acceptance criteria**

- **AC-001:** [One verifiable outcome]
- **AC-002:** [One verifiable outcome]
```

## Rules

- Use stable IDs for stories and acceptance criteria: `US-001`, `AC-001`.
- Link each story to one or more functional requirements such as `FR-001`.
- Keep each scenario focused on one behavior.
- Write outcomes that can be verified through public interfaces.
- Prefer user-visible, API-visible, CLI-visible, emitted-event, or documented state transitions.
- Use implementation details only when they are explicit product constraints.
- Do not assert private methods, internal class names, table names, counters, or component hierarchy unless the requirement is specifically about that interface or data contract.
- Do not include task sequencing, implementation phases, or ticket breakdowns.

## Example: Correct

### US-001: Reject reused welcome promotion

**Requirement coverage:** FR-002

**Scenario:** Returning customer applies a single-use welcome code

- **Given** an authenticated customer has already redeemed the welcome promotion
- **When** the customer applies code `WELCOME100` during checkout
- **Then** checkout keeps the order unpaid and displays that the code is only valid for new customers

**Acceptance criteria**

- **AC-001:** The customer cannot complete checkout with the reused welcome code applied.
- **AC-002:** The response or UI explains that the code is only valid for new customers.
- **AC-003:** The failed promo attempt does not change the cart subtotal, taxes, shipping, or payment authorization state.

## Example: Too Implementation-Coupled

```markdown
- **Given** the user row has `has_used_welcome_promo = true`
- **When** `PromoController.validate()` is called
- **Then** the `login_attempts` database counter increments by 1
```

This may be useful implementation context in a technical design, but it is not good PRD acceptance criteria unless the database field or method call is itself a public contract.
