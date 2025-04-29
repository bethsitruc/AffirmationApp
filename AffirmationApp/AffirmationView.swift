import SwiftUI
import WidgetKit

struct AffirmationView: View {
    @ObservedObject var store: AffirmationStore
    @State private var displayedCount = 6
    
    var body: some View {
        // MARK: - Main Application Tab View
        // This `TabView` provides the main navigation between the three sections of the app:
        // 1. Home: MainAffirmationView showing themed, daily, and surprise affirmations.
        // 2. Favorites: View of user-favorited affirmations.
        // 3. My Affirmations: View for user-submitted affirmations (editable).
        TabView {
            NavigationStack {
                MainAffirmationView(store: store, displayedCount: $displayedCount)
                    .navigationTitle("Affirmations")
            }
            .tabItem {
                Label("Home", systemImage: "sparkles")
            }

            NavigationStack {
                FavoritesView(store: store)
            }
            .tabItem {
                Label("Favorites", systemImage: "heart.fill")
            }

            NavigationStack {
                MyAffirmationsView(store: store)
            }
            .tabItem {
                Label("My Affirmations", systemImage: "person.crop.circle.badge.plus")
            }
        }
    }
}

/// The main content view for the Home tab, showing themed, daily, and surprise affirmations.
/// This view contains:
///   - A theme picker for filtering affirmations by theme.
///   - (Optional) A "Surprise Me" affirmation section.
///   - The "Affirmation of the Day" (deterministic per day).
///   - A scrollable, adaptive grid/list of affirmation tiles.
struct MainAffirmationView: View {
    @ObservedObject var store: AffirmationStore
    @Binding var displayedCount: Int
    @State private var selectedTheme: String = "All"
    //@State private var showingSurprise = false

