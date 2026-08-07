import SwiftUI
import AffirmationShared

struct SettingsView: View {
    @EnvironmentObject private var appearance: AppearanceSettings
    @EnvironmentObject private var store: AffirmationStore
    @State private var homeRefreshCadence = HomeFeedRefreshPreferences.cadence
    @StateObject private var supportPurchase = SupportPurchaseManager()
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
                    // A menu remains usable in narrow iPhone Mirroring and iPad windows.
                    .pickerStyle(.menu)

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
                    widgetInstruction(
                        number: 1,
                        title: "Open the widget gallery",
                        detail: "Touch and hold the Home Screen, then tap Edit → Add Widget."
                    )

                    widgetInstruction(
                        number: 2,
                        title: "Find Grounded",
                        detail: "Search for Grounded and select it."
                    )

                    widgetInstruction(
                        number: 3,
                        title: "Choose your widget",
                        detail: "Pick Affirmation or Shuffle, then tap Add Widget."
                    )
                }

                Section("About") {
                    Text("Grounded keeps encouragement simple: save favorites, add your own, and share cards.")
                    Text("Apple Intelligence is only used when you tap Generate while creating an affirmation.")
                    Text("Support: bethanycurtis.builds@gmail.com")
                        .foregroundColor(.secondary)
                }

                Section("Support Grounded") {
                    ForEach(SupportPurchaseManager.options) { option in
                        Button {
                            Task { await supportPurchase.purchase(option) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: option.iconName)
                                    .foregroundStyle(appearance.theme.accentColor)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(option.title)
                                        .foregroundStyle(.primary)
                                    Text(option.subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if supportPurchase.isPurchasing(option) {
                                    ProgressView()
                                } else {
                                    Text(supportPurchase.displayPrice(for: option))
                                        .foregroundStyle(appearance.theme.accentColor)
                                }
                            }
                        }
                        .disabled(supportPurchase.isPurchasing)
                        .accessibilityIdentifier(option.accessibilityIdentifier)
                    }

                    Text("Each option is a one-time contribution that helps fund future updates. No features are locked behind a purchase.")
                        .font(.footnote)
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
        .task {
            await supportPurchase.loadProducts()
        }
        .alert("Support Grounded", isPresented: Binding(
            get: { supportPurchase.notice != nil },
            set: { if !$0 { supportPurchase.notice = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(supportPurchase.notice ?? "")
        }
    }

    private func widgetInstruction(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(appearance.theme.accentColor)
                .frame(width: 28, height: 28)
                .background(appearance.theme.accentColor.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
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
