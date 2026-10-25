# Testing portfolio review — October 19, 2026

> This records the pre-expansion audit. See [the current testing guide](testing.md) for the subsequent implementation, verified coverage, and remaining integration checks.

## Assessment

The suite is a useful smoke-test and persistence baseline, but it is not yet a sufficient release gate for Grounded's complete feature set. Passing it demonstrates selected store behaviors and UI journeys; it does not demonstrate correct CloudKit transport, widget configuration, refresh policy, generation fallback, purchases, image export, or fold transitions.

This review covers the working tree including the adaptive Home grid, toolbar label/icon changes, and the rotation/share-picker test. It evaluates test effectiveness against user-facing risks, not just test counts. No production code or test behavior was changed during the review.

## Inventory

| Area | Existing automated coverage | Important limits |
| --- | --- | --- |
| Store | 11 Swift Testing cases: adding, favorite toggle, favorite tombstones, legacy migration, missing update/delete notifications, deletion tombstones, reload pruning, three remote merge scenarios | No existing-record edit/reload journey, favorite edit propagation/reload, deletion of a favorited personal entry, duplicate merges, timestamp ties, idempotence, malformed persistence recovery |
| Quote fetching | 3 cases: filtering/deduplication, omit attribution, HTTP failure | No malformed JSON, transport error/cancellation, empty/fully filtered payload, limits, blank/unknown authors |
| Preferences | 2 cases: cadence/date round trips and Home defaults | No appearance persistence, external cloud preference changes, or refresh scheduling behavior |
| Generation | 5 cases: theme/tone prompt strings | Checks wording, not execution of on-device → network → local fallback, output metadata, loading/error recovery, or saving generated results |
| UI | 4 XCTest methods: tab/create smoke, rotation/share-picker at accessibility XXXL, marketing captures, adaptive layout captures | No edit/delete/relaunch, assertions on card columns/pagination, theme/font changes, export verification, or explicit fold poses |
| Shared package | Test source contains an import and explanatory comment only | `swift test` is not an independent behavioral gate; shared behavior is partially exercised by the app test target |
| Widget | Built as app dependency | No widget-specific test target or assertions for source selection, missing/deleted selections, empty pools, timeline refresh, or rendering |
| CloudKit | Store merge tests using no-op coordinators | Real coordinators' record conversion, query pagination, save failures, overlapping syncs, and recovery are untested |
| StoreKit | No tests/configuration found | Product lookup, verification, success, cancellation, pending and failure paths are untested |

Total declared tests: **21 unit cases + 4 UI methods**. The layout method captures multiple scenarios, but those scenarios are not additional independent test cases.

## Highest-priority gaps

### 1. Make the Duo change verifiable

`UITests/AffirmationAppUITests.swift:61` rotates the device, opens/closes the share picker, and visits Favorites/Home. It does not open/partially fold/close Duo or check the resulting display geometry. Rotation and folding are distinct transitions. The earlier outer-display-only captures in this chat demonstrate why merely selecting a Duo simulator is insufficient.

Add explicit closed, fully open, and partially open scenarios with recorded pose/display identity. While retaining a scrolled feed and selected tab, transition poses and verify navigation remains available, cards stay readable, and share sheets can be dismissed. Include a favorite/personal edit sheet, keyboard, and accessibility text. Use supported simulator controls or a documented manual release check where pose automation is unavailable.

For the new grid (`App/Views/AffirmationView.swift:197`), seed a known feed larger than the initial six items, scroll to a known final item, and assert no omissions/duplicates. Verify one column at accessibility sizes and multiple columns at a sufficiently wide inner-display size. Exercise favorites after reflow. Check share-composer Done as well as picker Close; the new rotation test covers only the latter.

### 2. Protect personal data through complete journeys

Extend behavioral tests to edit an existing favorited personal affirmation, construct a fresh store, and verify updated text/themes/favorite state survived. Delete it and verify it stays absent from both personal and favorite libraries after reload and stale remote replay. Test cancel-delete and empty-text validation through UI. This guards user data more directly than adding more prompt-substring checks.

Add table-driven merge tests for newer local vs remote edits, tombstones in both directions, equal timestamps with an explicit expected policy, duplicate remote records, repeat application, and cross-channel delete/favorite interactions. Current merge cases are useful but cover only a small subset of this state space.

### 3. Test refresh and generation without real services

Inject a clock and fetch/generate closures or small protocols into refresh managers. Test disabled/not-yet-due/exactly-due schedules, offline fallback, preservation of favorites during replacement/trimming, feed size policy, date updates, and termination when fallback results repeat. `HomeFeedRefreshManager.fetchBatch` loops until it has enough unique entries; test bounded completion with repeated fallback values rather than relying on random success.

Inject the Foundation Models client behind a protocol. Assert preferred-source selection, fall-through on error/unavailability, final fallback when both network and local generation fail, metadata, and nonempty output. Keep actual Apple Intelligence quality/availability as a physical-device check, separate from deterministic unit tests.

### 4. Cover widgets, cloud transport, and support purchases

Extract widget text-selection and timeline policy into testable logic or add an appropriate widget test target. Cover pinned selection, favorites/personal shuffle pools, empty/deleted selections, persisted appearance, and refresh dates. Inspect widget gallery sizes and rendering modes separately.

Test CloudKit record codecs and coordinator state/error handling against a fake transport. Maintain a small two-device/account integration checklist for signed builds: create/edit/favorite/delete offline, reconnect, and confirm convergence without resurrection. No-op sync in UI tests is appropriate isolation, but it means those tests cannot validate CloudKit.

