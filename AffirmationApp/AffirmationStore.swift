import Foundation

// AffirmationStore is responsible for managing the app's list of affirmations,
// including both pre-loaded and user-submitted ones. It handles saving/loading from UserDefaults,
// updating affirmations, toggling favorites, and managing a "surprise" affirmation.
class AffirmationStore: ObservableObject {
    // Stored affirmations loaded from disk or defaults
    @Published var affirmations: [Affirmation] = [] {
        didSet {
            saveAffirmations()
        }
    }

    // Affirmations submitted by the user
    @Published var userSubmittedAffirmations: [Affirmation] = [] {
        didSet {
            saveUserSubmittedAffirmations()
        }
    }

    // A randomly chosen affirmation for the "Surprise Me" feature
    @Published var surpriseAffirmation: Affirmation?

    private let key = "affirmations_key"
    private let userKey = "user_submitted_affirmations_key"

    // Initialize and load stored affirmations
    init() {
        loadAffirmations()
        loadUserSubmittedAffirmations()
    }

    // Toggle the favorite status of a given affirmation
    func toggleFavorite(for affirmation: Affirmation) {
        if let index = affirmations.firstIndex(of: affirmation) {
            affirmations[index].isFavorite.toggle()
        }
    }

    // Save built-in affirmations to UserDefaults
    private func saveAffirmations() {
        if let data = try? JSONEncoder().encode(affirmations) {
            UserDefaults(suiteName: "group.bethsitruc.affirmationapp")?.set(data, forKey: key)
        }
    }

    // Load affirmations from UserDefaults or populate with default values
    private func loadAffirmations() {
        if let data = UserDefaults(suiteName: "group.bethsitruc.affirmationapp")?.data(forKey: key),
           let saved = try? JSONDecoder().decode([Affirmation].self, from: data) {
            self.affirmations = saved

            // Filter out any themes not in the approved list
            let allowedThemes = ["self-worth", "confidence", "resilience", "growth", "kindness", "optimism", "motivation"]
            self.affirmations = self.affirmations.map { affirmation in
                let filteredThemes = affirmation.themes.filter { allowedThemes.contains($0.lowercased()) }
                return Affirmation(id: affirmation.id, text: affirmation.text, isFavorite: affirmation.isFavorite, themes: filteredThemes)
            }
        } else {
            // Default affirmations if none are found in UserDefaults
            self.affirmations = [
                Affirmation(id: UUID(), text: "You are enough.", themes: ["self-worth"]),
                Affirmation(id: UUID(), text: "Believe you can and you're halfway there. – Theodore Roosevelt", themes: ["confidence", "motivation"]),
                Affirmation(id: UUID(), text: "You can handle anything that comes your way.", themes: ["resilience"]),
                Affirmation(id: UUID(), text: "You are growing and healing every day.", themes: ["growth"]),
                Affirmation(id: UUID(), text: "You deserve love and kindness.", themes: ["kindness", "self-worth"]),
                Affirmation(id: UUID(), text: "Keep your face always toward the sunshine—and shadows will fall behind you. – Walt Whitman", themes: ["optimism"]),
                Affirmation(id: UUID(), text: "You are capable, strong, and resilient.", themes: ["resilience", "confidence"]),
                Affirmation(id: UUID(), text: "Your presence makes the world a better place.", themes: ["kindness"]),
                Affirmation(id: UUID(), text: "Happiness is not something ready made. It comes from your own actions. – Dalai Lama", themes: ["optimism"]),
                Affirmation(id: UUID(), text: "Every step forward is a step toward your goals.", themes: ["motivation"]),
                Affirmation(id: UUID(), text: "You are worthy of everything good.", themes: ["self-worth"]),
                Affirmation(id: UUID(), text: "It always seems impossible until it’s done. – Nelson Mandela", themes: ["resilience", "motivation"]),
                Affirmation(id: UUID(), text: "You are doing better than you think.", themes: ["growth"]),
                Affirmation(id: UUID(), text: "You radiate confidence and positivity.", themes: ["confidence"]),
                Affirmation(id: UUID(), text: "Challenges are opportunities in disguise.", themes: ["resilience", "growth"]),
                Affirmation(id: UUID(), text: "You are aligned with your purpose.", themes: ["self-worth"]),
                Affirmation(id: UUID(), text: "You bring light to those around you.", themes: ["kindness"]),
                Affirmation(id: UUID(), text: "Mistakes help you grow and improve.", themes: ["growth"]),
                Affirmation(id: UUID(), text: "Today is full of potential and promise.", themes: ["optimism"]),
                Affirmation(id: UUID(), text: "Let your smile change the world.", themes: ["kindness"]),
                Affirmation(id: UUID(), text: "Your journey is uniquely beautiful.", themes: ["self-worth"]),
                Affirmation(id: UUID(), text: "Small steps lead to big changes.", themes: ["motivation", "growth"]),
                Affirmation(id: UUID(), text: "Start where you are. Use what you have. Do what you can. – Arthur Ashe", themes: ["motivation"]),
                Affirmation(id: UUID(), text: "Keep going. Everything you need will come to you. – Unknown", themes: ["motivation", "resilience"]),
                Affirmation(id: UUID(), text: "Difficult roads often lead to beautiful destinations. – Zig Ziglar", themes: ["resilience", "optimism"]),
                Affirmation(id: UUID(), text: "Stay close to anything that makes you glad to be alive. – Hafez", themes: ["optimism"]),
                Affirmation(id: UUID(), text: "You are stronger than you think. – Unknown", themes: ["resilience"]),
                Affirmation(id: UUID(), text: "Don’t wait. The time will never be just right. – Napoleon Hill", themes: ["motivation"]),
                Affirmation(id: UUID(), text: "You didn’t come this far to only come this far… now go get snacks.", themes: ["motivation"]),
                Affirmation(id: UUID(), text: "Progress, not perfection. And yes, naps count.", themes: ["growth", "optimism"]),
                Affirmation(id: UUID(), text: "You’re basically a superhero in comfy clothes.", themes: ["confidence"]),
                Affirmation(id: UUID(), text: "One step at a time… unless you’re dancing, then groove freely.", themes: ["optimism", "resilience"]),
                Affirmation(id: UUID(), text: "Mistakes mean you're learning. Or sleep-deprived. Either way, valid.", themes: ["resilience", "growth"]),
                Affirmation(id: UUID(), text: "Smile! It confuses people and burns calories. (Okay, maybe just the first part.)", themes: ["optimism"]),
            ]
        }
    }

