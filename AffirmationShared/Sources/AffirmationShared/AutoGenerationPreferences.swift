import Foundation

public enum AutoGenerationCadence: String, CaseIterable, Identifiable, Codable {
    case off
    case daily
    case weekly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .off: return "Off"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }

    public var interval: TimeInterval? {
        switch self {
        case .off: return nil
        case .daily: return 60 * 60 * 24
        case .weekly: return 60 * 60 * 24 * 7
        }
    }
}

public enum AutoGenerationPreferences {
    private static let cadenceKey = "autoGeneration.cadence"
    private static let lastKey = "autoGeneration.last"

    public static var cadence: AutoGenerationCadence {
        get {
            guard
                let string = SharedDefaults.string(forKey: cadenceKey),
                let value = AutoGenerationCadence(rawValue: string)
            else { return .off }
            return value
        }
        set {
            SharedDefaults.set(newValue.rawValue, forKey: cadenceKey)
        }
    }

    public static var lastGeneratedDate: Date? {
        get {
            let interval = SharedDefaults.double(forKey: lastKey)
            return interval == 0 ? nil : Date(timeIntervalSince1970: interval)
        }
        set {
            if let value = newValue {
                SharedDefaults.set(value.timeIntervalSince1970, forKey: lastKey)
            } else {
                SharedDefaults.removeObject(forKey: lastKey)
            }
        }
    }
}

public enum HomeFeedRefreshPreferences {
    private static let cadenceKey = "homeRefresh.cadence"
    private static let lastKey = "homeRefresh.last"

    public static var cadence: AutoGenerationCadence {
        get {
            guard
                let raw = SharedDefaults.string(forKey: cadenceKey),
                let value = AutoGenerationCadence(rawValue: raw)
            else { return .weekly }
            return value
        }
        set {
            SharedDefaults.set(newValue.rawValue, forKey: cadenceKey)
        }
    }

    public static var lastRefreshDate: Date? {
        get {
            let interval = SharedDefaults.double(forKey: lastKey)
            return interval == 0 ? nil : Date(timeIntervalSince1970: interval)
        }
        set {
            if let value = newValue {
                SharedDefaults.set(value.timeIntervalSince1970, forKey: lastKey)
            } else {
                SharedDefaults.removeObject(forKey: lastKey)
            }
        }
    }
}
