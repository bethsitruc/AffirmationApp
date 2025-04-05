import Foundation

class AffirmationStore: ObservableObject {
    @Published var affirmations: [Affirmation] = [] {
        didSet {
            saveAffirmations()
        }
    }

    private let key = "affirmations_key"

    init() {
        loadAffirmations()
    }

    func toggleFavorite(for affirmation: Affirmation) {
        if let index = affirmations.firstIndex(of: affirmation) {
            affirmations[index].isFavorite.toggle()
        }
    }

    private func saveAffirmations() {
        if let data = try? JSONEncoder().encode(affirmations) {
            UserDefaults(suiteName: "group.bethsitruc.affirmationapp")?.set(data, forKey: key)
        }
    }

    private func loadAffirmations() {
        if let data = UserDefaults(suiteName: "group.bethsitruc.affirmationapp")?.data(forKey: key),
           let saved = try? JSONDecoder().decode([Affirmation].self, from: data) {
            self.affirmations = saved
        } else {
            self.affirmations = [
                Affirmation(id: UUID(),text: "You are enough."),
                Affirmation(id: UUID(),text: "You can handle anything that comes your way."),
                Affirmation(id: UUID(),text: "You are growing and healing every day."),
                Affirmation(id: UUID(),text: "You deserve love and kindness."),
            ]
        }
    }

    func favoriteAffirmations() -> [Affirmation] {
        affirmations.filter { $0.isFavorite }
    }
}
