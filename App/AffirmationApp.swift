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
import CloudKit
import SwiftUI
import WidgetKit

// Uses SharedDefaults helper for shared UserDefaults and app group management.
// Ensure `Config.appGroup` matches the App Group enabled for app + widget targets.

@main // Marks this as the entry point of the SwiftUI app.
struct AffirmationApp: App {
    @Environment(\.scenePhase) private var scenePhase

    // Use a single, long-lived store instance for the app UI.
    @StateObject private var store: AffirmationStore
    @StateObject private var appearance = AppearanceSettings()
    private let homeRefresher = HomeFeedRefreshManager()

    // Use a small helper that fetches a fresh affirmation asynchronously.
    private let fetcher = FreshAffirmationFetcher()

    init() {
        let syncCoordinator: any UserAffirmationSyncing
        let favoriteSyncCoordinator: any FavoriteLibrarySyncing
        if Self.isRunningTests {
            syncCoordinator = NoOpUserAffirmationSyncCoordinator()
            favoriteSyncCoordinator = NoOpFavoriteLibrarySyncCoordinator()
        } else {
            syncCoordinator = CloudUserAffirmationSyncCoordinator(
                containerFactory: { CKContainer.default() }
            )
            favoriteSyncCoordinator = CloudFavoriteLibrarySyncCoordinator(
                containerFactory: { CKContainer.default() }
            )
        }
        let store = AffirmationStore(
            syncCoordinator: syncCoordinator,
            favoriteSyncCoordinator: favoriteSyncCoordinator
        )
        _store = StateObject(wrappedValue: store)
        CloudPreferenceStore.startObserving()

        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-state") {
            let keysToReset = [
                UserDefaults.Keys.latestAffirmation,
                UserDefaults.Keys.latestAffirmationFetchedAt,
                UserDefaults.Keys.affirmations,
                UserDefaults.Keys.userSubmittedAffirmations,
                UserDefaults.Keys.deletedUserAffirmationTombstones,
                UserDefaults.Keys.favoriteAffirmations,
                UserDefaults.Keys.deletedFavoriteAffirmationTombstones,
                "appearance.theme",
                "appearance.font",
                "autoGeneration.cadence",
                "autoGeneration.last",
                "homeRefresh.cadence",
                "homeRefresh.last",
            ]
            keysToReset.forEach {
                SharedDefaults.removeObject(forKey: $0)
                CloudPreferenceStore.removeObject(forKey: $0)
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            // Pass the single store instance into the main view.
            withScenePhaseChange(
                AffirmationView(store: store)
                    .environmentObject(store)
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
                        startUserAffirmationSyncIfNeeded()
                    }
            )
        }
    }

    private var shouldRefreshLatestAffirmation: Bool {
        let last = SharedDefaults.double(forKey: UserDefaults.Keys.latestAffirmationFetchedAt)
        guard last > 0 else { return true }
        let elapsed = Date().timeIntervalSince1970 - last
        return elapsed >= Config.latestAffirmationFetchInterval
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    private func startUserAffirmationSyncIfNeeded() {
        guard !Self.isRunningTests else {
            return
        }
        store.startUserAffirmationSync()
    }

    @ViewBuilder
    private func withScenePhaseChange<Content: View>(_ content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: scenePhase) { _, newValue in
                guard newValue == .active else { return }
                startUserAffirmationSyncIfNeeded()
                store.refreshUserAffirmationSync()
            }
        } else {
            content.onChange(of: scenePhase) { newValue in
                guard newValue == .active else { return }
                startUserAffirmationSyncIfNeeded()
                store.refreshUserAffirmationSync()
            }
        }
    }
}
