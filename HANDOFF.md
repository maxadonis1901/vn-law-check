# Scanner URL and consent fixes

## Goal and contract

Fix the three scanner bugs approved on 2026-11-20: reject links whose
authority only starts with the requested origin, resolve relative page and
script links against their containing page, and ignore blocked tracking
scripts regardless of attribute order. Keep Bash 3.2, current CLI/output,
download limits and existing runtime dependencies. No legal-content changes.

## Plan

1. Add failing local HTTP tests in `tests/test_fetch_site.py`, wire them into
   `tests/run.sh`, and add consent fixtures in `tests/fixtures/`.
2. Fix `scripts/fetch-site.sh` and `scripts/scan.sh`; use each downloaded
   page's URL when resolving its scripts and inspect complete opening tags.
3. Run `bash tools/sync.sh`, all CI checks and one bounded independent
   review. Publish a reviewable PR without merging.

Acceptance gate: regressions fail on the original scripts and pass on the
fix; `bash tests/run.sh`, `bash tools/sync.sh --check`, shell syntax and
the CI YAML/JSON checks pass.

## Status and verification

- Base: `964f519`, branch `fix/scanner-url-consent`, isolated clone.
- Baseline: `bash tests/run.sh` PASS (12 fixtures); `bash tools/sync.sh --check` PASS.
- Changed: `scripts/fetch-site.sh`, `scripts/scan.sh`, new
  `scripts/tracking-preload.awk`, their generated plugin copies,
  `tests/run.sh`, `tests/test_fetch_site.py`, five `consent-*` fixture dirs,
  and this handoff.
- RED: original scripts failed the blocked-after-src fixture and origin,
  relative-page and relative-script HTTP regressions for the expected reasons.
- GREEN: `bash tests/run.sh` PASS (17 fixtures + 8 HTTP tests), Bash 3.2.
  HTTP tests use real curl and isolated localhost servers; hostname tests
  use curl connect-to mappings, without contacting external sites.
- `bash -n scripts/scan.sh scripts/fetch-site.sh tests/run.sh` PASS.
- `bash tools/sync.sh --check` PASS; `git diff --check` PASS.
- `python3 -c 'import json; [json.load(open(f)) for f in
  [".claude-plugin/marketplace.json", "plugins/vn-law-check/.claude-plugin/plugin.json"]]'` PASS.
- GitHub Actions `check` run 44659724461 PASS on implementation commit
  `ca34cd5`: sync, full suite, SKILL YAML frontmatter and plugin JSON.
  Local YAML check unavailable (PyYAML absent; host pip macOS detection fails);
  the exact required YAML check passed in GitHub CI.
- Independent read-only review found canonical-entry redirects and multiline
  script tags regressed. Both fixed in one pass, with RED -> GREEN tests.
  Script evidence retains original filename and line (manually checked).
- Decision: use the effective entry-page origin after canonical redirects;
  use POSIX awk for complete multiline opening tags, without new runtime deps.
- Existing limitations: external redirects remain followed by curl; parsing
  is heuristic (no browser execution or general HTML-parser guarantee).
  Legal content and legal outcomes were not reviewed in this phase.
- Status: complete; PR https://github.com/mhfed/vn-law-check/pull/16 merged by
  maintainer as `5dae122`; implementation and main CI passed.
- Rework cycles: 1 (review found two missing boundary cases; fixed together).
- Environment retries (not code rework): localhost sandbox access, PyYAML setup.
- Actual token usage: unavailable.

## Release v1.7.1 phase (2026-11-20)

- Goal: publish the approved scanner fixes as v1.7.1. The previous public
  release/tag is v1.5.3; plugin metadata was 1.7.0.
- Contract: bump only plugin version metadata; release notes also explain
  the v1.6/v1.7 features already present on main since the last public release.
  No scanner or legal-content changes in this phase.
- Base: `5dae122`, branch `release/v1.7.1`.
- Changed paths: `plugins/vn-law-check/.claude-plugin/plugin.json`, `HANDOFF.md`.
- Plan: validate metadata/sync, pass existing CI on release PR, merge the
  version update and publish v1.7.1 targeting that exact main commit.
