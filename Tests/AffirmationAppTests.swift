import AffirmationShared
import Foundation
import Testing
@testable import AffirmationApp

@MainActor
@Suite("Affirmation Store", .serialized)
struct AffirmationStoreTests {
    private let defaultsKeys = [
        UserDefaults.Keys.affirmations,
        UserDefaults.Keys.userSubmittedAffirmations,
        UserDefaults.Keys.deletedUserAffirmationTombstones,
        UserDefaults.Keys.favoriteAffirmations,
        UserDefaults.Keys.deletedFavoriteAffirmationTombstones,
    ]

    @Test("Adding a user affirmation stores metadata and persists it")
    func addUserAffirmationPersists() throws {
        let snapshot = SharedDefaultsSnapshot(keys: defaultsKeys)
        defer { snapshot.restore() }
        clearSharedDefaults()

        let store = AffirmationStore()
        store.addUserAffirmation(
            text: "You can trust your next step.",
            themes: ["calm"],
            isUserCreated: true,
            isAIGenerated: true
        )

        let added = try #require(store.userSubmittedAffirmations.last)
        #expect(added.text == "You can trust your next step.")
        #expect(added.isUserCreated)
        #expect(added.isAIGenerated)
        #expect(added.themes == ["calm"])
        #expect(added.createdAt != nil)
        #expect(added.updatedAt != nil)

        let persisted = try #require(decodeStoredUserAffirmations().last)
        #expect(persisted.id == added.id)
        #expect(persisted.text == added.text)
    }

    @Test("Toggling favorite updates the user affirmation and favorites list")
    func toggleFavoriteUpdatesFavorites() throws {
        let snapshot = SharedDefaultsSnapshot(keys: defaultsKeys)
        defer { snapshot.restore() }
        clearSharedDefaults()

        let store = AffirmationStore()
        store.addUserAffirmation(text: "You are steady.", themes: ["grounded"], isUserCreated: true)
        let added = try #require(store.userSubmittedAffirmations.last)

        store.toggleFavorite(for: added)

        let updated = try #require(store.userSubmittedAffirmations.last)
        #expect(updated.isFavorite)
        #expect(store.favoriteAffirmations().contains(where: { $0.id == updated.id }))

        let persistedFavorites = try #require(decodeStoredFavoriteAffirmations().first)
        #expect(persistedFavorites.id == updated.id)
        #expect(persistedFavorites.isFavorite)
    }

    @Test("Unfavoriting persists a favorite tombstone")
    func unfavoritePersistsFavoriteTombstone() throws {
        let snapshot = SharedDefaultsSnapshot(keys: defaultsKeys)
        defer { snapshot.restore() }
        clearSharedDefaults()

        let store = AffirmationStore()
        store.addUserAffirmation(text: "You can reset and continue.", themes: ["steady"], isUserCreated: true)
        let added = try #require(store.userSubmittedAffirmations.last)

        store.toggleFavorite(for: added)
        let favorited = try #require(store.userSubmittedAffirmations.last)
        store.toggleFavorite(for: favorited)

        #expect(store.favoriteAffirmations().isEmpty)
        let tombstone = try #require(decodeStoredDeletedFavoriteAffirmations().first)
        #expect(tombstone.favoriteStorageKey == favorited.favoriteStorageKey)
    }

    @Test("Legacy embedded favorites migrate into the dedicated favorites library")
    func legacyFavoritesMigrateIntoFavoriteLibrary() throws {
        let snapshot = SharedDefaultsSnapshot(keys: defaultsKeys)
        defer { snapshot.restore() }
        clearSharedDefaults()

        let legacy = [
            Affirmation(
                id: UUID(),
                text: "You are already becoming who you need to be.",
                isFavorite: true,
                isUserCreated: false,
                themes: ["growth"],
                createdAt: Date()
            )
        ]
        let data = try JSONEncoder().encode(legacy)
        SharedDefaults.set(data, forKey: UserDefaults.Keys.affirmations)

        let store = AffirmationStore()

        #expect(store.favoriteAffirmations().count == 1)
        #expect(store.favoriteAffirmations().first?.text == legacy.first?.text)
        #expect(decodeStoredFavoriteAffirmations().count == 1)
    }

