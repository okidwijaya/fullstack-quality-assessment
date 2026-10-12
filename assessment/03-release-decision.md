# Release Decision

Assessment date: 2026-10-11

**Version:** `v1.0.0` (not tagged)

**Decision:** PENDING — not approved for release.

**Accountable owner:** TBD

## P0/P1 Risk Acceptance

An unresolved P0/P1 finding blocks release unless the finding is explicitly accepted by a named owner with a rationale. The tag workflow checks this table against unresolved P0/P1 findings in `assessment/01-audit.md`.

| Finding ID | Disposition | Acceptance owner | Rationale |
|---|---|---|---|
| LOGIN-TENANT-SELECTION | Open — policy ambiguous | TBD | Policy decision is pending; no risk acceptance recorded. |

## Current State

- The API RSpec suite most recently completed with 20 examples and 0 failures in the existing test container.
- Cross-tenant portfolio export, portfolio-skill override, fit/gap report read/generation, Coverage WebSocket role authorization, and assessment deletion have regression coverage and recorded red-to-green checks.
- The Coverage WebSocket test simulates middleware callbacks; it does not verify a live handshake or Redis subscription.
- A project-owned CI workflow and pull-request template have been added locally, but no GitHub-hosted run has been observed for them.
- The checked-in frontend REST/WebSocket fallback and `.env.example` use port 3000 while the API defaults to 3001; copying the example without applying the README override will target the wrong port.

## Outstanding Risks and Release Criteria

1. Confirm the intended login tenant-selection policy. It remains unresolved and is not accepted in the risk table.
2. Address or explicitly accept the confirmed frontend default-port mismatch; no app-code change is claimed.
3. Run `quality-gate` on GitHub for a pull request and the target branch; record actual check-run URLs and results.
4. Configure branch protection to require `quality-gate` and PR review; repository settings are not controlled by this workflow.
5. Demonstrate and retain evidence of one PR blocked by the input gate and one PR that passes it.
6. Review remaining P2 findings and obtain explicit acceptance or remediation.
7. Prepare release notes and verify the final candidate against the tag release-readiness gate before creating a version tag.

## Decision Rationale

The passing local API suite is useful evidence but does not prove the new CI workflow, branch protection, remote PR scenarios, or all release criteria. Login tenant policy remains unresolved and unaccepted, the frontend default-port mismatch remains open, and there is no completed remote release check. Keep the decision pending and do not create `v1.0.0` until the criteria above are addressed and the accountable owner records an explicit decision.