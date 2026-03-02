import SwiftUI
import WidgetKit
import AffirmationShared

struct AffirmationView: View {
    @ObservedObject var store: AffirmationStore
    @State private var displayedCount = 6
    // Track which tab is selected so we can present filled icons when active
    @State private var selection: Int = 0
    @EnvironmentObject private var appearance: AppearanceSettings
    
    var body: some View {
        // MARK: - Main Application Tab View
        // This `TabView` provides the main navigation between the three sections of the app:
        // 1. Home: MainAffirmationView showing themed, daily, and surprise affirmations.
        // 2. Favorites: View of user-favorited affirmations.
        // 3. My Affirmations: View for user-submitted affirmations (editable).
        TabView(selection: $selection) {
            NavigationStack {
                MainAffirmationView(store: store, displayedCount: $displayedCount)
            }
            .toolbar(.hidden, for: .navigationBar)
            .tabItem {
                Label {
                    Text("Home")
                } icon: {
                    DS.Icons.tabLeaf()
                }
            }
            .tag(0)

            NavigationStack {
                FavoritesView(store: store)
            }
            .toolbar(.hidden, for: .navigationBar)
            .tabItem {
                // Use outlined heart when unselected and filled when selected so state is obvious
                Label("Favorites", systemImage: selection == 1 ? "heart.fill" : "heart")
            }
            .tag(1)

            NavigationStack {
                MyAffirmationsView(store: store)
            }
            .toolbar(.hidden, for: .navigationBar)
            .tabItem {
                // Swap to a filled person icon when selected for parity with other tabs
                Label("My Affirmations", systemImage: selection == 2 ? "person.crop.circle.fill" : "person.crop.circle")
            }
            .tag(2)
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: selection == 3 ? "gearshape.fill" : "gearshape")
            }
            .tag(3)
        }
        .tint(appearance.theme.accentColor)
        .background(appearance.theme.gradient.ignoresSafeArea())
    }
}

/// The main content view for the Home tab, showing themed, daily, and surprise affirmations.
/// This view contains:
///   - A theme picker for filtering affirmations by theme.
///   - (Optional) A "Surprise Me" affirmation section.
///   - The "Affirmation of the Day" (deterministic per day).
///   - A scrollable, adaptive grid/list of affirmation tiles.
struct MainAffirmationView: View {
    private enum ActiveSheet: Int, Identifiable {
        case generatorConfig
        case generatedPreview
        case about

        var id: Int { rawValue }
    }

    @ObservedObject var store: AffirmationStore
    @Binding var displayedCount: Int
    @EnvironmentObject private var appearance: AppearanceSettings
    // Generator used for creating new affirmations
    private let generator = AffirmationGenerator()

    // UI state for generation flow
    @State private var isGenerating: Bool = false
    @State private var generatedText: String = ""
    @State private var showGenerationError: Bool = false
    @State private var generationErrorMessage: String = ""
    @State private var generationTheme: String = ""
    @State private var selectedTone: AffirmationGenerator.Tone = .calm
    @State private var fmAvailability = FoundationModelAvailability(status: .missingFramework, message: "Checking availability…")
    @State private var generationContextNote: String?
    @State private var generationSource: AffirmationGenerator.Source?
    @State private var activeSheet: ActiveSheet?
    @State private var shareTarget: Affirmation?
    @State private var showSharePicker = false
    //@State private var showingSurprise = false

    // Defines the adaptive grid column layout for short affirmations.
    let columns = [
        GridItem(.adaptive(minimum: 150), spacing: DS.Layout.tilePadding)
    ]
    