    @Test("Updating a missing user affirmation posts a not-found notification and appends it")
    func updateMissingUserAffirmationNotifiesAndAppends() async throws {
        let snapshot = SharedDefaultsSnapshot(keys: defaultsKeys)
        defer { snapshot.restore() }
        clearSharedDefaults()

        let store = AffirmationStore()
        let missing = Affirmation(
            id: UUID(),
            text: "You are resilient.",
            isFavorite: false,
            isUserCreated: true,
            themes: ["strength"],
            createdAt: Date()
        )

        let notificationTask = Task {
            await nextAffirmationNotFoundNotification()
        }

        store.update(missing)

        let receivedNotificationID = await notificationTask.value
        let notificationID = try #require(receivedNotificationID)
        #expect(notificationID == missing.id.uuidString)
        #expect(store.userSubmittedAffirmations.contains(where: { $0.id == missing.id }))
    }

    @Test("Deleting a missing user affirmation posts a not-found notification")
    func deleteMissingUserAffirmationNotifies() async throws {
        let snapshot = SharedDefaultsSnapshot(keys: defaultsKeys)
        defer { snapshot.restore() }
        clearSharedDefaults()

        let store = AffirmationStore()
        let missing = Affirmation(
            id: UUID(),
            text: "This should not exist",
            isFavorite: false,
            isUserCreated: true,
            themes: ["test"],
            createdAt: Date()
        )

        let notificationTask = Task {
            await nextAffirmationNotFoundNotification()
        }

        store.deleteUserAffirmation(missing)

        let receivedNotificationID = await notificationTask.value
        let notificationID = try #require(receivedNotificationID)
        #expect(notificationID == missing.id.uuidString)
    }

    @Test("Deleting a user affirmation persists a tombstone")
    func deleteUserAffirmationPersistsTombstone() throws {
        let snapshot = SharedDefaultsSnapshot(keys: defaultsKeys)
        defer { snapshot.restore() }
        clearSharedDefaults()

        let store = AffirmationStore()
        store.addUserAffirmation(text: "You are grounded.", themes: ["steady"], isUserCreated: true)
        let added = try #require(store.userSubmittedAffirmations.last)

        store.deleteUserAffirmation(added)

        #expect(store.userSubmittedAffirmations.isEmpty)
        let tombstone = try #require(decodeStoredDeletedUserAffirmations().first)
        #expect(tombstone.id == added.id)
    }

    @Test("Persisted tombstones win when the app reloads")
    func persistedTombstonesPruneDeletedAffirmationsOnInit() throws {
        let snapshot = SharedDefaultsSnapshot(keys: defaultsKeys)
        defer { snapshot.restore() }
        clearSharedDefaults()

        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 120)
        let deletedAt = Date(timeIntervalSince1970: 150)

        let staleUserAffirmation = Affirmation(
            id: id,
            text: "This should stay deleted.",
            isFavorite: true,
            isUserCreated: true,
            themes: ["test"],
            createdAt: createdAt,
            updatedAt: updatedAt,
            isAIGenerated: false
        )
        let staleFavorite = staleUserAffirmation
        let tombstone = UserAffirmationTombstone(id: id, deletedAt: deletedAt)
        let favoriteTombstone = FavoriteAffirmationTombstone(
            favoriteStorageKey: staleFavorite.favoriteStorageKey,
            deletedAt: deletedAt
        )

        SharedDefaults.set(try JSONEncoder().encode([staleUserAffirmation]), forKey: UserDefaults.Keys.userSubmittedAffirmations)
        SharedDefaults.set(try JSONEncoder().encode([staleFavorite]), forKey: UserDefaults.Keys.favoriteAffirmations)
        SharedDefaults.set(try JSONEncoder().encode([tombstone]), forKey: UserDefaults.Keys.deletedUserAffirmationTombstones)
        SharedDefaults.set(try JSONEncoder().encode([favoriteTombstone]), forKey: UserDefaults.Keys.deletedFavoriteAffirmationTombstones)

        let store = AffirmationStore()

