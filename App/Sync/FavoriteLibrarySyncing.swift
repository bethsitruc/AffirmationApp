import AffirmationShared
import CryptoKit
import Foundation

@MainActor
protocol FavoriteLibrarySyncing {
    func attach(store: AffirmationStore)
    func start()
    func scheduleSync()
}

@MainActor
final class NoOpFavoriteLibrarySyncCoordinator: FavoriteLibrarySyncing {
    func attach(store: AffirmationStore) {}
    func start() {}
    func scheduleSync() {}
}

struct FavoriteAffirmationTombstone: Codable, Equatable {
    let favoriteStorageKey: String
    let deletedAt: Date

    var favoriteSyncID: String {
        let digest = SHA256.hash(data: Data(favoriteStorageKey.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
