import Foundation
import AffirmationShared
#if !os(macOS)
import WidgetKit
#endif

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

    private let key = UserDefaults.Keys.affirmations
    private let userKey = UserDefaults.Keys.userSubmittedAffirmations
    // Initialize and load stored affirmations
    init() {
        loadAffirmations()
        loadUserSubmittedAffirmations()
    }

    /// Toggles the favorite flag for the given affirmation in either built-in or user-submitted collections.
    func toggleFavorite(for affirmation: Affirmation) {
        if let index = affirmations.firstIndex(of: affirmation) {
            affirmations[index].isFavorite.toggle()
        } else if let uIndex = userSubmittedAffirmations.firstIndex(where: { $0.id == affirmation.id }) {
            userSubmittedAffirmations[uIndex].isFavorite.toggle()
        }
    }

    /// Persists built-in affirmations to the shared defaults and refreshes widgets.
    private func saveAffirmations() {
        if let data = try? JSONEncoder().encode(affirmations) {
            _ = SharedDefaults.set(data, forKey: key)
#if !os(macOS)
            WidgetCenter.shared.reloadAllTimelines()
#endif
        }
    }

    /// Loads built-in affirmations from shared defaults or falls back to defaults; filters themes to the canonical set.
    private func loadAffirmations() {
        if let data = SharedDefaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([Affirmation].self, from: data) {
            self.affirmations = saved.map { affirmation in
                guard affirmation.createdAt == nil else { return affirmation }
                var updated = affirmation
                updated.createdAt = .distantPast
                return updated
            }
        } else {
            // Default affirmations if none are found in UserDefaults
            let now = Date()
            self.affirmations = AffirmationSeeds.all.enumerated().map { offset, affirmation in
                var entry = affirmation
                entry.createdAt = now.addingTimeInterval(TimeInterval(-offset * 60))
                return entry
            }
        }
    }

    /// Returns a combined list of all affirmations currently marked as favorite.
    func favoriteAffirmations() -> [Affirmation] {
        (affirmations + userSubmittedAffirmations).filter { $0.isFavorite }
    }

    /// Picks a random affirmation from both lists and stores it in 'surpriseAffirmation'.
    func generateSurpriseAffirmation() {
        if !(affirmations + userSubmittedAffirmations).isEmpty {
            surpriseAffirmation = (affirmations + userSubmittedAffirmations).randomElement()
        }
    }

    /// Persists user-submitted affirmations to the shared defaults and refreshes widgets.
    private func saveUserSubmittedAffirmations() {
        if let data = try? JSONEncoder().encode(userSubmittedAffirmations) {
            _ = SharedDefaults.set(data, forKey: userKey)
#if !os(macOS)
            WidgetCenter.shared.reloadAllTimelines()
#endif
        }
    }

    /// Loads user-submitted affirmations from shared defaults.
    private func loadUserSubmittedAffirmations() {
        if let data = SharedDefaults.data(forKey: userKey),
           let saved = try? JSONDecoder().decode([Affirmation].self, from: data) {
            self.userSubmittedAffirmations = saved
        }
    }

    /// Appends a new user-created affirmation to the user-submitted list.
    func addUserAffirmation(text: String, themes: [String], isUserCreated: Bool, isAIGenerated: Bool = false) {
        let newAffirmation = Affirmation(
            id: UUID(),
            text: text,
            isFavorite: false,
            isUserCreated: isUserCreated,
            themes: themes,
            createdAt: Date(),
            isAIGenerated: isAIGenerated
        )
        userSubmittedAffirmations.append(newAffirmation)
    }

    /// Updates an existing affirmation by id; if not found, posts an 'affirmationNotFound' notification and appends.
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

    /// Deletes a user-submitted affirmation by id; posts an 'affirmationNotFound' notification if missing.
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