    /// Returns the deterministic "Affirmation of the Day".
    /// Uses the day of the month as a seed to always show the same affirmation for a given day.
    /// `SeededGenerator` ensures the selection is repeatable each day.
    var affirmationOfTheDay: Affirmation? {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: Date())
        var generator = SeededGenerator(seed: day)
        return store.affirmations.randomElement(using: &generator)
    }
    
    /// View for displaying the "Surprise Affirmation" (if available).
    /// This is shown when the user triggers a "Surprise Me" action (feature may be commented out).
    /// The tile includes animated favorite toggling and a themed gradient background.
    var surpriseAffirmationView: some View {
        Group {
            if let surprise = store.surpriseAffirmation {
                VStack {
                    Text("🎉 Surprise Affirmation")
                        .font(DS.Fonts.note())
                        .foregroundColor(.secondary)

                    Text(surprise.text)
                        .font(DS.Fonts.title())
                        .padding()
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .lineLimit(6)
                        .truncationMode(.tail)

                    // Animated favorite button, color and scale changes when toggled.
                    Button(action: {
                        withAnimation {
                            store.toggleFavorite(for: surprise)
                        }
                    }) {
                        Image(systemName: surprise.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(surprise.isFavorite ? appearance.theme.accentColor : .gray)
                            .scaleEffect(surprise.isFavorite ? 1.2 : 1.0)
                            .animation(.easeInOut, value: surprise.isFavorite)
                    }
                    .padding(.bottom, 8)
                }
                .padding()
                .dsCard()
                .padding(.horizontal)
            }
        }
    }
    
    /// View for displaying the "Affirmation of the Day".
    /// Uses a consistent gradient background and allows favoriting.
    var affirmationOfTheDayView: some View {
        Group {
            if let dailyAffirmation = affirmationOfTheDay {
                AffirmationTileView(
                    affirmation: dailyAffirmation,
                    isUserSubmitted: dailyAffirmation.isUserCreated,
                    style: .featuredToday
                ) {
                    withAnimation { store.toggleFavorite(for: dailyAffirmation) }
                } shareAction: {
                    shareTarget = dailyAffirmation
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }
    
    private var combinedAffirmations: [Affirmation] {
        userAffirmations + builtInAffirmations
    }

    private var userAffirmations: [Affirmation] {
        store.userSubmittedAffirmations.sorted {
            ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
        }
    }

    private var builtInAffirmations: [Affirmation] {
        store.affirmations.sorted { lhs, rhs in
            let lDate = lhs.createdAt ?? .distantPast
            let rDate = rhs.createdAt ?? .distantPast
            if lDate == rDate {
                return lhs.text < rhs.text
            }
            return lDate > rDate
        }
    }

    private var feedAffirmations: [Affirmation] {
        combinedAffirmations
    }

    /// Provides the main scrollable content of affirmation tiles.
    /// - Tiles are adaptively displayed: long affirmations take a full row, short ones are paired in a grid.
    /// - User-submitted affirmations are labeled.
    /// - Each tile includes an animated favorite button.
    /// - Infinite scroll: loading more tiles as the user scrolls.
    var affirmationRows: some View {
        // Shuffle and take a slice for display.
        let affirmations = Array(feedAffirmations.prefix(displayedCount))
        var index = 0
        var rows: [AnyView] = []

        while index < affirmations.count {
            let item = affirmations[index]

            // Long affirmation: single full-width tile.
            if item.text.count >= 50 {
                let view = AnyView(
                    AffirmationTileView(
                        affirmation: item,
                        isUserSubmitted: item.isUserCreated,
                        style: .compact
                    ) {
                        withAnimation { store.toggleFavorite(for: item) }
                    } shareAction: {
                        shareTarget = item
                    }
                    .frame(minHeight: 120)
                    .padding(Edge.Set.horizontal)
                    // Infinite scroll: load more when last tile appears.
                    .onAppear {
                        if item == affirmations.last {
                            displayedCount += 6
                        }
                    }
                )
                rows.append(view)
                index += 1
            } else {
                // Short affirmations: try to pair two in a row (adaptive grid).
                _ = affirmations.count - index
                let pair = affirmations[index..<min(index + 2, affirmations.count)].filter { $0.text.count < 50 }

                if pair.count == 2 {
                    let view = AnyView(
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(pair, id: \.id) { affirmation in
                                AffirmationTileView(
                                    affirmation: affirmation,
                                    isUserSubmitted: affirmation.isUserCreated,
                                    style: .compact
                                ) {
                                    withAnimation { store.toggleFavorite(for: affirmation) }
                                } shareAction: {
                                    shareTarget = affirmation
                                }
                                .frame(minHeight: 120)
                                .padding(4)
                                .onAppear {
                                    if affirmation == affirmations.last {
                                        displayedCount += 6
                                    }
                                }
                            }
                        }
                    )
                    rows.append(view)
                    index += 2
                } else {
                    // Last single short affirmation: show as a full-width tile.
                    if let single = pair.first {
                        let view = AnyView(
                            AffirmationTileView(
                                affirmation: single,
                                isUserSubmitted: single.isUserCreated,
                                style: .compact
                            ) {
                                withAnimation { store.toggleFavorite(for: single) }
                            } shareAction: {
                                shareTarget = single
                            }
                            .frame(minHeight: 120)
                            .padding(Edge.Set.horizontal)
                            .onAppear {
                                if single == affirmations.last {
                                    displayedCount += 6
                                }
                            }
                        )
                        rows.append(view)
                        index += 1
                    } else {
                        index += 1
                    }
                }
            }
        }

        // Stack all rows for vertical scrolling.
        return VStack(spacing: DS.Layout.tilePadding) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, rowView in
                rowView
            }
        }
        .padding(DS.Layout.tilePadding)
    }

    private var generationButton: some View {
        Button {
            activeSheet = .generatorConfig
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(appearance.theme.accentColor.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(appearance.theme.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ask Apple Intelligence")
                        .font(appearance.font.font(size: 18, weight: .semibold))
                        .foregroundColor(appearance.theme.primaryText)
                    Text(generationSummaryText)
                        .font(.footnote)
                        .foregroundColor(appearance.theme.secondaryText)
                }
                Spacer()

                if isGenerating {
                    ProgressView()
                        .tint(appearance.theme.accentColor)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(appearance.theme.secondaryText)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(appearance.theme.cardBackground.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(appearance.theme.accentColor.opacity(0.15), lineWidth: 1)
                    )
            )
            .shadow(color: appearance.theme.primaryText.opacity(0.08), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.Layout.tilePadding)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Affirmations")
                        .font(appearance.font.font(size: 34, weight: .bold))
                        .foregroundColor(appearance.theme.primaryText)
                    Text("Daily encouragement, personalized to you.")
                        .font(.footnote)
                        .foregroundColor(appearance.theme.secondaryText)
                }
                Spacer(minLength: 12)
                controlCluster
            }
        }
        .padding(.horizontal, DS.Layout.tilePadding)
    }

    private var controlCluster: some View {
        HStack(spacing: 12) {
            controlButton(systemName: "square.and.arrow.up", accessibility: "Share an affirmation card") {
                showSharePicker = true
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            Capsule(style: .continuous)
                .fill(appearance.theme.cardBackground.opacity(0.9))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(appearance.theme.cardStroke.opacity(0.6), lineWidth: 1)
                )
        )
        .shadow(color: appearance.theme.primaryText.opacity(0.12), radius: 8, x: 0, y: 6)
    }

    private var generationSummaryText: String {
        if isGenerating {
            return "Crafting a \(selectedTone.label.lowercased()) message…"
        }
        if let source = generationSource {
            switch source {
            case .foundationModel:
                return "Last idea came from Apple Intelligence."
            case .network:
                return "Last idea came from the network fallback."
            case .local:
                return "Last idea used the offline fallback."
            }
        }
        if fmAvailability.status != .available {
            return fmAvailability.message
        }
        return "Tap to craft a new affirmation."
    }

    private var emptyFeedState: some View {
        VStack(spacing: 20) {
            DS.Icons.placeholderLeaf(size: 72, color: appearance.theme.accentColor)
            Text("No affirmations yet")
                .font(DS.Fonts.title())
                .foregroundColor(appearance.theme.primaryText)
            Text("Add your first affirmation or let Apple Intelligence create one.")
                .font(DS.Fonts.note())
                .foregroundColor(appearance.theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    var body: some View {
        ZStack {
            appearance.theme.gradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Layout.tilePadding) {
                    headerSection

                    if let daily = affirmationOfTheDay {
                        AffirmationTileView(
                            affirmation: daily,
                            isUserSubmitted: daily.isUserCreated,
                            style: .featuredToday
                        ) {
                            withAnimation { store.toggleFavorite(for: daily) }
                        } shareAction: {
                            shareTarget = daily
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, DS.Layout.tilePadding)
                    }

                    generationButton

                    if feedAffirmations.isEmpty {
                        emptyFeedState
                    } else {
                        affirmationRows
                    }
                }
                .padding(.top, DS.Layout.tilePadding * 1.2)
                .padding(.bottom, DS.Layout.tilePadding)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .generatorConfig:
                generatorConfigSheet
            case .generatedPreview:
                generatedPreviewSheet
            case .about:
                aboutSheet
            }
        }
        .sheet(item: $shareTarget) { affirmation in
            ShareCardComposerView(affirmation: affirmation)
                .environmentObject(appearance)
        }
        .sheet(isPresented: $showSharePicker) {
            ShareCardPickerView(
                favorites: store.favoriteAffirmations(),
                personal: store.userSubmittedAffirmations,
                builtIn: store.affirmations,
                onSelect: { affirmation in
                    shareTarget = affirmation
                }
            )
        }
        .task {
            fmAvailability = generator.foundationModelAvailability()
        }
            // MARK: Surprise Me Button (Optional)
            /*
            Button(action: {
                store.generateSurpriseAffirmation()
                showingSurprise = true
            }) {
                Label("Surprise Me!", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DS.PrimaryPillButtonStyle(prominent: false))
            .padding(.horizontal)
            .alert("🌟 Surprise Affirmation", isPresented: $showingSurprise, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                Text(store.surpriseAffirmation?.text ?? "You're amazing!")
            })
            */

            // MARK: Surprise Affirmation Section (Uncomment to show)
            //surpriseAffirmationView

            // (Content is handled above)
        
        .alert("Generation Failed", isPresented: $showGenerationError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(generationErrorMessage)
        })
    }

    @ViewBuilder
    private var generatorConfigSheet: some View {
        NavigationView {
            Form {
                Section(
                    footer: Text("Optional focus helps guide the vibe without forcing exact wording.")
                        .foregroundColor(appearance.theme.secondaryText)
                ) {
                    TextField("Focus (e.g. calm mornings)", text: $generationTheme)
                }

                Picker("Tone", selection: $selectedTone) {
                    ForEach(AffirmationGenerator.Tone.allCases) { tone in
                        Text(tone.label).tag(tone)
                    }
                }

                if fmAvailability.status != .available {
                    Label(fmAvailability.message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button(action: requestAIGeneration) {
                        if isGenerating {
                            HStack {
                                ProgressView()
                                Text("Generating…")
                            }
                        } else {
                            Label("Generate", systemImage: "sparkles")
                        }
                    }
                    .disabled(isGenerating)
                }
            }
            .navigationTitle("Apple Intelligence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { activeSheet = nil }
                }
            }
        }
        .tint(appearance.theme.accentColor)
    }

    @ViewBuilder
    private var generatedPreviewSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Generated Affirmation").foregroundColor(appearance.theme.secondaryText)) {
                    TextEditor(text: $generatedText)
                        .frame(minHeight: 120)

                    if let note = generationContextNote {
                        Label(note, systemImage: generationSource?.iconName ?? "info.circle")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    if !generationTheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label("Focus: \(generationTheme)", systemImage: "magnifyingglass")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Label("Tone: \(selectedTone.label)", systemImage: "waveform.path.ecg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button("Save") {
                        store.addUserAffirmation(
                            text: generatedText.trimmingCharacters(in: .whitespacesAndNewlines),
                            themes: generationThemesFromHint(),
                            isUserCreated: true,
                            isAIGenerated: true
                        )
                        activeSheet = nil
                    }

                    Button("Cancel", role: .cancel) {
                        activeSheet = nil
                    }
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(appearance.theme.accentColor)
    }

    @ViewBuilder
    private var aboutSheet: some View {
        NavigationView {
            List {
                Section(header: Text("About AffirmationApp").foregroundColor(appearance.theme.secondaryText)) {
                    Text("AffirmationApp keeps your favorite encouragement close by. Save personal entries, favorite built-ins, and ask Apple Intelligence to suggest fresh phrases when you need them.")
                        .font(.body)
                        .foregroundColor(.primary)
                }

                Section(header: Text("Using The Home Widget").foregroundColor(appearance.theme.secondaryText)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Long-press the Home Screen and tap the + button.")
                        Text("2. Search for AffirmationApp and choose either **Affirmation** (specific) or **Affirmation Shuffle**.")
                        Text("3. Tap the widget once it’s placed to pick the source, exact affirmation, and shuffle cadence. Colors and typography follow your appearance settings.")
                        Text("4. If things ever look stale, tap **Reload Widget Timelines** below.")
                    }
                    .font(.body)
                }

                Section(header: Text("Apple Intelligence Tips").foregroundColor(appearance.theme.secondaryText)) {
                    Text("Use the ✨ Generate button to draft new affirmations with Apple’s on-device models. You can set a focus, tone, and context note—generated entries land in **My Affirmations** so you can edit or favorite them later.")
                }

                Section(header: Text("Need A Refresh?").foregroundColor(appearance.theme.secondaryText)) {
                    Button {
                        #if !os(macOS)
                        WidgetCenter.shared.reloadAllTimelines()
                        #endif
                        activeSheet = nil
                    } label: {
                        Label("Reload Widget Timelines", systemImage: "arrow.clockwise")
                    }
                }
            }
            .navigationTitle("About & Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { activeSheet = nil }
                }
            }
        }
        .tint(appearance.theme.accentColor)
    }

    // NOTE: Currently unused; keep for potential future variety.
    /// Returns a font style for a tile based on its index.
    /// Not currently used, but could be used for further variety in tile text.
    func fontStyle(for index: Int) -> Font {
        let fonts: [Font] = [
            .custom("Georgia-Bold", size: 20),
            .custom("Courier-Bold", size: 20),
            .custom("Menlo-Bold", size: 20),
            .custom("Helvetica-Bold", size: 20),
            .custom("Futura-Bold", size: 20),
            .custom("Avenir-Heavy", size: 20),
            .custom("TimesNewRomanPS-BoldMT", size: 20),
            .custom("ChalkboardSE-Bold", size: 20)
        ]
        return fonts[index % fonts.count]
    }
    
    // NOTE: Currently unused; available for future layout tweaks.
    /// Returns an adaptive tile width based on the length of the affirmation text.
    /// Not currently used, but available for future layout tweaks.
    func tileWidth(for text: String) -> CGFloat {
        switch text.count {
        case 0..<60:
            return 150
        case 60..<120:
            return 250
        default:
            return 340
        }
    }
}

