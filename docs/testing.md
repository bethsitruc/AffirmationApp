# Grounded test suite

## Local gate

Use Xcode 27.1 with an installed iPhone Duo / iOS 27.1 simulator:

```sh
./scripts/test.sh
```

The script runs the standalone shared-package tests, then all app unit/UI tests with coverage, saves logs and an `.xcresult` under `build/test-results/<run>/`, and exports coverage JSON. It exits unsuccessfully if either suite fails. `bundle exec fastlane ios test` runs the same gate. The marketing screenshots lane remains separate.

Select another installed simulator or toolchain explicitly:

```sh
TEST_DESTINATION='platform=iOS Simulator,name=iPhone 17e,OS=26.5' ./scripts/test.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/test.sh
```

Pass Xcode test selectors as extra arguments when developing; omit selectors for a release gate. The committed app scheme includes both app test targets and coverage. No external CI account or hosted-runner installation is assumed by this local gate.

## Coverage added after the portfolio review

- Library: existing favorite edit/reload, deletion plus stale replay/reload, local edit precedence, timestamp ties, duplicate records, merge idempotence, corrupt-data recovery.
- Quote fetching: malformed/empty/filtered payloads, request limits, transport failure, cancellation, author/whitespace formatting.
- Home refresh: disabled/not-due/exactly-due scheduling, persistence, favorite retention, soft feed cap, offline fallback and bounded completion with repeated local results.
- Generation: preferred on-device execution, failure/unavailability falling through to network, offline local output, emergency text and metadata.
- CloudKit: actual coordinator record/tombstone operations via fake operation submission, stable favorite identity, fetch/save failures, recovery and overlapping-request coalescing. These checks do not contact an iCloud account.
- Widgets: the extension uses the shared selection and refresh policy tested for pinning, source pools, missing/deleted selections, empty/corrupt persistence, fallback behavior and refresh dates.
- Purchases: localized prices, missing products, lookup errors, successful-result presentation and rejection of unverified StoreKit payloads, pending, cancellation, failure/retry, stale notices and overlapping taps through an injected client.
- Sharing: the production renderer exports a long-text image in every theme, with/without branding; output dimensions and PNG decoding are asserted. Pixel-level clipping is still a visual check.
- UI: add/validate/edit/cancel deletion/delete/relaunch, persisted appearance, all 18 uniquely identified feed cards after pagination, favorite behavior after rotation, single-column accessibility layout and composer dismissal after rotation.
- Shared package: real standalone model tests for legacy decoding, round trips, normalized favorite keys and stable personal identity.

Tests use a separate defaults suite (`<app group>.tests`) and local preference storage. Hosted-test startup does not fetch quotes, start sync, or query live StoreKit. The root unit suite serializes tests that share fixtures. Relaunch tests keep the `-ui-testing` argument while removing the reset flag, so they verify persistence without accessing production storage.

## Duo fold transition gate

XCTest provides rotation but has no fold-control API in the installed SDK. This opt-in test requires a tester to operate Device Hub; it cannot pass solely because the selected simulator is called Duo:

```sh
TEST_RUNNER_GROUNDED_DUO_POSES=1 xcodebuild test \
  -project AffirmationApp.xcodeproj -scheme AffirmationApp \
  -destination 'platform=iOS Simulator,name=iPhone Duo' \
  -parallel-testing-enabled NO GROUNDED_DUO_POSES=1 CODE_SIGNING_ALLOWED=NO \
  -only-testing:AffirmationAppUITests/AffirmationAppUITests/testDuoFoldTransitionsPreserveFavorites
```

Follow `DUO POSE REQUEST` messages: **Open → Closed → Open**. Each stage has a 60-second timeout and checks the application's actual width. The inner-display stage asserts multiple card columns; subsequent stages assert the favorite remains visible. Named screenshots are attached to the result bundle.

The normal gate reports this case as skipped. On October 23, 2026, the opt-in test passed with Device Hub driving Open → Closed → Open on iOS 27.1. It checked actual display widths, multiple feed columns, and favorite retention through both transitions. Partial folding, camera/fold occlusion, the keyboard while folding, and physical-device behavior still require visual release checks; the test does not claim to validate those poses.

## Local StoreKit integration gate

`Tests/SupportPurchases.storekit` defines local consumable products. An opt-in test uses the real StoreKit adapter and `SKTestSession` to check verified purchase completion and pending approval, without charging a real account:

```sh
TEST_RUNNER_GROUNDED_STOREKIT_INTEGRATION=1 xcodebuild test \
  -project AffirmationApp.xcodeproj -scheme AffirmationApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -parallel-testing-enabled NO GROUNDED_STOREKIT_INTEGRATION=1 \
  -only-testing:AffirmationAppTests/GroundedTests/StoreKitIntegrationTests
```

