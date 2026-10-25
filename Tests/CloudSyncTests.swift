import AffirmationShared
import CloudKit
import Foundation
import Testing
@testable import AffirmationApp

extension GroundedTests {
    @MainActor
    @Suite("Cloud sync transport and records")
    struct CloudSyncTests {
        @Test("User records and tombstones round-trip through actual coordinator operations")
        func userRecordRoundTrip() async throws {
            let defaults = TestDefaults(); defer { defaults.restore() }
            let wire = FakeCloudTransport()
            let coordinator = CloudUserAffirmationSyncCoordinator(submit: wire.submit)
            let store = AffirmationStore(syncCoordinator: coordinator, favoriteSyncCoordinator: NoOpFavoriteLibrarySyncCoordinator())
            store.addUserAffirmation(text: "Synced personal", themes: ["growth"], isUserCreated: true, isAIGenerated: true)
            await coordinator.currentSync?.value
            let original = try #require(store.userSubmittedAffirmations.first)
            let uploaded = try #require(wire.saved.first { $0.recordID.recordName == original.id.uuidString.lowercased() })
            #expect(uploaded["text"] as? String == original.text)
            #expect(uploaded["themes"] as? [String] == ["growth"])
            #expect(uploaded["updatedAt"] as? Date == original.updatedAt)
            #expect((uploaded["isAIGenerated"] as? NSNumber)?.boolValue == true)
            store.userSubmittedAffirmations = []
            await coordinator.currentSync?.value
            #expect(store.userSubmittedAffirmations.first?.text == original.text)
            #expect(store.userSubmittedAffirmations.first?.isAIGenerated == true)
            store.deleteUserAffirmation(original)
            await coordinator.currentSync?.value
            let tombstone = try #require(wire.saved.first { $0.recordID == uploaded.recordID })
            #expect((tombstone["isDeleted"] as? NSNumber)?.boolValue == true)
            coordinator.scheduleSync(); await coordinator.currentSync?.value
            #expect(store.userSubmittedAffirmations.isEmpty)
        }

