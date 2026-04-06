import Foundation

struct SyncChannelDiagnostics: Equatable {
    var lastAttemptAt: Date?
    var lastSuccessAt: Date?
    var lastError: String?
}

struct SyncDiagnostics: Equatable {
    var userAffirmations = SyncChannelDiagnostics()
    var favorites = SyncChannelDiagnostics()
}
