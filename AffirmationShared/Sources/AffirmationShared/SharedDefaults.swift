import Foundation

/// Accessor for the shared UserDefaults suite for app group communication.
public var SharedDefaults: UserDefaults {
    guard let defaults = UserDefaults(suiteName: Config.appGroup) else {
        fatalError("App Group UserDefaults could not be created. Check your app group identifier.")
    }
    return defaults
}
