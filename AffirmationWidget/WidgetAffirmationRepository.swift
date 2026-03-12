import AffirmationShared
import Foundation

/// Lightweight reader that exposes stored affirmations to the widget without depending on the app store.
struct WidgetAffirmationRepository {
    func allAffirmations() -> [Affirmation] {
        loadAffirmations(forKey: UserDefaults.Keys.affirmations, fallback: AffirmationSeeds.all)
    }

    func personalAffirmations() -> [Affirmation] {
        loadAffirmations(forKey: UserDefaults.Keys.userSubmittedAffirmations, fallback: [])
    }

    func favorites() -> [Affirmation] {
        (allAffirmations() + personalAffirmations()).filter { $0.isFavorite }
    }

    @available(iOSApplicationExtension 17.0, *)
    func source(_ source: AffirmationWidgetContentSource, fallbackToAll: Bool = true) -> [Affirmation] {
        switch source {
        case .favorites:
            let favs = favorites()
            return (favs.isEmpty && fallbackToAll) ? allAffirmations() : favs
        case .personal:
            let mine = personalAffirmations()
            return (mine.isEmpty && fallbackToAll) ? allAffirmations() : mine
        }
    }

    func affirmation(with id: UUID) -> Affirmation? {
        let combined = allAffirmations() + personalAffirmations()
        return combined.first(where: { $0.id == id })
    }

    private func loadAffirmations(forKey key: String, fallback: [Affirmation]) -> [Affirmation] {
        guard let data = SharedDefaults.data(forKey: key) else { return fallback }
        return (try? JSONDecoder().decode([Affirmation].self, from: data)) ?? fallback
    }
}
