import SwiftUI
import AffirmationShared

struct SettingsView: View {
    @EnvironmentObject private var appearance: AppearanceSettings
    @EnvironmentObject private var store: AffirmationStore
    @State private var homeRefreshCadence = HomeFeedRefreshPreferences.cadence
    private let zenQuotesURL = URL(string: "https://zenquotes.io")!

    var body: some View {
        withCadenceChange(
            List {
                Section("Home Feed Refresh") {
                    Picker("Frequency", selection: $homeRefreshCadence) {
                        ForEach(AutoGenerationCadence.allCases) { cadence in
                            Text(cadence.displayName).tag(cadence)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Refresh Home with new ZenQuotes quotes.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Link("ZenQuotes Attribution", destination: zenQuotesURL)
                        .font(.footnote)
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Home Screen -> + -> search Grounded.")
                        Text("2. Grounded Affirmation: pin one favorite or personal affirmation.")
                        Text("3. Grounded Shuffle: pick source; refreshes hourly.")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }

                Section("About") {
                    Text("Grounded keeps encouragement simple: save favorites, add your own, and share cards.")
                    Text("Apple Intelligence is only used when you tap Generate while creating an affirmation.")
                    Text("Support: bethanycurtis.builds@gmail.com")
                        .foregroundColor(.secondary)
                }

                Section("Sync") {
                    Button("Sync Now") {
                        store.refreshUserAffirmationSync()
                    }

                    Text(syncStatusMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        )
        .navigationTitle("Settings")
        .onReceive(NotificationCenter.default.publisher(for: .cloudPreferencesDidChange)) { _ in
            homeRefreshCadence = HomeFeedRefreshPreferences.cadence
        }
        .onAppear {
            homeRefreshCadence = HomeFeedRefreshPreferences.cadence
        }
    }

    @ViewBuilder
    private func withCadenceChange<Content: View>(_ content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: homeRefreshCadence) { _, newValue in
                HomeFeedRefreshPreferences.cadence = newValue
            }
        } else {
            content.onChange(of: homeRefreshCadence) { newValue in
                HomeFeedRefreshPreferences.cadence = newValue
            }
        }
    }

    private var syncStatusMessage: String {
        if let error = latestSyncError {
            return "Last sync issue: \(error)"
        }

        if let lastSuccess = latestSyncSuccess {
            return "Last synced \(lastSuccess.formatted(date: .abbreviated, time: .shortened))."
        }

        return "Keeps favorites, personal affirmations, and appearance in sync across your devices."
    }

    private var latestSyncSuccess: Date? {
        [
            store.syncDiagnostics.userAffirmations.lastSuccessAt,
            store.syncDiagnostics.favorites.lastSuccessAt,
        ]
        .compactMap { $0 }
        .max()
    }

    private var latestSyncError: String? {
        store.syncDiagnostics.userAffirmations.lastError
            ?? store.syncDiagnostics.favorites.lastError
    }
}
