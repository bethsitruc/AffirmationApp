import Foundation
import AffirmationShared

#if !os(iOSApplicationExtension)

@MainActor
final class AutoGenerationManager {
    private let fetcher = FreshAffirmationFetcher()
    private let fallback = LocalGenerator()

    func runIfNeeded(store: AffirmationStore) async {
        let cadence = AutoGenerationPreferences.cadence
        guard let interval = cadence.interval else { return }
        let now = Date()
        if let last = AutoGenerationPreferences.lastGeneratedDate,
           now.timeIntervalSince(last) < interval {
            return
        }

        let text: String
        if let fetched = await fetcher.fetch() {
            text = fetched
        } else if let local = try? await fallback.generate(theme: nil) {
            text = local
        } else {
            text = "You are enough."
        }
        store.addUserAffirmation(
            text: text,
            themes: [],
            isUserCreated: true,
            isAIGenerated: false
        )
        AutoGenerationPreferences.lastGeneratedDate = now
    }
}

@MainActor
final class HomeFeedRefreshManager {
    private let fetcher = FreshAffirmationFetcher()
    private let fallback = LocalGenerator()
    private let batchSize = 10
    private let maxHomeAffirmations = 80

    func refreshIfNeeded(store: AffirmationStore) async {
        let cadence = HomeFeedRefreshPreferences.cadence
        guard let interval = cadence.interval else { return }
        let now = Date()
        if let last = HomeFeedRefreshPreferences.lastRefreshDate,
           now.timeIntervalSince(last) < interval {
            return
        }

        let quotes = await fetchBatch(count: batchSize)
        apply(quotes, to: store)
        HomeFeedRefreshPreferences.lastRefreshDate = Date()
    }

    private func fetchBatch(count: Int) async -> [String] {
        var entries = await fetcher.fetchBatch(limit: max(50, count), includeAuthor: true)

        while entries.count < count {
            let local = (try? await fallback.generate(theme: nil)) ?? "You are enough."
            if !entries.contains(local) {
                entries.append(local)
            }
        }
        return Array(entries.prefix(count))
    }

    private func apply(_ quotes: [String], to store: AffirmationStore) {
        removeOutdatedEntries(from: store, maximum: quotes.count)

        let timestamp = Date()
        let newAffirmations: [Affirmation] = quotes.enumerated().map { offset, quote in
            Affirmation(
                text: quote,
                isFavorite: false,
                isUserCreated: false,
                themes: [],
                createdAt: timestamp.addingTimeInterval(Double(offset) * 0.5),
                isAIGenerated: false
            )
        }

        store.affirmations.insert(contentsOf: newAffirmations, at: 0)
        trimIfNeeded(store: store)
    }

    private func removeOutdatedEntries(from store: AffirmationStore, maximum: Int) {
        guard maximum > 0 else { return }
        let ids = Set(
            store.affirmations
                .filter { !$0.isFavorite }
                .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
                .prefix(maximum)
                .map(\.id)
        )
        guard !ids.isEmpty else { return }
        store.affirmations.removeAll { ids.contains($0.id) }
    }

    private func trimIfNeeded(store: AffirmationStore) {
        let overflow = store.affirmations.count - maxHomeAffirmations
        guard overflow > 0 else { return }
        let ids = Set(
            store.affirmations
                .filter { !$0.isFavorite }
                .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
                .prefix(overflow)
                .map(\.id)
        )
        guard !ids.isEmpty else { return }
        store.affirmations.removeAll { ids.contains($0.id) }
    }
}

#endif
