---
workflow_artifact: prd
artifact_version: 1
source_mode: existing_project
status: approved
upstream_ids: [OPP-001]
recommended_next_skill: project-planner
canonical_next_artifact: project_plan
---

# Product Requirements Document: Checkout Promo Code Placement and Validation

## 1. Executive Summary

- **Target persona:** External e-commerce customers attempting checkout.
- **Core problem:** Customers cannot reliably find or use promo codes before payment review, which creates checkout friction and avoidable support contacts during campaigns.
- **Business goal:** Increase successful promo-code usage during campaigns and reduce promo-related checkout abandonment.
- **Product outcome:** Customers can discover the promo field before payment selection, apply a promo code, and receive clear eligibility feedback before authorizing payment.
- **Status:** Approved

## 2. Upstream Traceability

- **Source opportunity IDs:** OPP-001
- **Decision brief:** Checkout promo discovery Decision Brief, summarized in this PRD.
- **Key resolved decisions:** Promo entry must appear before payment authorization; validation feedback must be customer-actionable; no new third-party promo provider is in scope.
- **Key unresolved HITL decisions:** Final rejection copy, analytics event names, and whether welcome-promotion redemption is already tracked durably.
- **Repo grounding:** Existing checkout flow review, promo validation behavior, and analytics conventions.

## 3. Scope

### Goals

- **G-001:** Make promo-code entry discoverable before payment selection.
- **G-002:** Validate promo-code eligibility before payment authorization.
- **G-003:** Provide clear customer-facing feedback for invalid, expired, unknown, or ineligible promo codes.

### Non-Goals

- **NG-001:** Build campaign-management tooling.
- **NG-002:** Integrate new third-party promotion providers.
- **NG-003:** Redesign checkout flows unrelated to promo-code discovery and validation.

## 4. Users and Use Cases

### Personas

- **P-001:** Customer checking out during a promotion.
- **P-002:** Returning customer attempting to use a single-use welcome promotion.
- **P-003:** Support agent investigating promo-code complaints after checkout failure.

### Primary Use Cases

- **UC-001:** A customer enters a valid promo code before selecting payment and sees the discount reflected before payment authorization.
- **UC-002:** A returning customer attempts to reuse a welcome promotion and receives a clear rejection before payment authorization.
- **UC-003:** A customer enters an unknown or expired promo code and can correct it without losing checkout progress.

## 5. Functional Requirements

- **FR-001:** Checkout must expose promo-code entry before payment selection.
  - **Priority:** Must
  - **Source:** Customer friction report and campaign checkout review.
  - **Acceptance criteria:** AC-001, AC-002, AC-003

- **FR-002:** Checkout must validate promo-code eligibility before payment authorization.
  - **Priority:** Must
  - **Source:** Campaign eligibility rules.
  - **Acceptance criteria:** AC-002, AC-003, AC-004, AC-005, AC-007

- **FR-003:** Checkout must preserve customer progress after promo-code validation failure.
  - **Priority:** Must
  - **Source:** Checkout completion requirement.
  - **Acceptance criteria:** AC-006, AC-008, AC-009

## 6. BDD Scenarios and Acceptance Criteria

### US-001: Apply valid promo before payment

**Requirement coverage:** FR-001, FR-002

**Scenario:** Customer applies a valid promo code during checkout

- **Given** a customer has items in the cart and has not authorized payment
- **When** the customer applies a valid promo code before selecting a payment method
- **Then** checkout shows the discount and updated order total before payment authorization

**Acceptance criteria**

- **AC-001:** The promo-code entry point is visible before the customer reaches payment authorization.
- **AC-002:** A valid promo code updates the displayed order total before the customer authorizes payment.
- **AC-003:** The customer can remove or replace the applied promo code before payment authorization.

### US-002: Reject reused welcome promotion

**Requirement coverage:** FR-002, FR-003

**Scenario:** Returning customer applies a single-use welcome code

- **Given** an authenticated customer has already redeemed the welcome promotion
- **When** the customer applies code `WELCOME100` during checkout
- **Then** checkout keeps the order unpaid and displays that the code is only valid for new customers

**Acceptance criteria**

- **AC-004:** The customer cannot complete checkout with the reused welcome code applied.
- **AC-005:** The response or UI explains that the code is only valid for new customers.
- **AC-006:** The failed promo attempt does not change the cart subtotal, taxes, shipping, or payment authorization state.

### US-003: Recover from invalid promo code

**Requirement coverage:** FR-002, FR-003

