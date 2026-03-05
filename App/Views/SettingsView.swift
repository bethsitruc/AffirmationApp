import SwiftUI
import WidgetKit
import AffirmationShared

struct SettingsView: View {
    @EnvironmentObject private var appearance: AppearanceSettings
    @State private var homeRefreshCadence = HomeFeedRefreshPreferences.cadence

    var body: some View {
        List {
            Section("Home Feed Refresh") {
                Picker("Frequency", selection: $homeRefreshCadence) {
                    ForEach(AutoGenerationCadence.allCases) { cadence in
                        Text(cadence.displayName).tag(cadence)
                    }
                }
                .pickerStyle(.segmented)

                Text("We'll rotate older built-in affirmations with freshly generated ones using this schedule.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("Appearance") {
                NavigationLink {
                    AppearancePickerView(appearance: appearance)
                        .navigationTitle("Appearance")
                } label: {
                    Label("Themes & Fonts", systemImage: "paintpalette")
                }

                Text("Updates apply across the app, widgets, and share cards.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("Home Widget") {
                Text("Long-press the Home Screen, tap “+”, search for Grounded, then choose Affirmation or Shuffle. Tap the widget once it’s placed to pick the source and cadence.")
                    .font(.body)
                    .foregroundColor(.primary)
            }

            Section("About") {
                Text("Grounded: Affirmations App keeps your favorite encouragement close by. Save personal entries, favorite built-ins, or ask Apple Intelligence for something new.")
                Text("Questions? bethanycurtis.builds@gmail.com")
                    .foregroundColor(.secondary)
            }
        }
        .onChange(of: homeRefreshCadence) { HomeFeedRefreshPreferences.cadence = $0 }
        .navigationTitle("Settings")
    }
}
