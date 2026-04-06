import AffirmationShared
import CloudKit
import Foundation

@MainActor
final class CloudFavoriteLibrarySyncCoordinator: FavoriteLibrarySyncing {
    private weak var store: AffirmationStore?
    private let containerFactory: () -> CKContainer
    private let recordType = "FavoriteAffirmation"

    private var hasStarted = false
    private var isSyncing = false
    private var needsAnotherSync = false

    init(containerFactory: @escaping () -> CKContainer) {
        self.containerFactory = containerFactory
    }

    func attach(store: AffirmationStore) {
        self.store = store
    }

    func start() {
        guard !hasStarted else {
            scheduleSync()
            return
        }

        hasStarted = true
        scheduleSync()
    }

    func scheduleSync() {
        guard store != nil else { return }
        if isSyncing {
            needsAnotherSync = true
            return
        }

        isSyncing = true
        Task {
            await runSyncLoop()
        }
    }

    private func runSyncLoop() async {
        repeat {
            needsAnotherSync = false
            await syncOnce()
        } while needsAnotherSync

        isSyncing = false
    }

    private func syncOnce() async {
        guard let store else { return }
        store.noteFavoriteSyncAttempt()

        do {
            let remote = try await fetchRemoteState()
            store.applyRemoteFavoriteSync(
                favorites: remote.favorites,
                tombstones: remote.tombstones
            )
        } catch {
            store.noteFavoriteSyncFailure(error)
            #if DEBUG
            print("Cloud favorite fetch failed:", error.localizedDescription)
            #endif
        }

        do {
            let localFavorites = store.favoriteAffirmationsForSync()
            let localTombstones = store.favoriteAffirmationTombstonesForSync()
            try await pushState(favorites: localFavorites, tombstones: localTombstones)
            store.noteFavoriteSyncSuccess()
        } catch {
            store.noteFavoriteSyncFailure(error)
            #if DEBUG
            print("Cloud favorite push failed:", error.localizedDescription)
            #endif
        }
    }

    private func fetchRemoteState() async throws -> (favorites: [Affirmation], tombstones: [FavoriteAffirmationTombstone]) {
        let records = try await fetchAllRecords()
        let favorites = records.compactMap(Self.favorite(from:))
        let tombstones = records.compactMap(Self.tombstone(from:))
        return (favorites, tombstones)
    }

    private func fetchAllRecords() async throws -> [CKRecord] {
        var fetchedRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let batch = try await fetchBatch(cursor: cursor)
            fetchedRecords.append(contentsOf: batch.records)
            cursor = batch.cursor
        } while cursor != nil

        return fetchedRecords
    }

    private func fetchBatch(cursor: CKQueryOperation.Cursor?) async throws -> (records: [CKRecord], cursor: CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { continuation in
            let operation: CKQueryOperation
            if let cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                operation = CKQueryOperation(query: query)
            }

            var records: [CKRecord] = []
            var firstError: Error?

            operation.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    if firstError == nil {
                        firstError = error
                    }
                }
            }

            operation.queryResultBlock = { result in
                switch result {
                case .success(let nextCursor):
                    if let firstError {
                        continuation.resume(throwing: firstError)
                    } else {
                        continuation.resume(returning: (records, nextCursor))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            containerFactory().privateCloudDatabase.add(operation)
        }
    }

    private func pushState(
        favorites: [Affirmation],
        tombstones: [FavoriteAffirmationTombstone]
    ) async throws {
        let records = favorites.map(Self.record(for:)) + tombstones.map(Self.record(for:))
        guard !records.isEmpty else { return }

        try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            containerFactory().privateCloudDatabase.add(operation)
        }
    }

    private static func record(for affirmation: Affirmation) -> CKRecord {
        let recordID = CKRecord.ID(recordName: affirmation.favoriteSyncID)
        let record = CKRecord(recordType: "FavoriteAffirmation", recordID: recordID)
        record["favoriteStorageKey"] = affirmation.favoriteStorageKey as CKRecordValue
        record["id"] = affirmation.id.uuidString.lowercased() as CKRecordValue
        record["text"] = affirmation.text as CKRecordValue
        if !affirmation.themes.isEmpty {
            record["themes"] = affirmation.themes as CKRecordValue
        }
        record["createdAt"] = (affirmation.createdAt ?? affirmation.syncTimestamp) as CKRecordValue
        record["updatedAt"] = affirmation.syncTimestamp as CKRecordValue
        record["isUserCreated"] = affirmation.isUserCreated as CKRecordValue
        record["isAIGenerated"] = affirmation.isAIGenerated as CKRecordValue
        record["isDeleted"] = false as CKRecordValue
        record["deletedAt"] = nil
        return record
    }

    private static func record(for tombstone: FavoriteAffirmationTombstone) -> CKRecord {
        let recordID = CKRecord.ID(recordName: tombstone.favoriteSyncID)
        let record = CKRecord(recordType: "FavoriteAffirmation", recordID: recordID)
        record["favoriteStorageKey"] = tombstone.favoriteStorageKey as CKRecordValue
        record["id"] = tombstone.favoriteSyncID as CKRecordValue
        record["text"] = "" as CKRecordValue
        record["createdAt"] = tombstone.deletedAt as CKRecordValue
        record["updatedAt"] = tombstone.deletedAt as CKRecordValue
        record["isUserCreated"] = false as CKRecordValue
        record["isAIGenerated"] = false as CKRecordValue
        record["isDeleted"] = true as CKRecordValue
        record["deletedAt"] = tombstone.deletedAt as CKRecordValue
        return record
    }

    private static func favorite(from record: CKRecord) -> Affirmation? {
        let isDeleted = (record["isDeleted"] as? Int == 1) || (record["isDeleted"] as? Bool == true)
        guard !isDeleted else { return nil }

        let idString = record["id"] as? String ?? UUID().uuidString
        let id = UUID(uuidString: idString) ?? UUID()
        let text = record["text"] as? String ?? ""
        let themes = record["themes"] as? [String] ?? []
        let createdAt = record["createdAt"] as? Date
        let updatedAt = record["updatedAt"] as? Date
        let isUserCreated = (record["isUserCreated"] as? Int == 1) || (record["isUserCreated"] as? Bool == true)
        let isAIGenerated = (record["isAIGenerated"] as? Int == 1) || (record["isAIGenerated"] as? Bool == true)

        return Affirmation(
            id: id,
            text: text,
            isFavorite: true,
            isUserCreated: isUserCreated,
            themes: themes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isAIGenerated: isAIGenerated
        )
    }

    private static func tombstone(from record: CKRecord) -> FavoriteAffirmationTombstone? {
        let isDeleted = (record["isDeleted"] as? Int == 1) || (record["isDeleted"] as? Bool == true)
        guard isDeleted, let favoriteStorageKey = record["favoriteStorageKey"] as? String else { return nil }
        let deletedAt = (record["deletedAt"] as? Date) ?? (record["updatedAt"] as? Date) ?? .distantPast
        return FavoriteAffirmationTombstone(favoriteStorageKey: favoriteStorageKey, deletedAt: deletedAt)
    }
}
