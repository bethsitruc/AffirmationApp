import Foundation
import AffirmationShared

#if !os(iOSApplicationExtension)

@MainActor
final class AutoGenerationManager {
    private let generator = AffirmationGenerator()

    func runIfNeeded(store: AffirmationStore) async {
        let cadence = AutoGenerationPreferences.cadence
        guard let interval = cadence.interval else { return }
        let now = Date()
        if let last = AutoGenerationPreferences.lastGeneratedDate,
           now.timeIntervalSince(last) < interval {
            return
        }

        let result = await generator.generate(theme: nil)
        store.addUserAffirmation(
            text: result.text,
            themes: [],
            isUserCreated: true,
            isAIGenerated: result.source == .foundationModel
        )
        AutoGenerationPreferences.lastGeneratedDate = now
    }
}

@MainActor
final class HomeFeedRefreshManager {
    private let generator = AffirmationGenerator()
    private let batchSize = 10
    private let maxHomeAffirmations = 80
    private let themePool: [String] = [
        "self-worth", "confidence", "motivation", "growth",
        "optimism", "kindness", "resilience", "gratitude"
    ]

    func refreshIfNeeded(store: AffirmationStore) async {
        let cadence = HomeFeedRefreshPreferences.cadence
        guard let interval = cadence.interval else { return }
        let now = Date()
        if let last = HomeFeedRefreshPreferences.lastRefreshDate,
           now.timeIntervalSince(last) < interval {
            return
        }

        let results = await generateBatch(count: batchSize)
        apply(results, to: store)
        HomeFeedRefreshPreferences.lastRefreshDate = Date()
    }

    private func generateBatch(count: Int) async -> [AffirmationGenerator.Result] {
        var entries: [AffirmationGenerator.Result] = []
        for index in 0..<count {
            let theme = themePool.isEmpty ? nil : themePool[index % themePool.count]
            let tone = AffirmationGenerator.Tone.allCases[index % AffirmationGenerator.Tone.allCases.count]
            let result = await generator.generate(theme: theme, tone: tone)
            entries.append(result)
        }
        return entries
    }

    private func apply(_ results: [AffirmationGenerator.Result], to store: AffirmationStore) {
        removeOutdatedEntries(from: store, maximum: results.count)

        let timestamp = Date()
        let newAffirmations: [Affirmation] = results.enumerated().map { offset, result in
            Affirmation(
                text: result.text,
                isFavorite: false,
                isUserCreated: false,
                themes: result.metadata.theme.map { [$0] } ?? [],
                createdAt: timestamp.addingTimeInterval(Double(offset) * 0.5),
                isAIGenerated: result.source == .foundationModel
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
