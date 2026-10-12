# Quality Audit

Audit date: 2026-10-11

## Scope and Evidence

This review covers the API authorization paths, the frontend API configuration, and the request tests relevant to the findings below. The latest recorded API suite result is from the existing test container: 20 examples, 0 failures. The WebSocket authorization spec simulates middleware callbacks; it does not exercise a network handshake or Redis subscription. RSpec output includes an unavailable-jemalloc preload warning, which did not prevent execution.

## Ranked Findings

### P1 — [PORTFOLIO-EXPORT] Cross-tenant portfolio export: fixed

**Impact:** A tenant assessor could retrieve another tenant's completed portfolio through its resource ID.

**Evidence:** `api/app/controllers/api/v1/portfolios_controller.rb` scopes the export portfolio lookup through its tenant-scoped session. `api/spec/requests/tenant_isolation_spec.rb` covers same-tenant export success and cross-tenant denial.

**Verification:** Before the fix, the focused regression reported 1 example, 1 failure: the foreign-tenant export returned 200 instead of 404. After the fix, it reported 1 example, 0 failures; the full API suite then reported 9 examples, 0 failures.

**Status:** Fixed and regression-tested.

### P1 — [PORTFOLIO-SKILL-OVERRIDE] Cross-tenant skill override: fixed

**Impact:** A tenant assessor could write an override to a skill belonging to another tenant's portfolio.

**Evidence:** `api/app/controllers/api/v1/portfolio_skills_controller.rb` scopes the skill lookup through its portfolio and tenant-scoped session. The request spec checks same-tenant creation and cross-tenant denial.

**Verification:** Before the fix, the focused tenant spec reported 2 examples, 1 failure: the foreign skill override returned 201 instead of 404. After the fix, it reported 2 examples, 0 failures; the full API suite then reported 10 examples, 0 failures.

**Status:** Fixed and regression-tested.

### P1 — [FIT-GAP-REPORT-READ] Cross-tenant fit/gap report disclosure: fixed

**Impact:** A tenant assessor could read a report attached to another tenant's portfolio and vacancy.

**Evidence:** `PortfoliosController#show_fitgap` now resolves the portfolio through tenant-scoped sessions, the vacancy through its tenant scope, and the report through that vacancy constrained to the authorized portfolio. The request spec covers a same-tenant report and a foreign-tenant report.

**Verification:** Before the fix, the focused tenant spec reported 3 examples, 1 failure: a tenant-A request received 200 for tenant B's report instead of 404. After the fix, it reported 3 examples, 0 failures; the full API suite then reported 11 examples, 0 failures.

**Status:** Fixed and regression-tested.

### P1 — [FIT-GAP-GENERATION] Cross-tenant fit/gap generation: fixed

**Impact:** A tenant assessor could previously ask either generation endpoint to enqueue work for a portfolio belonging to another tenant, paired with a vacancy in the assessor's tenant. The asynchronous worker also accepted mismatched portfolio/vacancy ownership, so controller checks alone would not have protected report generation.

**Evidence:** `api/app/controllers/api/v1/portfolios_controller.rb` scopes `fitgap` and `regenerate_fitgap` portfolios through tenant-scoped `Session` records. `api/app/workers/fit_gap_generator_worker.rb` compares the owning session and vacancy tenant IDs and skips mismatched jobs before invoking the generator.

**Verification:** Before the fix, `docker exec sedt-api-test sh -c 'bundle exec rspec spec/requests/tenant_isolation_spec.rb'` reported 8 examples, 3 failures: both controller actions enqueued jobs for foreign portfolios, and the worker invoked the generator for a mismatched tenant pair. After the fix, the same command reported 8 examples, 0 failures; the full API suite reported 16 examples, 0 failures at that point.

**Status:** Fixed; cross-tenant and same-tenant controller/worker behavior is regression-tested. No claim is made here about other background jobs.

### P1 — [COVERAGE-WS-ROLE] Coverage WebSocket role authorization: fixed

