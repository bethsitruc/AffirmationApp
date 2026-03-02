import Testing
@testable import AffirmationApp

@Suite("Affirmation Store")
struct AffirmationStoreTests {

    @Test("Adding a user affirmation increases userSubmittedAffirmations count")
    func testAddUserAffirmation() async throws {
        let store = AffirmationStore()
        let originalCount = store.userSubmittedAffirmations.count

        store.addUserAffirmation(text: "You are amazing!", themes: ["motivation"], isUserCreated: true)

        #expect(store.userSubmittedAffirmations.count == originalCount + 1)
    }

    @Test("Toggling favorite adds an item to favorites list")
    func testFavoriteAffirmation() async throws {
        let store = AffirmationStore()
        guard let first = store.affirmations.first else {
            Issue.record("No affirmations available in default store")
            return
        }

        store.toggleFavorite(for: first)

        #expect(store.favoriteAffirmations().contains(where: { $0.id == first.id }))
    }

    @Test("Deleting a user affirmation removes it from the user list")
    func testDeleteUserAffirmation() async throws {
        let store = AffirmationStore()
        store.addUserAffirmation(text: "Temporary Affirmation", themes: ["test"], isUserCreated: true)
        guard let added = store.userSubmittedAffirmations.last else {
            Issue.record("Failed to add user affirmation")
            return
        }

        store.deleteUserAffirmation(added)

        #expect(!store.userSubmittedAffirmations.contains(where: { $0.id == added.id }))
    }
}
