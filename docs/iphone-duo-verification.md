# iPhone Duo update — October 19, 2026

## Toolchain

Xcode 27.1 (27A9275) at `/Applications/Xcode.app`, with the iOS 27.1 SDK and iPhone Duo simulator. The project was opened in this Xcode app. Deployment targets remain unchanged.

## Changes

- Home uses a lazy adaptive grid based on available container width, replacing text-length-based row pairing. Cards retain their identity as the display resizes, and accessibility text uses one column.
- Home pagination stops requesting additional rows once the available feed is exhausted.
- Share picker, share composer, and Home sheet dismissal buttons provide both labels and SF Symbols so system toolbars can present them vertically or in overflow menus.

These changes follow [Apple's preparation guidance](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo), using standard SwiftUI containers and semantic toolbar placements.

## Validation

- Xcode 27.1 compiled the app, widget, and test targets for iPhone Duo.
- `testLaunchTabsAndAddAffirmation` passed on the iPhone Duo simulator, covering all four tabs and creation of a personal affirmation.

- `testNavigationAndSharingSurviveRotation` passed on iPhone Duo in portrait and landscape with accessibility XXXL text, covering share-sheet dismissal and navigation back to Home.
- `git diff --check` passed.

## Limits

Simulator verification does not cover physical hardware, signed distribution, or transitions between folded, partially folded, and fully open poses. Those pose transitions still need a dedicated visual check before release.
