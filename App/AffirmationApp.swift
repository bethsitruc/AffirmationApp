//
//  AffirmationApp
//
//  Created by Bethany Curtis on 4/4/25.
//
//  This is the entry point of the AffirmationApp.
//  It defines the main structure conforming to the App protocol,
//  and sets up the initial window and view hierarchy.
//

import AffirmationShared
import SwiftUI
import WidgetKit

// Uses SharedDefaults helper for shared UserDefaults and app group management.
// Ensure `Config.appGroup` matches the App Group enabled for app + widget targets.

@main // Marks this as the entry point of the SwiftUI app.
struct AffirmationApp: App {
    // Use a single, long-lived store instance for the app UI.
    @StateObject private var store = AffirmationStore()
    @StateObject private var appearance = AppearanceSettings()
    private let homeRefresher = HomeFeedRefreshManager()

    // Use a small helper that fetches a fresh affirmation asynchronously.
    private let fetcher = FreshAffirmationFetcher()

    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-state") {
            let keysToReset = [
                UserDefaults.Keys.latestAffirmation,
                UserDefaults.Keys.latestAffirmationFetchedAt,
                UserDefaults.Keys.affirmations,
                UserDefaults.Keys.userSubmittedAffirmations,
            ]
            keysToReset.forEach { SharedDefaults.removeObject(forKey: $0) }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            // Pass the single store instance into the main view.
            AffirmationView(store: store)
                .environmentObject(appearance)
                // Refresh the shared latest quote on a cadence so widgets stay fresh
                // without hitting the quote API on every launch.
                .task {
                    guard !ProcessInfo.processInfo.arguments.contains("-ui-testing-disable-background-refresh") else {
                        return
                    }
                    if shouldRefreshLatestAffirmation {
                        if let text = await fetcher.fetch() {
                            SharedDefaults.set(text, forKey: UserDefaults.Keys.latestAffirmation)
                            SharedDefaults.set(Date().timeIntervalSince1970, forKey: UserDefaults.Keys.latestAffirmationFetchedAt)
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    }
                    await homeRefresher.refreshIfNeeded(store: store)
                }
        }
    }

    private var shouldRefreshLatestAffirmation: Bool {
        let last = SharedDefaults.double(forKey: UserDefaults.Keys.latestAffirmationFetchedAt)
        guard last > 0 else { return true }
        let elapsed = Date().timeIntervalSince1970 - last
        return elapsed >= Config.latestAffirmationFetchInterval
    }
}
