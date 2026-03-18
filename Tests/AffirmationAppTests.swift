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

        let receivedNotification = try await notificationTask.value
        let notification = try #require(receivedNotification)
        #expect(notification.userInfo?["id"] as? String == missing.id.uuidString)
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

        let receivedNotification = try await notificationTask.value
        let notification = try #require(receivedNotification)
        #expect(notification.userInfo?["id"] as? String == missing.id.uuidString)
    }

    private func clearSharedDefaults() {
        defaultsKeys.forEach { SharedDefaults.removeObject(forKey: $0) }
    }

    private func decodeStoredUserAffirmations() -> [Affirmation] {
        guard let data = SharedDefaults.data(forKey: UserDefaults.Keys.userSubmittedAffirmations) else {
            return []
        }
        return (try? JSONDecoder().decode([Affirmation].self, from: data)) ?? []
    }

    private func nextAffirmationNotFoundNotification() async -> Notification? {
        let notifications = NotificationCenter.default.notifications(named: .affirmationNotFound)
        return await withTimeout(seconds: 1) {
            for await notification in notifications {
                return notification
            }
            return nil
        }
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
        }
        for (key, value) in entries {
            SharedDefaults.set(value, forKey: key)
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
