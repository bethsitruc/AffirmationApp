import AffirmationShared
import CloudKit
import Foundation

@MainActor
final class CloudUserAffirmationSyncCoordinator: UserAffirmationSyncing {
    private weak var store: AffirmationStore?
    private let containerFactory: () -> CKContainer
    private let recordType = "UserAffirmation"

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
            await self.runSyncLoop()
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
        store.noteUserAffirmationSyncAttempt()

        do {
            let remote = try await fetchRemoteState()
            store.applyRemoteUserSync(
                affirmations: remote.affirmations,
                tombstones: remote.tombstones
            )
        } catch {
            store.noteUserAffirmationSyncFailure(error)
            #if DEBUG
            print("Cloud user affirmation fetch failed:", error.localizedDescription)
            #endif
        }

        do {
            let localAffirmations = store.userSubmittedAffirmationsForSync()
            let localTombstones = store.userAffirmationTombstonesForSync()
            try await pushState(
                affirmations: localAffirmations,
                tombstones: localTombstones
            )
            store.noteUserAffirmationSyncSuccess()
        } catch {
            store.noteUserAffirmationSyncFailure(error)
            #if DEBUG
            print("Cloud user affirmation push failed:", error.localizedDescription)
            #endif
        }
    }

    private func fetchRemoteState() async throws -> (affirmations: [Affirmation], tombstones: [UserAffirmationTombstone]) {
        let records = try await fetchAllRecords()
        let affirmations = records.compactMap(Self.affirmation(from:))
        let tombstones = records.compactMap(Self.tombstone(from:))
        return (affirmations, tombstones)
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
                let query = CKQuery(
                    recordType: recordType,
                    predicate: NSPredicate(
                        format: "createdAt > %@",
                        Date.distantPast as NSDate
                    )
                )
                query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
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
        affirmations: [Affirmation],
        tombstones: [UserAffirmationTombstone]
    ) async throws {
        let records = affirmations.map(Self.record(for:)) + tombstones.map(Self.record(for:))
        guard !records.isEmpty else { return }

        try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            containerFactory().privateCloudDatabase.add(operation)
        }
    }

    private static func record(for affirmation: Affirmation) -> CKRecord {
        let recordID = CKRecord.ID(recordName: affirmation.id.uuidString.lowercased())
        let record = CKRecord(recordType: "UserAffirmation", recordID: recordID)
        record["text"] = affirmation.text as CKRecordValue
        if !affirmation.themes.isEmpty {
            record["themes"] = affirmation.themes as CKRecordValue
        }
        record["createdAt"] = (affirmation.createdAt ?? affirmation.syncTimestamp) as CKRecordValue
        record["updatedAt"] = affirmation.syncTimestamp as CKRecordValue
        record["isAIGenerated"] = affirmation.isAIGenerated as CKRecordValue
        record["isDeleted"] = false as CKRecordValue
        record["deletedAt"] = nil
        return record
    }

    private static func record(for tombstone: UserAffirmationTombstone) -> CKRecord {
        let recordID = CKRecord.ID(recordName: tombstone.id.uuidString.lowercased())
        let record = CKRecord(recordType: "UserAffirmation", recordID: recordID)
        record["text"] = "" as CKRecordValue
        record["createdAt"] = tombstone.deletedAt as CKRecordValue
        record["updatedAt"] = tombstone.deletedAt as CKRecordValue
        record["isAIGenerated"] = false as CKRecordValue
        record["isDeleted"] = true as CKRecordValue
        record["deletedAt"] = tombstone.deletedAt as CKRecordValue
        return record
    }

    private static func affirmation(from record: CKRecord) -> Affirmation? {
        let isDeleted = record["isDeleted"] as? Int == 1 || record["isDeleted"] as? Bool == true
        guard !isDeleted, let id = UUID(uuidString: record.recordID.recordName) else { return nil }

        let text = record["text"] as? String ?? ""
        let themes = record["themes"] as? [String] ?? []
        let createdAt = record["createdAt"] as? Date
        let updatedAt = record["updatedAt"] as? Date
        let isAIGenerated = record["isAIGenerated"] as? Int == 1 || record["isAIGenerated"] as? Bool == true

        return Affirmation(
            id: id,
            text: text,
            isFavorite: false,
            isUserCreated: true,
            themes: themes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isAIGenerated: isAIGenerated
        )
    }

    private static func tombstone(from record: CKRecord) -> UserAffirmationTombstone? {
        let isDeleted = record["isDeleted"] as? Int == 1 || record["isDeleted"] as? Bool == true
        guard isDeleted, let id = UUID(uuidString: record.recordID.recordName) else { return nil }
        let deletedAt = (record["deletedAt"] as? Date) ?? (record["updatedAt"] as? Date) ?? .distantPast
        return UserAffirmationTombstone(id: id, deletedAt: deletedAt)
    }
}
