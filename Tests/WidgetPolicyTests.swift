import AffirmationShared
import Foundation
import Testing
@testable import AffirmationApp

extension GroundedTests {
    @Suite("Widget selection and appearance")
    struct WidgetPolicyTests {
        @Test("Empty and corrupt sources prompt for configuration; fallback is explicit")
        func emptySources() {
            let state = TestDefaults(); defer { state.restore() }
            SharedDefaults.set(Data("invalid".utf8), forKey: UserDefaults.Keys.favoriteAffirmations)
            let repo = WidgetAffirmationRepository()
            #expect(repo.favorites().isEmpty)
            #expect(!repo.allAffirmations().isEmpty)
            #expect(repo.entries(for: .favorites, fallbackToAll: false).isEmpty)
            #expect(!repo.entries(for: .favorites).isEmpty)
            #expect(repo.text(mode: .specific, source: .favorites) == "Pick a favorite or personal affirmation")
            #expect(repo.text(mode: .shuffle, source: .personal) == "Favorite or add affirmations")
        }

        @Test("Pinned and shuffle widgets resolve the intended source and recover deleted selections")
        func sourceAndSelection() throws {
            let state = TestDefaults(); defer { state.restore() }
            let personal = Affirmation(text: "Personal", isUserCreated: true)
            let favorite = Affirmation(text: "Favorite", isFavorite: true)
            SharedDefaults.set(try JSONEncoder().encode([personal]), forKey: UserDefaults.Keys.userSubmittedAffirmations)
            SharedDefaults.set(try JSONEncoder().encode([favorite]), forKey: UserDefaults.Keys.favoriteAffirmations)
            let repo = WidgetAffirmationRepository()
            #expect(repo.text(mode: .specific, source: .personal, selectedID: personal.id) == "Personal")
            #expect(repo.text(mode: .shuffle, source: .favorites, choose: { $0.first }) == "Favorite")
            #expect(repo.text(mode: .specific, source: .favorites, selectedID: UUID()) == "Favorite")
            SharedDefaults.removeObject(forKey: UserDefaults.Keys.userSubmittedAffirmations)
            #expect(repo.text(mode: .specific, source: .personal, selectedID: personal.id) == "Pick a favorite or personal affirmation")
        }

        @Test("Widget refresh policy honors specific and shuffle intervals", arguments: [900.0, 1800.0, 3600.0])
        func refreshDates(interval: Double) {
            let now = Date(timeIntervalSince1970: 100)
            #expect(WidgetAffirmationRepository.refreshDate(mode: .shuffle, interval: interval, now: now) == now.addingTimeInterval(interval))
            #expect(WidgetAffirmationRepository.refreshDate(mode: .specific, interval: interval, now: now) == now.addingTimeInterval(21_600))
        }

        @MainActor
        @Test("Appearance choices persist and external preference changes can be reloaded")
        func appearanceRoundTrip() {
            let state = TestDefaults(); defer { state.restore() }
            let settings = AppearanceSettings()
            settings.updateTheme(.dusk); settings.updateFont(.rounded)
            let reloaded = AppearanceSettings()
            #expect(reloaded.theme == .dusk)
            #expect(reloaded.font == .rounded)
            AppearancePreferences.theme = .glow; AppearancePreferences.font = .modern
            reloaded.syncFromDefaults()
            #expect(reloaded.theme == .glow)
            #expect(reloaded.font == .modern)
        }
    }
}