    // Return all affirmations marked as favorite
    func favoriteAffirmations() -> [Affirmation] {
        (affirmations + userSubmittedAffirmations).filter { $0.isFavorite }
    }

    // Pick a random affirmation from both built-in and user-submitted lists
    func generateSurpriseAffirmation() {
        if !(affirmations + userSubmittedAffirmations).isEmpty {
            surpriseAffirmation = (affirmations + userSubmittedAffirmations).randomElement()
        }
    }

    // Save user-submitted affirmations to UserDefaults
    private func saveUserSubmittedAffirmations() {
        if let data = try? JSONEncoder().encode(userSubmittedAffirmations) {
            UserDefaults(suiteName: "group.bethsitruc.affirmationapp")?.set(data, forKey: userKey)
        }
    }

    // Load user-submitted affirmations from UserDefaults
    private func loadUserSubmittedAffirmations() {
        if let data = UserDefaults(suiteName: "group.bethsitruc.affirmationapp")?.data(forKey: userKey),
           let saved = try? JSONDecoder().decode([Affirmation].self, from: data) {
            self.userSubmittedAffirmations = saved
        }
    }

    // Add a new user-submitted affirmation
    func addUserAffirmation(text: String, themes: [String], isUserCreated: Bool) {
        let newAffirmation = Affirmation(id: UUID(), text: text, isFavorite: false, isUserCreated: isUserCreated, themes: themes)
        userSubmittedAffirmations.append(newAffirmation)
    }

    // Update an existing affirmation, or add it if it's not found (with notification)
    func update(_ affirmation: Affirmation) {
        if affirmation.isUserCreated {
            if let index = userSubmittedAffirmations.firstIndex(where: { $0.id == affirmation.id }) {
                userSubmittedAffirmations[index] = affirmation
            } else {
                // Notify observers if not found
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .affirmationNotFound, object: nil, userInfo: ["id": affirmation.id.uuidString])
                }
                userSubmittedAffirmations.append(affirmation)
            }
        } else {
            if let index = affirmations.firstIndex(where: { $0.id == affirmation.id }) {
                affirmations[index] = affirmation
            } else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .affirmationNotFound, object: nil, userInfo: ["id": affirmation.id.uuidString])
                }
                affirmations.append(affirmation)
            }
        }
    }

    // Delete a user-submitted affirmation by ID
    func deleteUserAffirmation(_ affirmation: Affirmation) {
        if let index = userSubmittedAffirmations.firstIndex(where: { $0.id == affirmation.id }) {
            userSubmittedAffirmations.remove(at: index)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .affirmationNotFound, object: nil, userInfo: ["id": affirmation.id.uuidString])
            }
        }
    }
}

// Custom notification for when an affirmation can't be found in the store
extension Notification.Name {
    static let affirmationNotFound = Notification.Name("affirmationNotFound")
}
