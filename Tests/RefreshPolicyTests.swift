import AffirmationShared
import Foundation
import Testing
@testable import AffirmationApp

extension GroundedTests {
    @MainActor
    @Suite("Home refresh policy")
    struct RefreshPolicyTests {
        @Test("Disabled and not-due refreshes leave data and dates untouched", arguments: [false, true])
        func skipsRefresh(disabled: Bool) async {
            let defaults = TestDefaults(); defer { defaults.restore() }
            HomeFeedRefreshPreferences.cadence = disabled ? .off : .daily
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            HomeFeedRefreshPreferences.lastRefreshDate = now.addingTimeInterval(-60)
            var fetches = 0
            let manager = HomeFeedRefreshManager(fetch: { fetches += 1; return ["New"] }, now: { now })
            let store = AffirmationStore(); let before = store.affirmations
            await manager.refreshIfNeeded(store: store)
            #expect(fetches == 0)
            #expect(store.affirmations == before)
            #expect(HomeFeedRefreshPreferences.lastRefreshDate == now.addingTimeInterval(-60))
        }

        @Test("Refresh at the exact cadence boundary preserves favorites, caps the feed, and persists")
        func dueRefresh() async throws {
            let defaults = TestDefaults(); defer { defaults.restore() }
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            HomeFeedRefreshPreferences.cadence = .daily
            HomeFeedRefreshPreferences.lastRefreshDate = now.addingTimeInterval(-86_400)
            let store = AffirmationStore()
            store.affirmations = (0..<85).map { Affirmation(text: "Old \($0)", createdAt: Date(timeIntervalSince1970: Double($0))) }
            let favorite = try #require(store.affirmations.first)
            store.toggleFavorite(for: favorite)
            let manager = HomeFeedRefreshManager(fetch: { (0..<10).map { "New \($0)" } }, now: { now })
            await manager.refreshIfNeeded(store: store)
            #expect(store.affirmations.count == 80)
            #expect(store.affirmations.contains { $0.id == favorite.id && $0.isFavorite })
            #expect(store.affirmations.filter { $0.text.hasPrefix("New ") }.count == 10)
            #expect(HomeFeedRefreshPreferences.lastRefreshDate == now)
            #expect(AffirmationStore().affirmations == store.affirmations)
        }

        @Test("Favorites are preserved even when they exceed the normal feed cap")
        func favoritesOverrideCap() async {
            let defaults = TestDefaults(); defer { defaults.restore() }
            HomeFeedRefreshPreferences.cadence = .daily
            let store = AffirmationStore()
            store.affirmations = (0..<81).map { Affirmation(text: "Favorite \($0)") }
            for item in store.affirmations { store.toggleFavorite(for: item) }
            await HomeFeedRefreshManager(fetch: { (0..<10).map { "New \($0)" } }).refreshIfNeeded(store: store)
            #expect(store.favoriteAffirmations().count == 81)
            #expect(store.affirmations.count == 81)
            #expect(store.affirmations.filter { !$0.isFavorite }.isEmpty)
        }

        @Test("Offline repeated fallback completes with ten unique nonempty entries")
        func repeatedFallbackIsBounded() async {
            let defaults = TestDefaults(); defer { defaults.restore() }
            HomeFeedRefreshPreferences.cadence = .daily
            var attempts = 0
            let manager = HomeFeedRefreshManager(fetch: { [] }, local: { attempts += 1; return "Repeated" })
            let store = AffirmationStore(); store.affirmations = []
            await manager.refreshIfNeeded(store: store)
            #expect(attempts <= 10)
            #expect(store.affirmations.count == 10)
            #expect(Set(store.affirmations.map(\.text)).count == 10)
            #expect(!store.affirmations.contains { $0.text.isEmpty })
        }
    }
}
