# Release Notes — Candidate v1.0.0

Status: candidate only; no release tag or GitHub CI run is claimed.

## Changes

- Tenant-scoped portfolio export, portfolio-skill overrides, fit/gap report reads, and fit/gap generation, including worker-side tenant validation.
- Coverage WebSocket now applies the existing assessor/admin role policy.
- Assessment deletion now reports a 422 error when dependent sessions prevent deletion, while successful deletion remains unchanged.
- Added request regressions for these authorization and deletion cases.
- Added a pull-request quality gate and a tag-triggered release-readiness check.

## Verification Recorded Locally

- Focused tenant-isolation regressions: observed red before fixes and green afterward.
- Coverage WebSocket role spec: 2 examples, 0 failures after the fix. It simulates middleware callbacks, not a network handshake or live Redis subscription.
- Assessment deletion spec: 2 examples, 0 failures after the fix.
- Latest API suite: 20 examples, 0 failures.
- Frontend production build (`npm run build`): TypeScript and Vite build passed.

These are local results. GitHub Actions has not yet run for this candidate.

## Known Limitations and Blockers

- Login tenant-selection policy remains ambiguous and unaccepted.
- The checked-in frontend defaults use port 3000, but the API defaults to 3001; the README instructs a manual override. Verify or correct this setup before release.
- Coverage WebSocket coverage is a simulated middleware callback test, not a network integration test.
- Branch protection, visible blocked/passing PR evidence, and tag-triggered CI remain unverified.
- Release decision remains pending; do not tag this candidate as released.