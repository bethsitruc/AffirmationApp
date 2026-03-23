import Foundation

@MainActor
protocol UserAffirmationSyncing: AnyObject {
    func attach(store: AffirmationStore)
    func start()
    func scheduleSync()
}

@MainActor
final class NoOpUserAffirmationSyncCoordinator: UserAffirmationSyncing {
    func attach(store: AffirmationStore) {}
    func start() {}
    func scheduleSync() {}
}

struct UserAffirmationTombstone: Codable, Equatable {
    let id: UUID
    let deletedAt: Date
}
