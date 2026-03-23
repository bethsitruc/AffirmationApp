import Foundation

public enum AffirmationColorTheme: String, CaseIterable, Codable {
    case sage
    case dusk
    case glow
}
extension AffirmationColorTheme: Identifiable {}

public enum AffirmationFontPreference: String, CaseIterable, Codable {
    case serif
    case rounded
    case modern
}
extension AffirmationFontPreference: Identifiable {}

public enum AppearancePreferences {
    private static let themeKey = "appearance.theme"
    private static let fontKey = "appearance.font"

    public static var theme: AffirmationColorTheme {
        get {
            guard
                let stored = CloudPreferenceStore.string(forKey: themeKey),
                let value = AffirmationColorTheme(rawValue: stored)
            else { return .sage }
            return value
        }
        set {
            CloudPreferenceStore.set(newValue.rawValue, forKey: themeKey)
        }
    }

    public static var font: AffirmationFontPreference {
        get {
            guard
                let stored = CloudPreferenceStore.string(forKey: fontKey),
                let value = AffirmationFontPreference(rawValue: stored)
            else { return .serif }
            return value
        }
        set {
            CloudPreferenceStore.set(newValue.rawValue, forKey: fontKey)
        }
    }
}

public extension AffirmationColorTheme {
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sage: return "Sage"
        case .dusk: return "Dusk"
        case .glow: return "Glow"
        }
    }
}

public extension AffirmationFontPreference {
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .serif: return "Serif"
        case .rounded: return "Rounded"
        case .modern: return "Modern"
        }
    }
}