private extension MainAffirmationView {
    func requestAIGeneration() {
        guard !isGenerating else { return }
        isGenerating = true
        generationContextNote = nil

        Task {
            let result = await generator.generate(theme: generationTheme, tone: selectedTone)
            await MainActor.run {
                generatedText = result.text
                generationContextNote = result.metadata.note
                generationSource = result.source
                fmAvailability = generator.foundationModelAvailability()
                activeSheet = .generatedPreview
                isGenerating = false
            }
        }
    }

    func generationThemesFromHint() -> [String] {
        generationTheme
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    @ViewBuilder
    func controlButton(systemName: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline.weight(.semibold))
                .foregroundColor(appearance.theme.primaryText)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }
}

struct AffirmationView_Previews: PreviewProvider {
    static var previews: some View {
        AffirmationView(store: AffirmationStore())
            .environmentObject(AppearanceSettings())
    }
}

/// A deterministic random number generator seeded with an integer.
/// Used for picking the same "Affirmation of the Day" for a given day.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        self.state = UInt64(seed)
    }

    mutating func next() -> UInt64 {
        // Linear congruential generator for deterministic sequence.
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}

private extension AffirmationGenerator.Source {
    var iconName: String {
        switch self {
        case .foundationModel: return "sparkles"
        case .network: return "cloud"
        case .local: return "square.stack.3d.down.forward"
        }
    }
}
