import Foundation

/// Shared by the app, widget, and hosted tests so tests never access a personal suite.
public enum RuntimeEnvironment {
    public static var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.arguments.contains("-ui-testing")
            || ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-state")
    }
}

/// Tests use a separate, persistent-on-relaunch suite within their simulator.
public var SharedDefaults: UserDefaults {
    let suite = Config.appGroup + (RuntimeEnvironment.isTesting ? ".tests" : "")
    guard let defaults = UserDefaults(suiteName: suite) else {
        fatalError("App Group UserDefaults could not be created. Check your app group identifier.")
    }
    return defaults
}
