import Foundation

public enum WidgetContentSource: Sendable { case favorites, personal }
public enum WidgetSelectionMode: Sendable { case specific, shuffle }

/// Shared widget policy, independent of WidgetKit presentation and AppIntent types.
// UserDefaults supports concurrent access; this value holds an immutable reference.
public struct WidgetAffirmationRepository: @unchecked Sendable {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = SharedDefaults) { self.defaults = defaults }

    public func allAffirmations() -> [Affirmation] { load(UserDefaults.Keys.affirmations, fallback: AffirmationSeeds.all) }
    public func personalAffirmations() -> [Affirmation] { load(UserDefaults.Keys.userSubmittedAffirmations, fallback: []) }
    public func favorites() -> [Affirmation] { load(UserDefaults.Keys.favoriteAffirmations, fallback: []) }
    public func entries(for source: WidgetContentSource, fallbackToAll: Bool = true) -> [Affirmation] {
        let entries = source == .favorites ? favorites() : personalAffirmations()
        return entries.isEmpty && fallbackToAll ? allAffirmations() : entries
    }
    public func affirmation(with id: UUID) -> Affirmation? {
        (allAffirmations() + personalAffirmations()).first { $0.id == id }
    }
    public func text(mode: WidgetSelectionMode, source: WidgetContentSource, selectedID: UUID? = nil,
                     choose: ([Affirmation]) -> Affirmation? = { $0.randomElement() }) -> String {
        let entries = self.entries(for: source, fallbackToAll: false)
        switch mode {
        case .specific:
            if let id = selectedID, let selected = affirmation(with: id) { return selected.text }
            return entries.first?.text ?? "Pick a favorite or personal affirmation"
        case .shuffle:
            return choose(entries)?.text ?? "Favorite or add affirmations"
        }
    }
    public static func refreshDate(mode: WidgetSelectionMode, interval: TimeInterval? = nil, now: Date) -> Date {
        now.addingTimeInterval(mode == .specific ? 6 * 3600 : (interval ?? 3600))
    }
    private func load(_ key: String, fallback: [Affirmation]) -> [Affirmation] {
        guard let data = defaults.data(forKey: key) else { return fallback }
        return (try? JSONDecoder().decode([Affirmation].self, from: data)) ?? fallback
    }
}
