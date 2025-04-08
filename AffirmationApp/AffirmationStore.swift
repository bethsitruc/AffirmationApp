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
                Affirmation(id: UUID(), text: "You are enough."),
                Affirmation(id: UUID(), text: "Believe you can and you're halfway there. – Theodore Roosevelt"),
                Affirmation(id: UUID(), text: "You can handle anything that comes your way."),
                Affirmation(id: UUID(), text: "You are growing and healing every day."),
                Affirmation(id: UUID(), text: "You deserve love and kindness."),
                Affirmation(id: UUID(), text: "Keep your face always toward the sunshine—and shadows will fall behind you. – Walt Whitman"),
                Affirmation(id: UUID(), text: "You are capable, strong, and resilient."),
                Affirmation(id: UUID(), text: "Your presence makes the world a better place."),
                Affirmation(id: UUID(), text: "Happiness is not something ready made. It comes from your own actions. – Dalai Lama"),
                Affirmation(id: UUID(), text: "Every step forward is a step toward your goals."),
                Affirmation(id: UUID(), text: "You are worthy of everything good."),
                Affirmation(id: UUID(), text: "It always seems impossible until it’s done. – Nelson Mandela")
            ]
        }
    }

    func favoriteAffirmations() -> [Affirmation] {
        affirmations.filter { $0.isFavorite }
    }
}