**Impact:** A valid same-tenant JWT with a role outside the assessor policy could previously subscribe to coverage updates.

**Evidence:** `api/app/channels/coverage_websocket_middleware.rb` now delegates token validation and role enforcement to `AuthorizeApiRequest` with `:assessor`. The existing `ASSESSOR_ROLES` policy in `api/app/auth/authorize_api_request.rb` permits `admin` and `assessor`; the local `User` model also defines `user`, which is not allowed by that policy.

**Verification:** Before the fix, `docker exec sedt-api-test sh -c 'bundle exec rspec spec/requests/coverage_websocket_spec.rb'` reported 2 examples, 1 failure: the `user` token reached `send_current_state`; the admin control passed. After the fix, it reported 2 examples, 0 failures. The full API suite then reported 18 examples, 0 failures.

**Limitation:** The spec invokes middleware callbacks with a simulated Faye socket. It verifies the authorization decision, error frame, close callback, and authorized state/subscription path; it does not exercise a network-level WebSocket handshake or a live Redis subscription.

**Status:** Fixed for the tested callback flow; network-level integration remains unverified.

### P1 — [LOGIN-TENANT-SELECTION] Login tenant selection: policy ambiguous

**Impact:** Login signs the tenant scheme into the token from `X-Tenant-Scheme`, or falls back to the first organization returned by a query without ordering. `User` has no tenant-membership association. If login is meant to restrict users to assigned tenants, this could permit tenant selection without membership validation.

**Evidence:** `api/app/controllers/api/v1/authentication_controller.rb` accepts the header and includes the resulting scheme in the token. `api/app/models/user.rb` validates roles and credentials but has no tenant relationship. The repository does not establish whether a global administrator may intentionally select any tenant.

**Status:** Open specification ambiguity, not a confirmed exploitable defect. No behavior change is recommended until the intended login/tenant policy is confirmed.

**Outstanding question:** Is this account a global administrator allowed to select any organization, or must every login be authorized against tenant membership? Add request coverage once that policy is decided.

### P2 — [ASSESSMENT-DELETE-RESPONSE] Assessment deletion response: fixed

**Impact:** The `Assessment` model uses `dependent: :restrict_with_error` for sessions. Previously, `AssessmentsController#destroy` ignored whether the record was actually destroyed and returned a success message when the restriction aborted deletion.

**Evidence:** `api/app/models/assessment.rb` declares the restriction; `api/app/controllers/api/v1/assessments_controller.rb` calls `@assessment.destroy` and unconditionally responds with `Assessment deleted`.

**Verification:** Before the fix, the focused request spec reported 2 examples, 1 failure: deleting an assessment with a session returned 200 instead of 422 while the record remained. After the fix, it reported 2 examples, 0 failures; the full API suite then reported 20 examples, 0 failures. The no-session control still returns 200 and removes the record.

**Status:** Fixed and regression-tested; the model restriction remains in place.

### P2 — [FRONTEND-API-PORT] Frontend API fallback port: confirmed setup mismatch

**Impact:** Copying `web/.env.example` unchanged points REST and WebSocket traffic to port 3000, while `api/config/puma.rb` defaults to 3001. The web README's edited example uses 3001, so developers who follow that correction may avoid the issue.

**Evidence:** `web/.env.example` and `web/src/services/api.ts` default REST and WebSocket URLs to port 3000, while `api/config/puma.rb` defaults the API to 3001. `web/README.md` tells readers to edit the copied environment file to 3001, but its quick-start default still says 3000.

**Status:** Confirmed configuration mismatch for the copy-as-is quick start; no browser request was run. It is not asserted to affect deployments that provide an explicit URL. No application change is included because this repo has no frontend unit-test harness to safely guard the fallback change.

## Remaining Verification

- Confirm login tenant-selection policy before classifying it as a security defect.
- Align and test the frontend's checked-in default ports when a minimal regression test is available.
- Consider a real WebSocket integration test when a reliable test server/Redis harness is available.