The normal deterministic gate reports this case as disabled/skipped. The integration test requires a functioning StoreKit testing service and asserts that the session accepts `disableDialogs` before attempting a transaction. In this workspace's simulator, that service returned `SKInternalErrorDomain code 3`, even with ad-hoc signing. The explicitly enabled check therefore fails early; it is not counted as a verified integration pass. Fake-client purchase outcome tests and a direct test of the production verification boundary remain in the normal gate. These service symptoms also match [reports on Apple Developer Forums](https://developer.apple.com/forums/thread/826971); that does not establish that our simulator has the same underlying cause.

## Remaining integration boundaries

CloudKit query cursor pagination and server conflict behavior, true cross-device convergence, Apple Intelligence output quality, widget gallery/rendering modes, payment verification against Apple's services, and minimum iOS 16.6 behavior need separate integration/device checks. Do not substitute a coverage percentage for these checks. Screenshot capture tests provide artifacts, not automatic pixel-diff approval.

## Verified results — October 19, 2026

The checked-in `scripts/test.sh` completed successfully with Xcode 27.1 (27A9275):

| Gate | Result |
| --- | --- |
| App unit methods | 55 passed; 1 opt-in StoreKit integration case disabled |
| Duo UI methods | 9 passed; 1 interactive fold case skipped |
| Standalone shared-package methods | 2 passed |
| Additional iPad checks | Edit/delete/relaunch, appearance persistence, and pagination/favorite rotation: 3 passed |
| Production Release app + widget build | Passed, unsigned generic iOS build |

That is **66 passing regular test methods**, compared with 25 in the audited baseline. Parameterized methods additionally exercise multiple inputs. The app result bundle reports 64 passed, 0 failed, 2 skipped; the separate package run contributes the other 2 passes. A final targeted recheck of the strengthened purchase-concurrency assertions also passed.

The opt-in StoreKit check was explicitly enabled and failed its service-readiness assertion (`SKInternalErrorDomain code 3`), before attempting a transaction. The fold test compiled but could not be driven because the Mac was locked. Neither is counted as passing. These are remaining environment/integration checks, not silent substitutes for the normal gate.

Local evidence:

- `build/test-results/expanded-suite/app.xcresult`
- `build/test-results/expanded-suite/app.log`
- `build/test-results/expanded-suite/shared.log`
- `build/test-results/expanded-suite/coverage.json`
- `build/test-results/expanded-suite/summary.json`
- `/tmp/grounded-expanded-tablet.log`
- `/tmp/grounded-release-verified.log`
- `/tmp/grounded-storekit-final.log`
- `/tmp/grounded-purchase-concurrency-check.log`

The new tests prompted fixes for unbounded offline refresh retries, fetch failures being hidden by successful uploads, overlapping purchase requests/stale purchase notices, and live service work during hosted-test startup. No signed distribution or external CI run was performed.


## Follow-up verification — October 23, 2026

The interactive Duo transition test passed with Xcode 27.1 / iOS 27.1. Its first attempt timed out waiting for the simulator to be opened; after setting the initial Open pose, the complete Open → Closed → Open sequence passed. StoreKit integration is excluded at the user's request; deterministic purchase tests remain included.

Fold evidence: `build/test-results/20261023-fold/app.xcresult` and `app.log`. XCTest's `XCUIScreen.main` screenshot attachments select the outer display even after reopening, so they must not be treated as inner-display captures. Actual display width assertions and Device Hub observation verified the reopened inner display.

The unfolded follow-up exposed two UI-test navigation assumptions: a single app-wide swipe did not reach Typography or paginate the feed. The tests now scroll the actual settings collection/feed scroll view with bounded retries and keep their original selection, persistence, item-count and favorite assertions. Both corrected tests passed on the inner display before rerunning the complete gate.

Final complete gate: `build/test-results/20261023-final/app.xcresult`, `app.log`, `shared.log`, `summary.json`, and `coverage.json`. Result: **64 app/UI methods passed, 0 failed, 2 skipped**, plus **2 shared-package methods passed**. StoreKit is deliberately skipped. The interactive fold case is skipped only in the unattended gate and passed separately (also rerun successfully in `build/test-results/20261023-fold-final.xcresult`), bringing verified distinct passing methods to **67** across the regular and interactive gates.

Verified display captures are in `build/iphone-duo-screenshots/fold-transitions-final-20261023/duo-open.png` (2853×2007 inner display) and `duo-closed.png` (1398×2034 outer display). The inner image was captured directly from the active simulator display during the fold test. An experiment with `app.screenshot()` produced a black inner-display image, so the existing screenshot API was retained and this simulator limitation is documented instead of treating that artifact as visual proof.
