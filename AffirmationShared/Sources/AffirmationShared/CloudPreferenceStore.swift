import Foundation

public extension Notification.Name {
    static let cloudPreferencesDidChange = Notification.Name("cloudPreferencesDidChange")
}

public enum CloudPreferenceStore {
    private actor ObservationState {
        private var hasStartedObserving = false
        private var token: NSObjectProtocol?

        func shouldStart() -> Bool {
            guard !hasStartedObserving else { return false }
            hasStartedObserving = true
            return true
        }

        func setToken(_ token: NSObjectProtocol) {
            self.token = token
        }
    }

    private static let observationState = ObservationState()
    private static var ubiquitous: NSUbiquitousKeyValueStore { .default }

    public static func startObserving() {
        guard !RuntimeEnvironment.isTesting else { return }
        Task { @MainActor in
            let shouldStart = await observationState.shouldStart()
            guard shouldStart else {
                _ = synchronize()
                return
            }

            let token = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: ubiquitous,
                queue: .main
            ) { notification in
                synchronize()
                mirrorChangedKeys(from: notification)
                NotificationCenter.default.post(name: .cloudPreferencesDidChange, object: nil)
            }
            await observationState.setToken(token)
            _ = synchronize()
        }
    }

    @discardableResult
    public static func synchronize() -> Bool {
        guard !RuntimeEnvironment.isTesting else { return true }
        return ubiquitous.synchronize()
    }

    public static func string(forKey key: String) -> String? {
        if RuntimeEnvironment.isTesting { return SharedDefaults.string(forKey: key) }
        if let value = ubiquitous.string(forKey: key) {
            SharedDefaults.set(value, forKey: key)
            return value
        }

        if let local = SharedDefaults.string(forKey: key) {
            ubiquitous.set(local, forKey: key)
            ubiquitous.synchronize()
            return local
        }

        return nil
    }

    public static func set(_ value: String, forKey key: String) {
        if RuntimeEnvironment.isTesting {
            SharedDefaults.set(value, forKey: key)
            NotificationCenter.default.post(name: .cloudPreferencesDidChange, object: nil)
            return
        }
        ubiquitous.set(value, forKey: key)
        SharedDefaults.set(value, forKey: key)
        ubiquitous.synchronize()
        NotificationCenter.default.post(name: .cloudPreferencesDidChange, object: nil)
    }

    public static func double(forKey key: String) -> Double {
        if RuntimeEnvironment.isTesting { return SharedDefaults.double(forKey: key) }
        if let cloudNumber = ubiquitous.object(forKey: key) as? NSNumber {
            let value = cloudNumber.doubleValue
            SharedDefaults.set(value, forKey: key)
            return value
        }

        let localValue = SharedDefaults.double(forKey: key)
        if localValue != 0 {
            ubiquitous.set(localValue, forKey: key)
            ubiquitous.synchronize()
        }
        return localValue
    }

    public static func set(_ value: Double, forKey key: String) {
        if RuntimeEnvironment.isTesting {
            SharedDefaults.set(value, forKey: key)
            NotificationCenter.default.post(name: .cloudPreferencesDidChange, object: nil)
            return
        }
        ubiquitous.set(value, forKey: key)
        SharedDefaults.set(value, forKey: key)
        ubiquitous.synchronize()
        NotificationCenter.default.post(name: .cloudPreferencesDidChange, object: nil)
    }

    public static func removeObject(forKey key: String) {
        if RuntimeEnvironment.isTesting {
            SharedDefaults.removeObject(forKey: key)
            NotificationCenter.default.post(name: .cloudPreferencesDidChange, object: nil)
            return
        }
        ubiquitous.removeObject(forKey: key)
        SharedDefaults.removeObject(forKey: key)
        ubiquitous.synchronize()
        NotificationCenter.default.post(name: .cloudPreferencesDidChange, object: nil)
    }

    private static func mirrorChangedKeys(from notification: Notification) {
        guard
            let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        else { return }

        for key in keys {
            if let value = ubiquitous.object(forKey: key) {
                SharedDefaults.set(value, forKey: key)
            } else {
                SharedDefaults.removeObject(forKey: key)
            }
        }
    }
}
