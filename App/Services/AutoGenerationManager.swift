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
    private let fetch: () async -> [String]
    private let local: () async -> String
    private let now: () -> Date
    private let batchSize = 10
    private let maxHomeAffirmations = 80

    init(
        fetch: @escaping () async -> [String] = { await FreshAffirmationFetcher().fetchBatch(limit: 50, includeAuthor: true) },
        local: @escaping () async -> String = { (try? await LocalGenerator().generate(theme: nil)) ?? "You are enough." },
        now: @escaping () -> Date = Date.init
    ) {
        self.fetch = fetch
        self.local = local
        self.now = now
    }

    func refreshIfNeeded(store: AffirmationStore) async {
        let cadence = HomeFeedRefreshPreferences.cadence
        guard let interval = cadence.interval else { return }
        let now = now()
        if let last = HomeFeedRefreshPreferences.lastRefreshDate,
           now.timeIntervalSince(last) < interval {
            return
        }

        let quotes = await fetchBatch(count: batchSize)
        apply(quotes, to: store)
        HomeFeedRefreshPreferences.lastRefreshDate = now
    }

    private func fetchBatch(count: Int) async -> [String] {
        var seen = Set<String>()
        var entries = await fetch().filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && seen.insert($0).inserted }

        // A local provider can repeat forever; bound retries, then fill from known seeds.
        for _ in 0..<count where entries.count < count {
            let candidate = await local()
            if !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               seen.insert(candidate).inserted {
                entries.append(candidate)
            }
        }
        for seed in AffirmationSeeds.all where entries.count < count {
            if seen.insert(seed.text).inserted { entries.append(seed.text) }
        }
        return Array(entries.prefix(count))
    }

    private func apply(_ quotes: [String], to store: AffirmationStore) {
        removeOutdatedEntries(from: store, maximum: quotes.count)

        let timestamp = now()
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