- Acceptance gate: plugin JSON reports 1.7.1, sync and existing CI pass;
  GitHub release is public/latest and tag resolves to the versioned commit.
- Verification: metadata JSON/version assertion PASS;
  `bash tools/sync.sh --check` PASS; `git diff --check` PASS.
  GitHub Actions run 44667198729 PASS (17 fixtures + 8 HTTP tests,
  sync, YAML frontmatter, plugin JSON) before merging PR #17.
- Status: COMPLETE. PR #17 squash-merged as
  `a5875d6a493d0c57dfb15887fdb3de230641afa9`.
  https://github.com/mhfed/vn-law-check/releases/tag/v1.7.1 published as
  latest, not draft/prerelease. Release target and fetched tag both resolve
  to that exact commit; `git show v1.7.1:plugins/vn-law-check/.claude-plugin/plugin.json`
  confirms version 1.7.1. Latest-release API also verified publication.
- Risks: none introduced by the metadata change; existing scanner limitations
  remain documented in the previous phase.
- Next action: optional `scan.sh --json` phase, pending a separate request.
- This completion record is kept in the local checkout; the public tag
  remains the exact tested release commit.
- Rework cycles: 1 (source review restored controller roles, onward-transfer
  consequence, authority evidence condition and standard-form contract scope).
  Actual token usage: unavailable.

## JSON scanner phase (2026-11-20)

- Goal: add `scan.sh --json [target]` (also accept the flag after target)
  while preserving default text output and Bash 3.2. Primary implements;
  one independent read-only reviewer checks the completed phase.
- Contract/schema v1: `schema_version: 1`, original `target`, `scope`
  (mode, absolute root, URL download caps), `summary` (existing LEVEL/AI/
  FOREIGN_HOST/APP/TRACKING_CONSENT plus platforms), `signals` keyed by name
  with nullable `detected`, bounded `evidence` (`file`, nullable integer
  `line`, nullable `match`) and `evidence_limit`, and `limitations` codes.
  Null detection means not applicable, not a negative finding. Relative
  evidence paths are rooted at scope.root. No legal compliance verdict.
- Architecture: collect the scanner's raw result variables once for both
  formats; do not reparse human-readable reports or rerun the scan. A small
  Python 3 stdlib serializer is required only for --json; text has no new
  runtime dependency. Successful JSON stdout contains one JSON document;
  errors go to stderr with nonzero exit and no success document.
- Relevant paths: `scripts/scan.sh`, new `scripts/scan-json.py`,
  `tests/test_scan_json.py`, `tests/run.sh`, README.md, `.gitignore`; generated plugin
  scripts are updated only through `tools/sync.sh`.
- Plan: write failing CLI/summary/evidence/URL/escaping/applicability tests;
  implement; document the schema; sync; run suite + compatibility checks;
  one bounded independent review; open PR and wait for CI, without merging.
- Gate: all existing fixtures plus HTTP and JSON tests pass; directory
  text output matches pre-change snapshots; schema examples parse; sync,
  shell syntax and existing CI gates pass.
- Status: COMPLETE; PR https://github.com/mhfed/vn-law-check/pull/18 open,
  implementation CI green. No merge performed.
  Base: `a5875d6`.
- RED -> GREEN: unsupported --json and large-evidence argv overflow were
  reproduced before implementation changes. Raw fields now use NUL-delimited
  stdin, so large JS evidence does not become an OS command argument.
- `bash tests/run.sh` PASS: 17 fixtures, 8 HTTP tests, 13 JSON tests
  (including summary subtests for 16 existing directory fixtures).
- Exact pre-change text comparison PASS for all 16 directory fixtures.
- `bash -n scripts/scan.sh scripts/fetch-site.sh tests/run.sh` PASS;
  `bash tools/sync.sh --check` PASS; `git diff --check` PASS.