        #expect(store.userSubmittedAffirmations.isEmpty)
        #expect(store.favoriteAffirmations().isEmpty)
    }

    @Test("Remote sync prefers the newest user affirmation over older tombstones")
    func remoteSyncMergePrefersLatestRecord() throws {
        let snapshot = SharedDefaultsSnapshot(keys: defaultsKeys)
        defer { snapshot.restore() }
        clearSharedDefaults()

        let store = AffirmationStore()
        let id = UUID()
        let record = Affirmation(
            id: id,
            text: "You can begin again.",
            isFavorite: false,
            isUserCreated: true,
            themes: ["growth"],
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200),
            isAIGenerated: false
        )
        let tombstone = UserAffirmationTombstone(
            id: id,
            deletedAt: Date(timeIntervalSince1970: 150)
        )

        store.applyRemoteUserSync(affirmations: [record], tombstones: [tombstone])

        #expect(store.userSubmittedAffirmations.count == 1)
        #expect(store.userSubmittedAffirmations.first?.id == id)
    }

    @Test("Remote favorite sync prefers the newest favorite over an older tombstone")
    func remoteFavoriteSyncPrefersLatestRecord() throws {
        let snapshot = SharedDefaultsSnapshot(keys: defaultsKeys)
        defer { snapshot.restore() }
        clearSharedDefaults()

        let store = AffirmationStore()
        let favorite = Affirmation(
            id: UUID(),
            text: "You are allowed to begin again.",
            isFavorite: true,
            isUserCreated: false,
            themes: ["growth"],
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 250),
            isAIGenerated: false
        )
        let tombstone = FavoriteAffirmationTombstone(
            favoriteStorageKey: favorite.favoriteStorageKey,
            deletedAt: Date(timeIntervalSince1970: 150)
        )

        store.applyRemoteFavoriteSync(favorites: [favorite], tombstones: [tombstone])

        #expect(store.favoriteAffirmations().count == 1)
        #expect(store.favoriteAffirmations().first?.favoriteStorageKey == favorite.favoriteStorageKey)
    }

    @Test("Remote favorite sync removes stale favorites when tombstone is newer")
    func remoteFavoriteSyncPrefersNewerTombstone() throws {
        let snapshot = SharedDefaultsSnapshot(keys: defaultsKeys)
        defer { snapshot.restore() }
        clearSharedDefaults()

        let store = AffirmationStore()
        let favorite = Affirmation(
            id: UUID(),
            text: "You can exhale and continue.",
            isFavorite: true,
            isUserCreated: false,
            themes: ["calm"],
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 120),
            isAIGenerated: false
        )
        let tombstone = FavoriteAffirmationTombstone(
            favoriteStorageKey: favorite.favoriteStorageKey,
            deletedAt: Date(timeIntervalSince1970: 300)
        )

        store.applyRemoteFavoriteSync(favorites: [favorite], tombstones: [tombstone])

        #expect(store.favoriteAffirmations().isEmpty)
        let persistedTombstone = try #require(decodeStoredDeletedFavoriteAffirmations().first)
        #expect(persistedTombstone.favoriteStorageKey == favorite.favoriteStorageKey)
    }

    private func clearSharedDefaults() {
        defaultsKeys.forEach {
            SharedDefaults.removeObject(forKey: $0)
            CloudPreferenceStore.removeObject(forKey: $0)
        }
    }

    private func decodeStoredUserAffirmations() -> [Affirmation] {
        guard let data = SharedDefaults.data(forKey: UserDefaults.Keys.userSubmittedAffirmations) else {
            return []
        }
        return (try? JSONDecoder().decode([Affirmation].self, from: data)) ?? []
    }

    private func decodeStoredFavoriteAffirmations() -> [Affirmation] {
        guard let data = SharedDefaults.data(forKey: UserDefaults.Keys.favoriteAffirmations) else {
            return []
        }
        return (try? JSONDecoder().decode([Affirmation].self, from: data)) ?? []
    }

    private func decodeStoredDeletedUserAffirmations() -> [UserAffirmationTombstone] {
        guard let data = SharedDefaults.data(forKey: UserDefaults.Keys.deletedUserAffirmationTombstones) else {
            return []
        }
        return (try? JSONDecoder().decode([UserAffirmationTombstone].self, from: data)) ?? []
    }

    private func decodeStoredDeletedFavoriteAffirmations() -> [FavoriteAffirmationTombstone] {
        guard let data = SharedDefaults.data(forKey: UserDefaults.Keys.deletedFavoriteAffirmationTombstones) else {
            return []
        }
        return (try? JSONDecoder().decode([FavoriteAffirmationTombstone].self, from: data)) ?? []
    }

    private func nextAffirmationNotFoundNotification() async -> String? {
        let notifications = NotificationCenter.default.notifications(named: .affirmationNotFound)
        return await withTimeout(seconds: 1) {
            for await notification in notifications {
                return notification.userInfo?["id"] as? String
            }
            return nil
        }
    }
}

