# AffirmationApp

Affirmation App is a fun and motivating app that aims to incorporate AI to generate new positive quotes and affirmations regularly. While the goal is to provide fresh, uplifting affirmations powered by AI, the current version is quite basic but still delivers a variety of positive quotes to keep you inspired each day.

## Features
- **Apple Foundation Model Suggestions (iOS 18+)**: Ask Apple Intelligence for a concise first-person affirmation, optionally guiding tone and theme. When Apple Intelligence is unavailable the app gracefully falls back to the affirmations.dev API and local seeds.
- **Favorite Your Affirmations**: Users can favorite affirmations they love, and view them easily.
- **Home Screen Widget**: Display a favorite affirmation directly on your home screen! You can choose to show a single affirmation or have it rotate through your favorites.
- **Regular Updates**: New affirmations are generated regularly to keep the content fresh and engaging.

## App Store blurb & widget instructions
Use this copy for the App Store “What’s New” or description to keep onboarding outside the Home tab:

> **How to add the widget**
> 1. Long‑press the Home Screen and tap the **+** button.  
> 2. Search for *AffirmationApp* and choose either **Affirmation** (pin one saying) or **Affirmation Shuffle** (auto-rotating).  
> 3. Tap the widget once it’s placed to pick your source (Favorites, My Affirmations, or All), select a specific affirmation, font, and shuffle cadence.  
> 4. Revisit the widget editor anytime to update the look.
>
> **Need a refresher?** Open the app, tap the **i** button in the top right, and use “Reload Widget Timelines” to nudge updates.

## Apple Intelligence integration
Apple’s Foundation Models framework (available on iOS/iPadOS 18+ / macOS 15+) now powers the “Ask Apple Intelligence” buttons on the Home tab and in the “Submit Affirmation” sheet. The integration works as follows:

1. **On-device first** – We check `SystemLanguageModel.default.availability` and stream a short prompt through `LanguageModelSession` with guardrails that enforce inclusive, first‑person phrasing.
2. **Clear feedback** – The UI surfaces the tone, optional theme, and whether the suggestion came from Apple Intelligence, the affirmations.dev API, or the deterministic local fallback.
3. **Graceful fallbacks** – If Apple Intelligence isn’t enabled on the device (or you’re building on older SDKs) we automatically call the small affirmations.dev endpoint, and finally the local generator so users always get a result.

> **Developer setup**
> - Build with Xcode 16+ (ships the `FoundationModels` framework) and run on iOS 18/macOS 15 simulators or devices with Apple Intelligence enabled under *Settings ▸ Siri & Language*.
> - No API keys are required because the default `LanguageModelSession` uses on-device models. The HTTP fallback only touches `https://www.affirmations.dev/`.
