import Foundation
import Testing
@testable import AffirmationShared

@Suite("Portable model contracts")
struct AffirmationModelTests {
    @Test("Legacy payload defaults metadata without losing identity or text")
    func legacyDecoding() throws {
        let id = UUID()
        let data = Data("{\"id\":\"\(id)\",\"text\":\"Keep growing\"}".utf8)
        let item = try JSONDecoder().decode(Affirmation.self, from: data)
        #expect(item.id == id)
        #expect(item.text == "Keep growing")
        #expect(!item.isFavorite && !item.isUserCreated && !item.isAIGenerated)
        #expect(item.themes.isEmpty && item.updatedAt == nil)
        #expect(try JSONDecoder().decode(Affirmation.self, from: JSONEncoder().encode(item)) == item)
    }
    @Test("Built-in favorite keys normalize text; personal keys use identity")
    func favoriteIdentity() {
        let first = Affirmation(text: "  TRUST   your\nprogress. ")
        let second = Affirmation(text: "trust your progress.")
        #expect(first.favoriteStorageKey == second.favoriteStorageKey)
        #expect(first.favoriteSyncID == second.favoriteSyncID)
        #expect(first.favoriteSyncID.count == 64)
        let personal = Affirmation(id: first.id, text: first.text, isUserCreated: true)
        var edited = personal; edited.text = "Different text"
        #expect(personal.favoriteStorageKey == edited.favoriteStorageKey)
        #expect(personal.favoriteStorageKey != first.favoriteStorageKey)
    }
}