Add a local StoreKit configuration and tests for verified success, unverified results, cancellation, pending approval, unavailable products, and failure recovery. This can be done without real charges.

## Reliability and release automation

- **Hosted unit-test startup is not fully isolated.** `App/AffirmationApp.swift` computes `isRunningTests` for sync/observation, but the root `.task` only checks `-ui-testing-disable-background-refresh` before calling the real fetcher and `HomeFeedRefreshManager`. Unit-test hosting does not supply that UI launch flag. The fresh coverage report records one `refreshIfNeeded`, `fetchBatch`, and `apply` execution despite every UI test disabling refresh. This strongly indicates test-host startup exercised the live refresh path. Gate startup work on test state and inject service clients so tests cannot mutate data in the background or depend on external availability. Settings UI traversal also calls the real StoreKit product lookup; no purchase outcome is asserted.

- `UITests/SnapshotHelper.swift:41` captures and attaches screenshots but never compares pixels or asserts layout geometry. Treat these as visual-review artifacts, not snapshot regression tests. It also ignores the Boolean result of waiting for foreground and uses a fixed one-second sleep. Prefer explicit screen readiness assertions before capture.
- The capture file names use device and screen names, so repeated runs/poses overwrite files in the Fastlane cache. Result-bundle attachments are retained, but standalone artifacts should include run/pose identifiers.
- Store/preferences tests use the real shared defaults suite, and their cleanup calls `CloudPreferenceStore`, which accesses `NSUbiquitousKeyValueStore.default`. The snapshot helpers save local values rather than independent local/cloud state; restoration can overwrite the cloud copy and does not restore Data there. Prefer isolated defaults plus an in-memory cloud-preferences adapter. Avoid testing against a signed-in personal account.
- UI launches reset state every time. This makes tests repeatable but cannot prove data survives an app restart; add a relaunch without the reset argument.
- Only the widget scheme is committed as a shared scheme. Commit an explicit app scheme/test plan so intended test membership/configuration is reviewable and stable in automation; current local `xcodebuild -scheme AffirmationApp` resolves an implicit scheme.
- No CI workflow is checked into this repository. The only Fastlane lane captures marketing screenshots, explicitly selects one UI test, defaults to Xcode-beta, and its device list excludes Duo. External CI may exist, but is not evidenced here. A screenshots lane must not be treated as the complete test gate.

## Recommended gate

For each change: deterministic unit tests once, iPhone UI CRUD/relaunch and favorite smoke tests, and relevant feature tests. For adaptive UI changes: compact phone and iPad checks plus explicit Duo closed/open/partially-open checks in portrait/landscape and accessibility text. Retain result bundles and review named visual artifacts until automated visual checks exist.

Before a release: unsigned Release compilation for app/widget; oldest supported available OS validation (the app still declares iOS 16.6); physical-device CloudKit and Apple Intelligence checks; local StoreKit scenarios; widget gallery/appearance checks; export a real share image and inspect long text. The app and widget have different minimum OS versions; a modern simulator pass is not proof of minimum-version compatibility.

Prefer behavioral coverage of these critical paths over a global percentage target. Aggregate coverage can be inflated by UI traversal and still miss important outcomes.

## Execution evidence

Xcode 27.1 (27A9275), iOS 27.1 SDK, unsigned simulator builds. Historical September checks and earlier Duo smoke tests are supporting context, not substitutes for these fresh runs.

- Complete Duo run: **25/25 passed** (21 unit cases and 4 UI methods), with coverage enabled and parallel test execution disabled.
- Result bundle: `/tmp/grounded-portfolio-duo.xcresult`; build/test log: `/tmp/grounded-portfolio-duo.log`.
- Focused regression matrix: **4/4 passed** — tab/create and accessibility rotation/share-picker tests on iPhone 17e (iOS 26.5) and Grounded QA Tablet / iPad Pro 13-inch M5 (iOS 27.0). Bundle: `/tmp/grounded-portfolio-regression.xcresult`; log: `/tmp/grounded-portfolio-regression.log`.
- Combined execution: **29 passing test executions**, no test failures. App and widget compiled in the simulator test builds. Signed distribution, Release compilation, physical-device services, and iOS 16.6 were not rechecked in this audit.
- `git diff --check` passed.
- All 13 Duo layout captures from this run were 1398 × 2034, matching the earlier outer-display capture dimensions. This run does not establish unfolded or partially folded coverage.

| Measured area | Executable line coverage | Interpretation |
| --- | --- | --- |
| App target | 58.8% (3780/6424) | Combined unit/UI traversal; not assertion coverage |
| AffirmationStore | 79.5% | Useful baseline; important conflict outcomes remain absent |
| Edit screen | 3.2% | No editing/deletion UI journey |
| Appearance picker | 0% | No theme/font interaction |
| Both CloudKit coordinators | 0% each | Transport/coordinator behavior untested |
| Widget provider/view, intent, repository files | 0% each | Building the extension does not test widget behavior |
| Widget target aggregate | 27.0% | Includes source files also compiled into the app; misleading as widget feature coverage |
| Generator | 49.9% | Actual `generate(theme:tone:)` facade was not executed |
| Refresh manager file | 61.2% | Startup executed refresh without assertions on policy or outcomes |
| Purchase manager | 46.1% | Product loading ran; `purchase` and verification paths did not |

Coverage JSON: `/tmp/grounded-portfolio-coverage.json`. Percentages are diagnostics from this run, not recommended release thresholds.
