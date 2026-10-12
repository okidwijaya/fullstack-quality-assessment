# Quality System

## Continuous Integration Gate

The project workflow is `.github/workflows/quality-gate.yml`. The `quality-gate` job runs for pull requests targeting `main`, pushes to `main`, and version-tag pushes. It validates required pull-request sections, prepares an isolated PostgreSQL test database, runs RSpec, and runs the frontend production build. Any failed step fails the job.

CI provisions PostgreSQL 18 and Redis 8 as workflow services, matching the major versions observed in the current development/test environment. It uses Ruby 3.3.2 from the API runtime configuration, the checked-in Bundler lockfile, Node 20, and `npm ci` with the checked-in npm lockfile. The PostgreSQL password and JWT signing key in the workflow are disposable test-only values; no application credentials or AI-service keys are needed for the test job.

### Commands

Local API test command using the existing test container:

```sh
docker exec sedt-api-test sh -c 'bundle exec rspec'
```

Local frontend checks using the checked-in npm lockfile:

```sh
cd web
npm ci
npm run build
```

CI additionally runs `RAILS_ENV=test bundle exec rails db:prepare` before the API specs. On a fresh local setup, use a disposable test database; do not point this command at development or production data.

## Tag Release Readiness

Version tags matching `v*` run the same `quality-gate` checks and a dependent `release-readiness` job. The release job always runs for a version tag, even if quality checks fail, so it can report a clear `BLOCKED` result tied to `GITHUB_REF_NAME`. It blocks when quality checks failed, the release decision is not `APPROVED`, the accountable owner is missing, or any unresolved P0/P1 audit finding lacks an explicit `Accepted` disposition, named acceptance owner, and rationale in the P0/P1 risk table in `assessment/03-release-decision.md`.

The local release check is `python3 .github/scripts/release_readiness.py`; pass `GITHUB_REF_NAME` and `QUALITY_GATE_RESULT` to simulate the tag context. This local invocation is not a GitHub Actions run. Branch protection must separately require `quality-gate` on pull requests; the tag result does not replace that repository setting.

## Pull-Request Inputs

`.github/pull_request_template.md` requests:

- A linked specification or product requirement.
- Acceptance criteria and test scenarios.
- A solution/design plan.
- Tests added/updated and results.
- Security/data-isolation impact.
- Risks and rollback considerations.

The workflow checks that each corresponding section is present and has non-comment text. This is a machine-enforced completeness check, not semantic review: a non-empty section can still be incorrect or inadequate. Reviewers remain responsible for checking that the requirement and design are real and that tests exercise the acceptance criteria.

## Definition of Ready

A change is ready to start when:

1. It links to a specification, product requirement, or an explicit defect report.
2. It states observable acceptance criteria and relevant success, denial, validation, and failure scenarios.
3. It outlines the proposed design and affected API/data/security boundaries.
4. It identifies regression risk, test strategy, and rollback considerations.
5. Any ambiguous policy or missing product decision is resolved or recorded as a blocker.

## Definition of Done

A change is done when:

1. The implementation matches the approved acceptance criteria and remains narrowly scoped.
2. Relevant tests are added or updated; bug fixes include evidence of the failing test before the fix and passing test after it.
3. API specs and frontend build pass in the required gate.
4. Security and tenant-isolation effects are reviewed; no secrets are committed.
5. The PR contains completed required sections, and required CI status is green.
6. Release notes, release decision, and tag are handled only through the release process.

## Proving the Gate Blocks

To demonstrate the input gate, open a disposable PR with one required section empty and confirm the `quality-gate` check fails at PR-input validation. Then fill the section with reviewable information and rerun the PR to confirm the check advances through API specs and frontend build. Preserve the actual PR URLs and check-run links in the assessment record; no blocked/passing PR evidence is asserted by this document.

Repository branch protection is configured outside these files. An administrator must mark the `quality-gate` status check as required and require PR review before merge. Without that setting, workflow failure is visible but is not guaranteed to block merges.

## Known Limitations

- The current WebSocket spec simulates middleware callbacks, not a network handshake or live Redis pub/sub.
- The workflow validates presence of required PR content, not its correctness or adequacy.
- GitHub branch protection, actual PR scenarios, and GitHub-hosted workflow runs must be verified in repository settings and on GitHub.
- Login tenant-selection policy remains ambiguous; the audit does not treat it as a confirmed defect. The tag gate treats unresolved P0/P1 findings as blocking unless accepted by a named owner with rationale.
- Any test failure must be investigated from its output. Do not weaken assertions or retry by disabling checks.