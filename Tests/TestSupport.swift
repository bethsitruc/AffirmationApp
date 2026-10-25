import AffirmationShared
import Foundation
import Testing

@Suite("Grounded", .serialized)
struct GroundedTests {}

struct TestDefaults {
    private let domain = Config.appGroup + ".tests"
    private let values: [String: Any]
    init() {
        precondition(RuntimeEnvironment.isTesting, "Test fixtures require the isolated test suite")
        values = SharedDefaults.persistentDomain(forName: domain) ?? [:]
        SharedDefaults.removePersistentDomain(forName: domain)
    }
    func restore() { SharedDefaults.setPersistentDomain(values, forName: domain) }
}

final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
    func increment() { lock.lock(); defer { lock.unlock() }; count += 1 }
}