**Scenario:** Customer enters an unknown or expired promo code

- **Given** a customer is in checkout with an unpaid order
- **When** the customer applies an unknown or expired promo code
- **Then** checkout rejects the code, keeps the customer in checkout, and allows another code attempt

**Acceptance criteria**

- **AC-007:** Checkout displays a clear invalid-code or expired-code message.
- **AC-008:** The customer does not lose cart contents, shipping details, or payment-selection progress.
- **AC-009:** The customer can submit a different promo code after the failed attempt.

## 7. Nonfunctional Requirements

- **NFR-001 Security:** Promo validation must require the same customer authentication and authorization guarantees as checkout pricing.
- **NFR-002 Privacy:** Promo errors must not reveal sensitive account history beyond customer-actionable eligibility feedback.
- **NFR-003 Performance:** Promo validation should complete within 500 ms p95 under normal campaign traffic.
- **NFR-004 Reliability:** Promo validation failure must not authorize payment or silently drop the customer's checkout state.
- **NFR-005 Accessibility:** Promo-code controls and validation messages must be keyboard accessible and exposed to assistive technologies.
- **NFR-006 Observability:** Promo validation outcomes should be observable enough to investigate campaign and support issues without logging secrets or full payment details.

## 8. Technical and Operational Constraints

- **C-001 Supported interfaces:** Use existing checkout surfaces and internal promotion-validation capabilities where available.
- **C-002 Compatibility:** Preserve existing checkout API and UI behavior for carts without promo codes.
- **C-003 Dependency policy:** Do not introduce new client-side state-management libraries for this feature.
- **C-004 Deployment or rollout:** The change should be releasable behind the existing checkout rollout mechanism if one exists.
- **C-005 Data or migration:** Any durable tracking of single-use promotion redemption must be backward compatible with existing customers.

## 9. AI Behavior and Evaluation

Not applicable. This is standard checkout product behavior and does not include model-mediated decisions.

## 10. Success Metrics

- **M-001:** Promo-code application completion rate.
  - **Baseline:** Unknown.
  - **Target:** Increase after launch.
  - **Measurement source:** Checkout analytics.

- **M-002:** Promo-related checkout abandonment.
  - **Baseline:** Unknown.
  - **Target:** Decrease after launch.
  - **Measurement source:** Checkout funnel analytics and support tags.

## 11. Assumptions

- **A-001:** The existing checkout system can display order-total changes before payment authorization.
  - **Source:** Existing checkout behavior assumption from Opportunity Brief.
- **A-002:** The existing promotion rules can determine whether a customer is eligible for a welcome promotion.
  - **Source:** Campaign eligibility rule assumption from Decision Brief.
- **A-003:** Marketing owns final customer-facing copy for promotion rejection messages.
  - **Source:** Product operating model assumption.

## 12. Open Questions and HITL Decisions

- **Q-001:** What exact customer-facing copy should be used for ineligible, expired, and unknown promo codes?
  - **Blocks:** Final UI copy for US-002 and US-003.
  - **Needed from:** Marketing / Product

- **Q-002:** What analytics event names should be used for promo validation outcomes?
  - **Blocks:** NFR-006 instrumentation details.
  - **Needed from:** Product / Data

- **Q-003:** Is welcome-promotion redemption already tracked in durable account state?
  - **Blocks:** Implementation planning for FR-002.
  - **Needed from:** Engineering

## 13. Risks

- **R-001:** Promo validation latency could slow checkout during campaign spikes.
  - **Impact:** Medium
  - **Mitigation:** Preserve a clear loading state, measure p95 latency, and use existing checkout resilience patterns.

- **R-002:** Eligibility error messages could expose more account history than needed.
  - **Impact:** Medium
  - **Mitigation:** Use generic but actionable copy and avoid revealing historical redemption dates or campaign internals.

- **R-003:** Moving promo entry could unintentionally alter payment-review behavior.
  - **Impact:** High
  - **Mitigation:** Cover checkout paths with and without promo codes in acceptance tests.

## 14. Planning Handoff

Use this approved PRD as input to `project-planner`.

- Preserve opportunity, decision, requirement, story, acceptance-criteria, constraint, assumption, open-question, and risk IDs.
- Convert requirements into outcome-oriented epics and vertical-slice tasks in `docs/project-plan.md`.
- Mark tasks blocked by unresolved questions as `HITL` or `Execution-ready: No`.
- Do not create Beads items directly from this PRD; use `project-planner` first, then `plan-to-beads-unified`.
