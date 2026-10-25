import AffirmationShared

extension WidgetAffirmationRepository {
    func source(_ source: AffirmationWidgetContentSource, fallbackToAll: Bool = true) -> [Affirmation] {
        self.entries(for: source == .favorites ? WidgetContentSource.favorites : .personal, fallbackToAll: fallbackToAll)
    }
}
