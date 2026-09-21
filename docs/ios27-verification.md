# iOS 27 verification — September 18, 2026

## Toolchain and compatibility

- Xcode 27.0, build 27A266a; iOS 27 SDK.
- iOS 27 simulator build 24A434. `xcodebuild -downloadPlatform iOS` resolved this installed runtime; no newer runtime was offered.
- App minimum deployment remains iOS 16.6; widget minimum remains iOS 17.
- Unit/UI test targets now require iOS 17 to match Xcode 27's test frameworks and eliminate linker deployment warnings.
- Project upgrade marker updated to Xcode 27.

## Changes found through visual inspection

- At accessibility text sizes, the Home Apple Intelligence card now places its icon, text, and disclosure indicator vertically, giving its message the full available width.
- UI tests select a hittable tab when iPadOS exposes nested elements with duplicate tab labels.
- Tests reset orientation and default text size between scenarios and retain screenshot attachments in the result bundle.
- Use display screenshots for landscape: the iOS 27 app screenshot API returned cropped, partly black rotated images.

## Validation

- Unsigned Release build for generic iOS device: succeeded (app and widget).
- Full isolated matrix: 72 passing runs (21 unit tests plus 3 UI tests on each device).
- Final layout recheck: passed on all three devices after the final card-width and screenshot changes.
- Inspected 54 captures; no remaining horizontal clipping in the checked layouts. At the largest accessibility size, the compact phone’s submit label wraps across several lines; content remains scrollable.
- Review completed September 21 using the September 18 captures.
- Dedicated simulators avoid interference from other projects using the default devices.

| Simulator | Device | Coverage |
| --- | --- | --- |
| Grounded QA Compact | iPhone 17e | Portrait, landscape, accessibility XXXL |
| Grounded QA Large | iPhone 18 Pro Max | Portrait, landscape, accessibility XXXL |
| Grounded QA Tablet | iPad Pro 13-inch (M5) | Portrait, landscape, accessibility XXXL |

Screens cover Home, Favorites, My Affirmations, Settings, and share-card composition. UI tests also create and save an affirmation. Accessibility and landscape checks cover all four main tabs; accessibility Home includes a scrolled capture.

Local evidence is in `build/ios27-visual/verified/`. Test result bundles are `/tmp/grounded-ios27-isolated.xcresult` and `/tmp/grounded-ios27-final-layouts.xcresult`; Release build output is `/tmp/grounded-ios27-release.log`.

## Re-run

With the named dedicated simulators available:

```sh
xcodebuild test -project AffirmationApp.xcodeproj -scheme AffirmationApp \
  -destination 'platform=iOS Simulator,name=Grounded QA Compact' \
  -destination 'platform=iOS Simulator,name=Grounded QA Large' \
  -destination 'platform=iOS Simulator,name=Grounded QA Tablet' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO
```

## Limits

This validates simulator layouts and compilation, not signed distribution or on-device behavior. Arbitrarily resized iPad windows, Dark Mode, widget gallery rendering, and live Apple Intelligence generation were not visually tested in this pass. The widget is included in the successful build.
