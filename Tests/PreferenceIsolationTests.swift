import AffirmationShared
import Foundation
import Testing

extension GroundedTests {
    @Suite("Preference test isolation")
    struct PreferenceIsolationTests {
        @Test("Test preference writes remain in the test suite and preserve change notifications")
        func isolatedPreferences() throws {
            let state = TestDefaults(); defer { state.restore() }
            #expect(RuntimeEnvironment.isTesting)
            let key = "isolated-test-\(UUID())"
            let production = try #require(UserDefaults(suiteName: Config.appGroup))
            let changes = LockedCounter()
            let token = NotificationCenter.default.addObserver(forName: .cloudPreferencesDidChange, object: nil, queue: nil) { _ in
                changes.increment()
            }
            defer { NotificationCenter.default.removeObserver(token) }
            CloudPreferenceStore.set("test value", forKey: key)
            #expect(CloudPreferenceStore.string(forKey: key) == "test value")
            #expect(SharedDefaults.string(forKey: key) == "test value")
            #expect(production.object(forKey: key) == nil)
            CloudPreferenceStore.set(123.0, forKey: key)
            #expect(CloudPreferenceStore.double(forKey: key) == 123)
            CloudPreferenceStore.removeObject(forKey: key)
            #expect(SharedDefaults.object(forKey: key) == nil)
            #expect(production.object(forKey: key) == nil)
            #expect(changes.value == 3)
        }
    }
}
