import Foundation
import XCTest

@MainActor
func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
    Snapshot.setup(app, waitForAnimations: waitForAnimations)
}

@MainActor
func snapshot(_ name: String, timeWaitingForIdle timeout: TimeInterval = 20) {
    Snapshot.capture(name, timeWaitingForIdle: timeout)
}

@MainActor
private enum Snapshot {
    static var app: XCUIApplication?
    static var waitForAnimations = true
    static var screenshotsDirectory: URL?

    static func setup(_ app: XCUIApplication, waitForAnimations: Bool) {
        self.app = app
        self.waitForAnimations = waitForAnimations

        guard let simulatorHostHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else {
            XCTFail("Fastlane Snapshot requires a simulator")
            return
        }

        let cacheDirectory = URL(fileURLWithPath: simulatorHostHome)
            .appendingPathComponent("Library/Caches/tools.fastlane", isDirectory: true)
        screenshotsDirectory = cacheDirectory.appendingPathComponent("screenshots", isDirectory: true)

        appendSetting(from: cacheDirectory.appendingPathComponent("language.txt"),
                      flag: "-AppleLanguages", transform: { "(\($0))" }, to: app)
        appendSetting(from: cacheDirectory.appendingPathComponent("locale.txt"),
                      flag: "-AppleLocale", transform: { "\"\($0)\"" }, to: app)
        app.launchArguments += ["-FASTLANE_SNAPSHOT", "YES", "-ui_testing"]
    }

    static func capture(_ name: String, timeWaitingForIdle timeout: TimeInterval) {
        guard app != nil, let screenshotsDirectory else {
            XCTFail("Call setupSnapshot before snapshot")
            return
        }

        if timeout > 0 {
            _ = app?.wait(for: .runningForeground, timeout: timeout)
        }
        if waitForAnimations {
            Thread.sleep(forTimeInterval: 1)
        }

        let screenshot = XCUIScreen.main.screenshot()
        guard var simulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] else {
            XCTFail("Unable to determine simulator name")
            return
        }
        simulator = simulator.replacingOccurrences(
            of: "Clone [0-9]+ of ",
            with: "",
            options: .regularExpression
        )

        do {
            try FileManager.default.createDirectory(
                at: screenshotsDirectory,
                withIntermediateDirectories: true
            )
            let destination = screenshotsDirectory.appendingPathComponent("\(simulator)-\(name).png")
            try screenshot.pngRepresentation.write(to: destination, options: .atomic)
        } catch {
            XCTFail("Unable to write screenshot \(name): \(error.localizedDescription)")
        }
    }

    private static func appendSetting(
        from file: URL,
        flag: String,
        transform: (String) -> String,
        to app: XCUIApplication
    ) {
        guard let value = try? String(contentsOf: file, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return }
        app.launchArguments += [flag, transform(value)]
    }
}

// SnapshotHelperVersion [1.30]