    // Defines the adaptive grid column layout for short affirmations.
    let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
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
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(surprise.text)
                        .font(.system(size: surprise.text.count > 100 ? 14 : 20, weight: .semibold))
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
                            .foregroundColor(surprise.isFavorite ? .pink : .gray)
                            .scaleEffect(surprise.isFavorite ? 1.2 : 1.0)
                            .animation(.easeInOut, value: surprise.isFavorite)
                    }
                    .padding(.bottom, 8)
                }
                .padding()
                .background(LinearGradient(
                    gradient: Gradient(colors: [Color.orange.opacity(0.5), Color.yellow.opacity(0.4)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .cornerRadius(20)
                .shadow(radius: 5)
                .padding(.horizontal)
            }
        }
    }
    
    /// View for displaying the "Affirmation of the Day".
    /// Uses a consistent gradient background and allows favoriting.
    var affirmationOfTheDayView: some View {
        Group {
            if let dailyAffirmation = affirmationOfTheDay {
                VStack {
                    Text("Affirmation of the Day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(dailyAffirmation.text)
                        .font(.system(size: dailyAffirmation.text.count > 100 ? 14 : 20, weight: .semibold))
                        .padding()
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .lineLimit(6)
                        .truncationMode(.tail)

                    // Animated favorite button.
                    Button(action: {
                        withAnimation {
                            store.toggleFavorite(for: dailyAffirmation)
                        }
                    }) {
                        Image(systemName: dailyAffirmation.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(dailyAffirmation.isFavorite ? .pink : .gray)
                            .scaleEffect(dailyAffirmation.isFavorite ? 1.2 : 1.0)
                            .animation(.easeInOut, value: dailyAffirmation.isFavorite)
                    }
                    .padding(.bottom, 8)
                }
                .padding()
                .background(LinearGradient(
                    gradient: Gradient(colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.4)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .cornerRadius(20)
                .shadow(radius: 5)
                .padding()
            }
        }
    }
    
    /// Returns affirmations filtered by the selected theme.
    /// If "All" is selected, returns all affirmations.
    var filteredAffirmations: [Affirmation] {
        if selectedTheme == "All" {
            return store.affirmations
        } else {
            // Case-insensitive theme matching.
            return store.affirmations.filter { $0.themes.contains { $0.localizedCaseInsensitiveCompare(selectedTheme) == .orderedSame } }
        }
    }
    
    /// Provides the main scrollable content of affirmation tiles.
    /// - Tiles are adaptively displayed: long affirmations take a full row, short ones are paired in a grid.
    /// - User-submitted affirmations are labeled.
    /// - Each tile includes an animated favorite button.
    /// - Infinite scroll: loading more tiles as the user scrolls.
    var affirmationRows: some View {
        // Shuffle and take a slice for display.
        let affirmations = Array(filteredAffirmations.shuffled().prefix(displayedCount))
        var index = 0
        var rows: [AnyView] = []

        while index < affirmations.count {
            let item = affirmations[index]

            // Long affirmation: single full-width tile.
            if item.text.count >= 50 {
                let view = AnyView(
                    VStack {
                        // Show label if user-submitted.
                        if store.userSubmittedAffirmations.contains(where: { $0.id == item.id }) {
                            Label("User Submitted", systemImage: "person.crop.circle.badge.plus")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(item.text)
                            .font(.system(size: item.text.count > 100 ? 14 : 20, weight: .semibold))
                            .padding()
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .lineLimit(6)
                            .truncationMode(.tail)

                        // Animated favorite button.
                        Button(action: {
                            withAnimation {
                                store.toggleFavorite(for: item)
                            }
                        }) {
                            Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(item.isFavorite ? .pink : .gray)
                                .scaleEffect(item.isFavorite ? 1.2 : 1.0)
                                .animation(.easeInOut, value: item.isFavorite)
                        }
                        .padding(.top, 5)
                        .padding(.bottom, 8)
                    }
                    .frame(height: 180)
                    // Tile color is based on the global index for variety.
                    .background(tileColor(for: store.affirmations.firstIndex(of: item) ?? 0))
                    .cornerRadius(20)
                    .shadow(radius: 4)
                    .padding(.horizontal)
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
                                VStack {
                                    if store.userSubmittedAffirmations.contains(where: { $0.id == affirmation.id }) {
                                        Label("User Submitted", systemImage: "person.crop.circle.badge.plus")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Text(affirmation.text)
                                        .font(.system(size: affirmation.text.count > 100 ? 14 : 20, weight: .semibold))
                                        .padding()
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .lineLimit(6)
                                        .truncationMode(.tail)

                                    Button(action: {
                                        withAnimation {
                                            store.toggleFavorite(for: affirmation)
                                        }
                                    }) {
                                        Image(systemName: affirmation.isFavorite ? "heart.fill" : "heart")
                                            .foregroundColor(affirmation.isFavorite ? .pink : .gray)
                                            .scaleEffect(affirmation.isFavorite ? 1.2 : 1.0)
                                            .animation(.easeInOut, value: affirmation.isFavorite)
                                    }
                                    .padding(.top, 5)
                                    .padding(.bottom, 8)
                                }
                                .frame(height: 180)
                                .background(tileColor(for: store.affirmations.firstIndex(of: affirmation) ?? 0))
                                .cornerRadius(20)
                                .shadow(radius: 4)
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
                            VStack {
                                if store.userSubmittedAffirmations.contains(where: { $0.id == single.id }) {
                                    Label("User Submitted", systemImage: "person.crop.circle.badge.plus")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Text(single.text)
                                    .font(.system(size: single.text.count > 100 ? 14 : 20, weight: .semibold))
                                    .padding()
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .lineLimit(6)
                                    .truncationMode(.tail)

                                Button(action: {
                                    withAnimation {
                                        store.toggleFavorite(for: single)
                                    }
                                }) {
                                    Image(systemName: single.isFavorite ? "heart.fill" : "heart")
                                        .foregroundColor(single.isFavorite ? .pink : .gray)
                                        .scaleEffect(single.isFavorite ? 1.2 : 1.0)
                                        .animation(.easeInOut, value: single.isFavorite)
                                }
                                .padding(.top, 5)
                                .padding(.bottom, 8)
                            }
                            .frame(height: 180)
                            .background(tileColor(for: store.affirmations.firstIndex(of: single) ?? 0))
                            .cornerRadius(20)
                            .shadow(radius: 4)
                            .padding(.horizontal)
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
        return VStack(spacing: 20) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, rowView in
                rowView
            }
        }
        .padding()
    }
    
    var body: some View {
        VStack {
            // MARK: Theme Picker
            // Allows the user to select a theme to filter affirmations.
            Menu {
                Picker("Theme", selection: $selectedTheme) {
                    Text("All").tag("All")
                    let themes = Set(store.affirmations.flatMap { $0.themes.map { $0.capitalized } }).sorted()
                    ForEach(themes, id: \.self) { theme in
                        Text(theme).tag(theme)
                    }
                }
            } label: {
                HStack {
                    Label("Theme: \(selectedTheme)", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            // MARK: Surprise Me Button (Optional)
            /*
            Button(action: {
                store.generateSurpriseAffirmation()
                showingSurprise = true
            }) {
                Label("Surprise Me!", systemImage: "sparkles")
                    .font(.headline)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
            .alert("🌟 Surprise Affirmation", isPresented: $showingSurprise, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                Text(store.surpriseAffirmation?.text ?? "You're amazing!")
            })
            */

            // MARK: Surprise Affirmation Section (Uncomment to show)
            //surpriseAffirmationView
            
            // MARK: Affirmation of the Day Section
            affirmationOfTheDayView

            // MARK: Affirmation Tiles
            // Shows a scrollable list/grid of affirmations, with infinite scroll.
            ScrollView {
                affirmationRows
            }
            .padding(.bottom, 16)
        }
    }
    
    /// Returns a background color for a tile based on its index.
    /// Cycles through several pastel colors for visual variety.
    func tileColor(for index: Int) -> Color {
        let colors: [Color] = [
            .blue.opacity(0.2),
            .green.opacity(0.2),
            .orange.opacity(0.2),
            .purple.opacity(0.2),
            .yellow.opacity(0.2),
            .pink.opacity(0.2)
        ]
        return colors[index % colors.count]
    }

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

struct AffirmationView_Previews: PreviewProvider {
    static var previews: some View {
        AffirmationView(store: AffirmationStore())
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
