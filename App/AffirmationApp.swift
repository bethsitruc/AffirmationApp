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

// Uses SharedDefaults helper for shared UserDefaults and app group management
// Keys are now defined in SharedDefaults.swift
// TODO: Ensure the correct App Group ID is set in SharedDefaults.swift before release

@main // Marks this as the entry point of the SwiftUI app.
struct AffirmationApp: App {
    // Use a single, long-lived store instance for the app UI.
    @StateObject private var store = AffirmationStore()
    @StateObject private var appearance = AppearanceSettings()
    private let autoGenerator = AutoGenerationManager()
    private let homeRefresher = HomeFeedRefreshManager()

    // Use a small helper that fetches a fresh affirmation asynchronously.
    private let fetcher = FreshAffirmationFetcher()
    
    var body: some Scene {
        WindowGroup {
            // Pass the single store instance into the main view.
            AffirmationView(store: store)
                .environmentObject(appearance)
                // On startup ask for a fresh affirmation and publish it to an App Group
                // so widgets and extensions can read the same latest affirmation.
                .task {
                    if let text = await fetcher.fetch() {
                        SharedDefaults.set(text, forKey: UserDefaults.Keys.latestAffirmation)
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    await autoGenerator.runIfNeeded(store: store)
                    await homeRefresher.refreshIfNeeded(store: store)
                }
        }
    }
}