@Suite("Affirmation Generator")
struct AffirmationGeneratorPromptTests {
    @Test("Prompt adds tailored nostalgic guidance")
    func nostalgicPromptIncludesConcreteGuidance() {
        let prompt = FoundationModelClient.prompt(
            for: "nostalgic",
            tone: .calm
        )

        #expect(prompt.contains("younger version of yourself"))
        #expect(prompt.contains("childhood rooms"))
        #expect(prompt.contains("healing through remembered softness"))
    }

    @Test("Prompt avoids generic wording for untailored themes")
    func genericPromptStillAsksForSpecificity() {
        let prompt = FoundationModelClient.prompt(
            for: "fresh starts",
            tone: .confident
        )

        #expect(prompt.contains("fresh starts"))
        #expect(prompt.contains("concrete emotional lens or lived image"))
    }

    @Test("Playful tone explicitly asks for wit and surprise")
    func playfulToneGuidanceIsDistinct() {
        let prompt = FoundationModelClient.prompt(for: "tired", tone: .playful)
        #expect(AffirmationGenerator.Tone.playful.instructionsQualifier.contains("witty"))
        #expect(AffirmationGenerator.Tone.playful.styleGuidance.contains("gentle wordplay"))
        #expect(AffirmationGenerator.Tone.playful.promptQualifier.contains("lightly clever"))
        #expect(prompt.contains("mischievous metaphor"))
        #expect(prompt.contains("Avoid plain therapy language"))
        #expect(prompt.contains("low-battery humor"))
        #expect(prompt.contains("rest and recharge"))
        #expect(prompt.contains("not playful enough"))
    }

    @Test("Confident tone is grounded instead of hype-driven")
    func confidentToneAvoidsPepRallyLanguage() {
        #expect(AffirmationGenerator.Tone.confident.styleGuidance.contains("not performative"))
        #expect(AffirmationGenerator.Tone.confident.promptQualifier.contains("deep self-trust"))
        #expect(!AffirmationGenerator.Tone.confident.promptQualifier.contains("pre-game rally"))
    }

    @Test("Grateful tone emphasizes noticing over generic thanks")
    func gratefulToneGuidanceIsConcrete() {
        #expect(AffirmationGenerator.Tone.grateful.styleGuidance.contains("ordinary gifts"))
        #expect(AffirmationGenerator.Tone.grateful.promptQualifier.contains("savoring ordinary gifts"))
    }
}

private struct SharedDefaultsSnapshot {
    let entries: [String: Any]
    let missingKeys: Set<String>

    init(keys: [String]) {
        var stored: [String: Any] = [:]
        var missing = Set<String>()

        for key in keys {
            if let value = SharedDefaults.object(forKey: key) {
                stored[key] = value
            } else {
                missing.insert(key)
            }
        }

        self.entries = stored
        self.missingKeys = missing
    }

    func restore() {
        for key in missingKeys {
            SharedDefaults.removeObject(forKey: key)
            CloudPreferenceStore.removeObject(forKey: key)
        }
        for (key, value) in entries {
            SharedDefaults.set(value, forKey: key)
            switch value {
            case let string as String:
                CloudPreferenceStore.set(string, forKey: key)
            case let number as NSNumber:
                CloudPreferenceStore.set(number.doubleValue, forKey: key)
            default:
                break
            }
        }
    }
}

private func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async -> T?
) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask {
            await operation()
        }
        group.addTask {
            let duration = UInt64(seconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: duration)
            return nil
        }

        let result = await group.next() ?? nil
        group.cancelAll()
        return result
    }
}