        @Test("Favorite records preserve stable identity and deletion across sync")
        func favoriteRecordRoundTrip() async throws {
            let defaults = TestDefaults(); defer { defaults.restore() }
            let wire = FakeCloudTransport()
            let coordinator = CloudFavoriteLibrarySyncCoordinator(submit: wire.submit)
            let store = AffirmationStore(syncCoordinator: NoOpUserAffirmationSyncCoordinator(), favoriteSyncCoordinator: coordinator)
            let item = try #require(store.affirmations.first)
            store.toggleFavorite(for: item)
            await coordinator.currentSync?.value
            let record = try #require(wire.saved.first)
            #expect(record.recordID.recordName == item.favoriteSyncID)
            #expect(record["favoriteStorageKey"] as? String == item.favoriteStorageKey)
            coordinator.start(); await coordinator.currentSync?.value
            #expect(store.favoriteAffirmations().count == 1)
            store.toggleFavorite(for: try #require(store.favoriteAffirmations().first))
            await coordinator.currentSync?.value
            coordinator.scheduleSync(); await coordinator.currentSync?.value
            #expect(store.favoriteAffirmations().isEmpty)
            #expect((wire.saved.first?["isDeleted"] as? NSNumber)?.boolValue == true)
        }

        @Test("Save failure is reported and a later sync recovers", arguments: [false, true])
        func failuresRecover(favorites: Bool) async throws {
            let defaults = TestDefaults(); defer { defaults.restore() }
            let wire = FakeCloudTransport(); wire.failSaves = true
            let user = CloudUserAffirmationSyncCoordinator(submit: wire.submit)
            let favorite = CloudFavoriteLibrarySyncCoordinator(submit: wire.submit)
            let store = AffirmationStore(syncCoordinator: user, favoriteSyncCoordinator: favorite)
            if favorites { store.toggleFavorite(for: try #require(store.affirmations.first)) }
            else { store.addUserAffirmation(text: "Retry", themes: [], isUserCreated: true) }
            await user.currentSync?.value; await favorite.currentSync?.value
            #expect((favorites ? store.syncDiagnostics.favorites : store.syncDiagnostics.userAffirmations).lastError != nil)
            wire.failSaves = false
            if favorites { favorite.scheduleSync(); await favorite.currentSync?.value }
            else { user.scheduleSync(); await user.currentSync?.value }
            #expect((favorites ? store.syncDiagnostics.favorites : store.syncDiagnostics.userAffirmations).lastError == nil)
            #expect(!wire.saved.isEmpty)
        }

        @Test("A successful upload does not hide a failed fetch", arguments: [false, true])
        func fetchFailureRemainsVisible(favorites: Bool) async throws {
            let defaults = TestDefaults(); defer { defaults.restore() }
            let wire = FakeCloudTransport(); wire.failQueries = true
            let user = CloudUserAffirmationSyncCoordinator(submit: wire.submit)
            let favorite = CloudFavoriteLibrarySyncCoordinator(submit: wire.submit)
            let store = AffirmationStore(syncCoordinator: user, favoriteSyncCoordinator: favorite)
            if favorites { store.toggleFavorite(for: try #require(store.affirmations.first)) }
            else { store.addUserAffirmation(text: "Local upload", themes: [], isUserCreated: true) }
            await user.currentSync?.value; await favorite.currentSync?.value
            #expect(!wire.saved.isEmpty)
            #expect((favorites ? store.syncDiagnostics.favorites : store.syncDiagnostics.userAffirmations).lastError != nil)
        }

        @Test("Overlapping requests are coalesced into one additional sync", arguments: [false, true])
        func coalescesRequests(favorites: Bool) async {
            let defaults = TestDefaults(); defer { defaults.restore() }
            let wire = FakeCloudTransport(); wire.holdQueries = true
            let user = CloudUserAffirmationSyncCoordinator(submit: wire.submit)
            let favorite = CloudFavoriteLibrarySyncCoordinator(submit: wire.submit)
            let store = AffirmationStore(syncCoordinator: user, favoriteSyncCoordinator: favorite)
            if favorites { favorite.start() } else { user.start() }
            for _ in 0..<100 where wire.pendingQuery == nil { await Task.yield() }
            #expect(wire.pendingQuery != nil)
            if favorites { favorite.scheduleSync(); favorite.scheduleSync() }
            else { user.scheduleSync(); user.scheduleSync() }
            wire.holdQueries = false
            wire.pendingQuery?.queryResultBlock?(.success(nil)); wire.pendingQuery = nil
            if favorites { await favorite.currentSync?.value } else { await user.currentSync?.value }
            #expect(wire.queries == 2)
            #expect((favorites ? store.syncDiagnostics.favorites : store.syncDiagnostics.userAffirmations).lastSuccessAt != nil)
        }
    }
}

@MainActor
private final class FakeCloudTransport {
    var saved: [CKRecord] = []
    var failSaves = false
    var failQueries = false
    var holdQueries = false
    var pendingQuery: CKQueryOperation?
    var queries = 0
    func submit(_ operation: CKDatabaseOperation) {
        if let query = operation as? CKQueryOperation {
            queries += 1
            if failQueries { query.queryResultBlock?(.failure(CKError(.networkFailure))); return }
            if holdQueries { pendingQuery = query; return }
            for record in saved { query.recordMatchedBlock?(record.recordID, .success(record)) }
            query.queryResultBlock?(.success(nil))
        } else if let modify = operation as? CKModifyRecordsOperation {
            if failSaves { modify.modifyRecordsResultBlock?(.failure(CKError(.networkFailure))); return }
            for record in modify.recordsToSave ?? [] {
                saved.removeAll { $0.recordID == record.recordID }; saved.append(record)
            }
            modify.modifyRecordsResultBlock?(.success(()))
        } else { Issue.record("Unexpected CloudKit operation") }
    }
}
