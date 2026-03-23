import SwiftUI
import AffirmationShared
import WidgetKit

@MainActor
final class AppearanceSettings: ObservableObject {
    @Published private(set) var theme: AffirmationColorTheme
    @Published private(set) var font: AffirmationFontPreference
    private var cloudObserver: NSObjectProtocol?

    init(theme: AffirmationColorTheme = AppearancePreferences.theme,
         font: AffirmationFontPreference = AppearancePreferences.font) {
        self.theme = theme
        self.font = font
        cloudObserver = NotificationCenter.default.addObserver(
            forName: .cloudPreferencesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncFromDefaults()
        }
    }

    deinit {
        if let cloudObserver {
            NotificationCenter.default.removeObserver(cloudObserver)
        }
    }

    func updateTheme(_ theme: AffirmationColorTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        AppearancePreferences.theme = theme
        reloadWidgets()
    }

    func updateFont(_ font: AffirmationFontPreference) {
        guard self.font != font else { return }
        self.font = font
        AppearancePreferences.font = font
        reloadWidgets()
    }

    func syncFromDefaults() {
        theme = AppearancePreferences.theme
        font = AppearancePreferences.font
    }

    private func reloadWidgets() {
        #if !os(macOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
