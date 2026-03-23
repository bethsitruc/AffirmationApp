import Foundation
import AffirmationShared
#if !os(macOS)
import WidgetKit
#endif

// AffirmationStore is responsible for managing the app's list of affirmations,
// including both pre-loaded and user-submitted ones. It handles saving/loading from UserDefaults,
// updating affirmations, toggling favorites, and managing a "surprise" affirmation.
@MainActor
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
            notifyUserAffirmationSyncChanged()
        }
    }

    @Published private var deletedUserAffirmationTombstones: [UserAffirmationTombstone] = [] {
        didSet {
            saveDeletedUserAffirmationTombstones()
            notifyUserAffirmationSyncChanged()
        }
    }

    @Published private var deletedFavoriteAffirmationTombstones: [FavoriteAffirmationTombstone] = [] {
        didSet {
            saveDeletedFavoriteAffirmationTombstones()
            notifyFavoriteSyncChanged()
        }
    }

    // Durable favorites library used for local persistence now and cross-device sync later.
    @Published private var favoriteLibrary: [Affirmation] = [] {
        didSet {
            saveFavoriteAffirmations()
            notifyFavoriteSyncChanged()
        }
    }

    // A randomly chosen affirmation for the "Surprise Me" feature
    @Published var surpriseAffirmation: Affirmation?

    private let key = UserDefaults.Keys.affirmations
    private let userKey = UserDefaults.Keys.userSubmittedAffirmations
    private let deletedUserKey = UserDefaults.Keys.deletedUserAffirmationTombstones
    private let favoriteKey = UserDefaults.Keys.favoriteAffirmations
    private let deletedFavoriteKey = UserDefaults.Keys.deletedFavoriteAffirmationTombstones
    private let syncCoordinator: any UserAffirmationSyncing
    private let favoriteSyncCoordinator: any FavoriteLibrarySyncing
    private var isApplyingRemoteUserSync = false
    private var isApplyingRemoteFavoriteSync = false

    // Initialize and load stored affirmations
    init(
        syncCoordinator: any UserAffirmationSyncing,
        favoriteSyncCoordinator: any FavoriteLibrarySyncing
    ) {
        self.syncCoordinator = syncCoordinator
        self.favoriteSyncCoordinator = favoriteSyncCoordinator
        loadAffirmations()
        loadUserSubmittedAffirmations()
        loadDeletedUserAffirmationTombstones()
        loadFavoriteAffirmations()
        loadDeletedFavoriteAffirmationTombstones()
        migrateLegacyFavoritesIfNeeded()
        applyFavoriteFlagsToCollections()
        syncCoordinator.attach(store: self)
        favoriteSyncCoordinator.attach(store: self)
    }

    convenience init() {
        self.init(
            syncCoordinator: NoOpUserAffirmationSyncCoordinator(),
            favoriteSyncCoordinator: NoOpFavoriteLibrarySyncCoordinator()
        )
    }

    func startUserAffirmationSync() {
        syncCoordinator.start()
        favoriteSyncCoordinator.start()
    }

    func refreshUserAffirmationSync() {
        syncCoordinator.scheduleSync()
        favoriteSyncCoordinator.scheduleSync()
    }

    /// Toggles the favorite flag for the given affirmation in either built-in or user-submitted collections.
    func toggleFavorite(for affirmation: Affirmation) {
        if let existingIndex = favoriteLibrary.firstIndex(where: { $0.favoriteStorageKey == affirmation.favoriteStorageKey }) {
            let removed = favoriteLibrary.remove(at: existingIndex)
            deletedFavoriteAffirmationTombstones.removeAll { $0.favoriteStorageKey == removed.favoriteStorageKey }
            deletedFavoriteAffirmationTombstones.append(
                FavoriteAffirmationTombstone(
                    favoriteStorageKey: removed.favoriteStorageKey,
                    deletedAt: Date()
                )
            )
        } else {
            var snapshot = affirmation
            snapshot.isFavorite = true
            snapshot.updatedAt = Date()
            deletedFavoriteAffirmationTombstones.removeAll { $0.favoriteStorageKey == snapshot.favoriteStorageKey }
            favoriteLibrary.insert(snapshot, at: 0)
        }
        applyFavoriteFlagsToCollections()
    }

    /// Persists built-in affirmations to the shared defaults and refreshes widgets.
    private func saveAffirmations() {
        let persisted = affirmations.map { flaggedCopy(for: $0) }
        if let data = try? JSONEncoder().encode(persisted) {
            SharedDefaults.set(data, forKey: key)
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
        favoriteLibrary
    }

    /// Picks a random affirmation from both lists and stores it in 'surpriseAffirmation'.
    func generateSurpriseAffirmation() {
        if !(affirmations + userSubmittedAffirmations).isEmpty {
            surpriseAffirmation = (affirmations + userSubmittedAffirmations).randomElement()
        }
    }

    /// Persists user-submitted affirmations to the shared defaults and refreshes widgets.
    private func saveUserSubmittedAffirmations() {
        let persisted = userSubmittedAffirmations.map { flaggedCopy(for: $0) }
        if let data = try? JSONEncoder().encode(persisted) {
            SharedDefaults.set(data, forKey: userKey)
#if !os(macOS)
            WidgetCenter.shared.reloadAllTimelines()
#endif
        }
    }

    /// Persists the durable favorites library and refreshes widgets.
    private func saveFavoriteAffirmations() {
        let persisted = favoriteLibrary.map { flaggedCopy(for: $0, forceFavorite: true) }
        if let data = try? JSONEncoder().encode(persisted) {
            SharedDefaults.set(data, forKey: favoriteKey)
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

    private func saveDeletedUserAffirmationTombstones() {
        if let data = try? JSONEncoder().encode(deletedUserAffirmationTombstones) {
            SharedDefaults.set(data, forKey: deletedUserKey)
        }
    }

    private func loadDeletedUserAffirmationTombstones() {
        if let data = SharedDefaults.data(forKey: deletedUserKey),
           let saved = try? JSONDecoder().decode([UserAffirmationTombstone].self, from: data) {
            self.deletedUserAffirmationTombstones = saved
        }
    }

    private func saveDeletedFavoriteAffirmationTombstones() {
        if let data = try? JSONEncoder().encode(deletedFavoriteAffirmationTombstones) {
            SharedDefaults.set(data, forKey: deletedFavoriteKey)
        }
    }

    private func loadDeletedFavoriteAffirmationTombstones() {
        if let data = SharedDefaults.data(forKey: deletedFavoriteKey),
           let saved = try? JSONDecoder().decode([FavoriteAffirmationTombstone].self, from: data) {
            self.deletedFavoriteAffirmationTombstones = saved
        }
    }

    /// Loads synced/durable favorites from shared defaults.
    private func loadFavoriteAffirmations() {
        if let data = SharedDefaults.data(forKey: favoriteKey),
           let saved = try? JSONDecoder().decode([Affirmation].self, from: data) {
            self.favoriteLibrary = saved.map { flaggedCopy(for: $0, forceFavorite: true) }
        }
    }

    /// Appends a new user-created affirmation to the user-submitted list.
    func addUserAffirmation(text: String, themes: [String], isUserCreated: Bool, isAIGenerated: Bool = false) {
        let now = Date()
        let newAffirmation = Affirmation(
            id: UUID(),
            text: text,
            isFavorite: false,
            isUserCreated: isUserCreated,
            themes: themes,
            createdAt: now,
            updatedAt: now,
            isAIGenerated: isAIGenerated
        )
        deletedUserAffirmationTombstones.removeAll { $0.id == newAffirmation.id }
        userSubmittedAffirmations.append(newAffirmation)
    }

    /// Updates an existing affirmation by id; if not found, posts an 'affirmationNotFound' notification and appends.
    func update(_ affirmation: Affirmation) {
        var updatedAffirmation = affirmation
        if updatedAffirmation.isUserCreated {
            updatedAffirmation.updatedAt = Date()
        }

        if affirmation.isUserCreated {
            if let index = userSubmittedAffirmations.firstIndex(where: { $0.id == updatedAffirmation.id }) {
                userSubmittedAffirmations[index] = flaggedCopy(for: updatedAffirmation)
            } else {
                // Notify observers if not found
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .affirmationNotFound, object: nil, userInfo: ["id": updatedAffirmation.id.uuidString])
                }
                userSubmittedAffirmations.append(flaggedCopy(for: updatedAffirmation))
            }
            deletedUserAffirmationTombstones.removeAll { $0.id == updatedAffirmation.id }
        } else {
            if let index = affirmations.firstIndex(where: { $0.id == updatedAffirmation.id }) {
                affirmations[index] = flaggedCopy(for: updatedAffirmation)
            } else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .affirmationNotFound, object: nil, userInfo: ["id": updatedAffirmation.id.uuidString])
                }
                affirmations.append(flaggedCopy(for: updatedAffirmation))
            }
        }

        if let favoriteIndex = favoriteLibrary.firstIndex(where: { $0.favoriteStorageKey == updatedAffirmation.favoriteStorageKey }) {
            var snapshot = updatedAffirmation
            snapshot.isFavorite = true
            favoriteLibrary[favoriteIndex] = snapshot
        }
        applyFavoriteFlagsToCollections()
    }

    /// Deletes a user-submitted affirmation by id; posts an 'affirmationNotFound' notification if missing.
    func deleteUserAffirmation(_ affirmation: Affirmation) {
        if let index = userSubmittedAffirmations.firstIndex(where: { $0.id == affirmation.id }) {
            let deleted = userSubmittedAffirmations.remove(at: index)
            let deletedAt = max(Date(), deleted.syncTimestamp.addingTimeInterval(1))
            deletedUserAffirmationTombstones.removeAll { $0.id == deleted.id }
            deletedUserAffirmationTombstones.append(
                UserAffirmationTombstone(id: deleted.id, deletedAt: deletedAt)
            )
            removeFavoriteSnapshot(for: affirmation.favoriteStorageKey, deletedAt: deletedAt)
            applyFavoriteFlagsToCollections()
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .affirmationNotFound, object: nil, userInfo: ["id": affirmation.id.uuidString])
            }
        }
    }

    private func migrateLegacyFavoritesIfNeeded() {
        guard favoriteLibrary.isEmpty else { return }

        let legacyFavorites = (affirmations + userSubmittedAffirmations)
            .filter(\.isFavorite)
        guard !legacyFavorites.isEmpty else { return }

        var seen = Set<String>()
        favoriteLibrary = legacyFavorites.compactMap { affirmation in
            guard seen.insert(affirmation.favoriteStorageKey).inserted else { return nil }
            return flaggedCopy(for: affirmation, forceFavorite: true)
        }
    }

    private func applyFavoriteFlagsToCollections() {
        let favoriteKeys = Set(favoriteLibrary.map(\.favoriteStorageKey))

        let updatedAffirmations = affirmations.map { affirmation -> Affirmation in
            var copy = affirmation
            copy.isFavorite = favoriteKeys.contains(copy.favoriteStorageKey)
            return copy
        }

        if updatedAffirmations != affirmations {
            affirmations = updatedAffirmations
        }

        let updatedUserAffirmations = userSubmittedAffirmations.map { affirmation -> Affirmation in
            var copy = affirmation
            copy.isFavorite = favoriteKeys.contains(copy.favoriteStorageKey)
            return copy
        }

        if updatedUserAffirmations != userSubmittedAffirmations {
            userSubmittedAffirmations = updatedUserAffirmations
        }

        let byKey = Dictionary(uniqueKeysWithValues: (affirmations + userSubmittedAffirmations).map { ($0.favoriteStorageKey, $0) })
        let refreshedFavorites = favoriteLibrary.map { favorite in
            byKey[favorite.favoriteStorageKey] ?? flaggedCopy(for: favorite, forceFavorite: true)
        }

        if refreshedFavorites != favoriteLibrary {
            favoriteLibrary = refreshedFavorites.map { flaggedCopy(for: $0, forceFavorite: true) }
        }
    }

    private func flaggedCopy(for affirmation: Affirmation, forceFavorite: Bool? = nil) -> Affirmation {
        var copy = affirmation
        copy.isFavorite = forceFavorite ?? favoriteLibrary.contains(where: { $0.favoriteStorageKey == affirmation.favoriteStorageKey })
        return copy
    }

    private func notifyUserAffirmationSyncChanged() {
        guard !isApplyingRemoteUserSync else { return }
        syncCoordinator.scheduleSync()
    }

    private func notifyFavoriteSyncChanged() {
        guard !isApplyingRemoteFavoriteSync else { return }
        favoriteSyncCoordinator.scheduleSync()
    }

    func userSubmittedAffirmationsForSync() -> [Affirmation] {
        userSubmittedAffirmations
    }

    func userAffirmationTombstonesForSync() -> [UserAffirmationTombstone] {
        deletedUserAffirmationTombstones
    }

    func favoriteAffirmationsForSync() -> [Affirmation] {
        favoriteLibrary
    }

    func favoriteAffirmationTombstonesForSync() -> [FavoriteAffirmationTombstone] {
        deletedFavoriteAffirmationTombstones
    }

    func applyRemoteUserSync(
        affirmations remoteAffirmations: [Affirmation],
        tombstones remoteTombstones: [UserAffirmationTombstone]
    ) {
        let localAffirmations = Dictionary(uniqueKeysWithValues: userSubmittedAffirmations.map { ($0.id, $0) })
        let remoteAffirmationMap = Dictionary(uniqueKeysWithValues: remoteAffirmations.map { ($0.id, $0) })
        let localTombstoneMap = Dictionary(uniqueKeysWithValues: deletedUserAffirmationTombstones.map { ($0.id, $0) })
        let remoteTombstoneMap = Dictionary(uniqueKeysWithValues: remoteTombstones.map { ($0.id, $0) })

        let allIDs = Set(localAffirmations.keys)
            .union(remoteAffirmationMap.keys)
            .union(localTombstoneMap.keys)
            .union(remoteTombstoneMap.keys)

        var mergedAffirmations: [Affirmation] = []
        var mergedTombstones: [UserAffirmationTombstone] = []

        for id in allIDs {
            let localAffirmation = localAffirmations[id]
            let remoteAffirmation = remoteAffirmationMap[id]
            let localTombstone = localTombstoneMap[id]
            let remoteTombstone = remoteTombstoneMap[id]

            let latestAffirmation = [localAffirmation, remoteAffirmation]
                .compactMap { $0 }
                .max { $0.syncTimestamp < $1.syncTimestamp }
            let latestTombstone = [localTombstone, remoteTombstone]
                .compactMap { $0 }
                .max { $0.deletedAt < $1.deletedAt }

            switch (latestAffirmation, latestTombstone) {
            case let (.some(affirmation), .some(tombstone)):
                if affirmation.syncTimestamp >= tombstone.deletedAt {
                    mergedAffirmations.append(flaggedCopy(for: affirmation))
                } else {
                    mergedTombstones.append(tombstone)
                }
            case let (.some(affirmation), .none):
                mergedAffirmations.append(flaggedCopy(for: affirmation))
            case let (.none, .some(tombstone)):
                mergedTombstones.append(tombstone)
            case (.none, .none):
                break
            }
        }

        mergedTombstones.sort { $0.deletedAt > $1.deletedAt }
        mergedAffirmations.sort { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }

        let deletedKeys = Set(mergedTombstones.map { "user:\($0.id.uuidString.lowercased())" })

        isApplyingRemoteUserSync = true
        userSubmittedAffirmations = mergedAffirmations
        deletedUserAffirmationTombstones = mergedTombstones
        if !deletedKeys.isEmpty {
            for key in deletedKeys {
                if let tombstone = mergedTombstones.first(where: { "user:\($0.id.uuidString.lowercased())" == key }) {
                    removeFavoriteSnapshot(for: key, deletedAt: tombstone.deletedAt)
                }
            }
        }
        isApplyingRemoteUserSync = false

        applyFavoriteFlagsToCollections()
    }

    func applyRemoteFavoriteSync(
        favorites remoteFavorites: [Affirmation],
        tombstones remoteTombstones: [FavoriteAffirmationTombstone]
    ) {
        let localFavorites = Dictionary(uniqueKeysWithValues: favoriteLibrary.map { ($0.favoriteStorageKey, $0) })
        let remoteFavoriteMap = Dictionary(uniqueKeysWithValues: remoteFavorites.map { ($0.favoriteStorageKey, $0) })
        let localTombstoneMap = Dictionary(uniqueKeysWithValues: deletedFavoriteAffirmationTombstones.map { ($0.favoriteStorageKey, $0) })
        let remoteTombstoneMap = Dictionary(uniqueKeysWithValues: remoteTombstones.map { ($0.favoriteStorageKey, $0) })

        let allKeys = Set(localFavorites.keys)
            .union(remoteFavoriteMap.keys)
            .union(localTombstoneMap.keys)
            .union(remoteTombstoneMap.keys)

        var mergedFavorites: [Affirmation] = []
        var mergedTombstones: [FavoriteAffirmationTombstone] = []

        for key in allKeys {
            let localFavorite = localFavorites[key]
            let remoteFavorite = remoteFavoriteMap[key]
            let localTombstone = localTombstoneMap[key]
            let remoteTombstone = remoteTombstoneMap[key]

            let latestFavorite = [localFavorite, remoteFavorite]
                .compactMap { $0 }
                .max { $0.syncTimestamp < $1.syncTimestamp }
            let latestTombstone = [localTombstone, remoteTombstone]
                .compactMap { $0 }
                .max { $0.deletedAt < $1.deletedAt }

            switch (latestFavorite, latestTombstone) {
            case let (.some(favorite), .some(tombstone)):
                if favorite.syncTimestamp >= tombstone.deletedAt {
                    mergedFavorites.append(flaggedCopy(for: favorite, forceFavorite: true))
                } else {
                    mergedTombstones.append(tombstone)
                }
            case let (.some(favorite), .none):
                mergedFavorites.append(flaggedCopy(for: favorite, forceFavorite: true))
            case let (.none, .some(tombstone)):
                mergedTombstones.append(tombstone)
            case (.none, .none):
                break
            }
        }

        mergedFavorites.sort { $0.syncTimestamp > $1.syncTimestamp }
        mergedTombstones.sort { $0.deletedAt > $1.deletedAt }

        isApplyingRemoteFavoriteSync = true
        favoriteLibrary = mergedFavorites
        deletedFavoriteAffirmationTombstones = mergedTombstones
        isApplyingRemoteFavoriteSync = false

        applyFavoriteFlagsToCollections()
    }

    private func removeFavoriteSnapshot(for favoriteStorageKey: String, deletedAt: Date) {
        guard favoriteLibrary.contains(where: { $0.favoriteStorageKey == favoriteStorageKey }) else { return }
        favoriteLibrary.removeAll { $0.favoriteStorageKey == favoriteStorageKey }
        deletedFavoriteAffirmationTombstones.removeAll { $0.favoriteStorageKey == favoriteStorageKey }
        deletedFavoriteAffirmationTombstones.append(
            FavoriteAffirmationTombstone(
                favoriteStorageKey: favoriteStorageKey,
                deletedAt: deletedAt
            )
        )
    }
}

// Custom notification for when an affirmation can't be found in the store
extension Notification.Name {
    static let affirmationNotFound = Notification.Name("affirmationNotFound")
}
