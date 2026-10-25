import AffirmationShared
import Foundation
import Testing
@testable import AffirmationApp

extension GroundedTests {
    @MainActor
    @Suite("Durable library and merge regressions")
    struct StoreRegressions {
        @Test("Editing a favorite survives reload; deleting survives stale replay")
        func editFavoriteDeleteReload() throws {
            let defaults = TestDefaults(); defer { defaults.restore() }
            let store = AffirmationStore()
            store.addUserAffirmation(text: "Original", themes: ["calm"], isUserCreated: true)
            let original = try #require(store.userSubmittedAffirmations.first)
            store.toggleFavorite(for: original)
            var edit = try #require(store.userSubmittedAffirmations.first)
            edit.text = "Updated personal encouragement"
            edit.themes = ["growth"]
            store.update(edit)

            let reloaded = AffirmationStore()
            let persisted = try #require(reloaded.userSubmittedAffirmations.first)
            #expect(persisted.text == edit.text)
            #expect(persisted.themes == ["growth"])
            #expect(persisted.isFavorite)
            #expect(reloaded.favoriteAffirmations().first?.text == edit.text)
            reloaded.deleteUserAffirmation(persisted)
            let deleted = AffirmationStore()
            deleted.applyRemoteUserSync(affirmations: [original], tombstones: [])
            deleted.applyRemoteFavoriteSync(favorites: [persisted], tombstones: [])
            let final = AffirmationStore()
            #expect(final.userSubmittedAffirmations.isEmpty)
            #expect(final.favoriteAffirmations().isEmpty)
        }

        @Test("Merge chooses latest record, resolves ties in favor of records, and is idempotent",
              arguments: [(100.0, 200.0, true), (200.0, 100.0, false), (100.0, 100.0, true)])
        func mergePolicy(_ scenario: (Double, Double, Bool)) throws {
            let defaults = TestDefaults(); defer { defaults.restore() }
            let (deletedTime, editedTime, survives) = scenario
            let record = Affirmation(text: "Remote record", isFavorite: true, isUserCreated: true,
                                     createdAt: Date(timeIntervalSince1970: 50),
                                     updatedAt: Date(timeIntervalSince1970: editedTime))
            let tombstone = UserAffirmationTombstone(id: record.id, deletedAt: Date(timeIntervalSince1970: deletedTime))
            let favoriteTombstone = FavoriteAffirmationTombstone(favoriteStorageKey: record.favoriteStorageKey,
                                                               deletedAt: tombstone.deletedAt)
            let store = AffirmationStore()
            for _ in 0..<2 {
                store.applyRemoteUserSync(affirmations: [record, record], tombstones: [tombstone, tombstone])
                store.applyRemoteFavoriteSync(favorites: [record, record], tombstones: [favoriteTombstone, favoriteTombstone])
                #expect(store.userSubmittedAffirmations.count == (survives ? 1 : 0))
                #expect(store.favoriteAffirmations().count == (survives ? 1 : 0))
            }
            #expect(AffirmationStore().userSubmittedAffirmations.count == (survives ? 1 : 0))
        }

        @Test("Newer local edit is not overwritten by stale remote state")
        func newerLocalEditWins() throws {
            let defaults = TestDefaults(); defer { defaults.restore() }
            let store = AffirmationStore()
            let remote = Affirmation(text: "Old", isUserCreated: true, updatedAt: Date(timeIntervalSince1970: 100))
            store.applyRemoteUserSync(affirmations: [remote], tombstones: [])
            var edit = remote; edit.text = "New local text"
            store.update(edit)
            store.applyRemoteUserSync(affirmations: [remote], tombstones: [])
            #expect(store.userSubmittedAffirmations.first?.text == edit.text)
        }

        @Test("Invalid personal persistence recovers without crashing")
        func malformedPersistence() {
            let defaults = TestDefaults(); defer { defaults.restore() }
            SharedDefaults.set(Data("not json".utf8), forKey: UserDefaults.Keys.userSubmittedAffirmations)
            SharedDefaults.set(Data("{}".utf8), forKey: UserDefaults.Keys.favoriteAffirmations)
            let store = AffirmationStore()
            #expect(store.userSubmittedAffirmations.isEmpty)
            #expect(store.favoriteAffirmations().isEmpty)
            store.addUserAffirmation(text: "Recovered", themes: [], isUserCreated: true)
            #expect(AffirmationStore().userSubmittedAffirmations.first?.text == "Recovered")
        }
    }
}