- Generated plugin smoke: --json on landing-form parses, consent=static.
- GitHub Actions `check` run 44669595489 PASS on implementation commit
  `b6536f1`: sync, all fixtures/HTTP/JSON tests, SKILL YAML and plugin JSON.
  Local YAML check not rerun (host PyYAML unavailable); the required check
  passed in GitHub CI.
- One read-only reviewer found an existing shorter filename prefix could
  steal evidence from a colon-containing filename, and Unicode/control line
  separators were incorrectly treated as LF. Both reproduced RED -> GREEN
  and fixed in one pass; the full suite and text compatibility check pass.
  Unicode preservation was treated as part of the evidence contract despite
  the reviewer grading that case minor. No findings were deferred.
- Next action: maintainer review/merge of PR #18. This documentation-only
  completion update records the verified implementation gate.
- Rework cycles: 1 (evidence boundary cases from independent review).
  Actual token usage: unavailable.

## Legal-source verification phase (2026-11-21)

- Goal: independently verify open legal-reference issues using original
  government publications; update supported claims, distinguish unresolved
  research from missing product facts and contested legal interpretation.
- Base: `52e0643` (JSON PR #18 merged); branch `docs/verify-legal-sources`.
- Contract: no invented article/penalty; preserve scope, conditions, party
  roles, exceptions and transition dates. Verification of published wording
  does not certify a particular site's compliance or a complete legal search.
- Start with #1-#4 (NĐ 330/2026 and 356/2025), then examine remaining issues.
  Edit source references and legal-reference ledger only, sync generated
  plugin copies; no scanner behavior change, no issue closure until review.
- Primary materials: original DOCX/PDF downloads from Công báo and signed
  government PDFs; scratch originals/extracted text under work/legal-verification.
- Acceptance: each new legal claim has a primary link + article/paragraph;
  compare material amounts/conditions in original PDFs; one independent
  read-only source/diff review; sync and existing CI pass; reviewable PR.
- Relevant paths: `references/08-penalties-reference.md`,
  `references/01-personal-data-protection.md`, relevant remaining checklist
  files, `sources/legal-references.md`, new verification ledger under sources/.
- Status: source/diff independently reviewed and corrected; published as
  https://github.com/mhfed/vn-law-check/pull/19 (open, not merged). Verified
  the published-wording questions in #1-#3 and #5; remaining issues have
  scoped findings and explicit open research in `sources/verification-2026-11-21.md`.
  No issue has been closed, and no scanner behavior was changed.
- Changed sources: `references/01-personal-data-protection.md`,
  `02-ecommerce.md`, `03-cybersecurity.md`, `04-consumer-protection.md`,
  `05-advertising.md`, `06-electronic-transactions.md`, `07-ai-transparency.md`,
  `08-penalties-reference.md`, `09-mobile-app.md`; `sources/legal-references.md`
  and `sources/verification-2026-11-21.md`; generated plugin copies via sync.
- Verification: `bash tests/run.sh` PASS (17 fixtures, 8 URL tests, 13 JSON
  tests); `bash tools/sync.sh --check` PASS; `git diff --check` PASS; existing
  plugin JSON parse PASS. Local YAML check not rerun (host PyYAML unavailable);
  GitHub CI passed all steps, including YAML, at implementation commit
  `88fbf1a2b893a1dc027c590e4fdfc05445336f5e`, run `44885630631`.
  Original Công báo PDF pages visually checked
  for Article 54/57 NĐ 330 and Article 41 NĐ 356, including the 72-hour harm
  condition, formal designation, accumulated threshold and exceptions.
- Risks: partial source research is explicitly retained; published text alone
  cannot establish a particular product's facts or resolve contested interpretation.
- Independent review: introduced claims checked against local primary extracts;
  all reported scope/role omissions corrected and confirmed in a bounded recheck.
- Next action/gate: maintainer review/merge PR #19. This completion-only
  handoff update records the verified implementation gate. Remaining source
  research is listed per issue in the verification ledger, not silently closed.
- Rework cycles: 1 (source review restored controller roles, onward-transfer
  consequence, authority evidence condition and standard-form contract scope).
  Actual token usage: unavailable.
