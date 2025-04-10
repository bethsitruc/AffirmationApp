import SwiftUI
import WidgetKit

struct AffirmationView: View {
    @ObservedObject var store: AffirmationStore
    @State private var displayedCount = 6
    
    var body: some View {
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
        }
    }
}

struct MainAffirmationView: View {
    @ObservedObject var store: AffirmationStore
    @Binding var displayedCount: Int
    @State private var selectedTheme: String = "All"
    //@State private var showingSurprise = false

    let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]
    
    var affirmationOfTheDay: Affirmation? {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: Date())
        var generator = SeededGenerator(seed: day)
        return store.affirmations.randomElement(using: &generator)
    }
    
    var surpriseAffirmationView: some View {
        Group {
            if let surprise = store.surpriseAffirmation {
                VStack {
                    Text("🎉 Surprise Affirmation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(surprise.text)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding()
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

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
    
    var affirmationOfTheDayView: some View {
        Group {
            if let dailyAffirmation = affirmationOfTheDay {
                VStack {
                    Text("Affirmation of the Day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(dailyAffirmation.text)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding()
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

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
    
    var filteredAffirmations: [Affirmation] {
        if selectedTheme == "All" {
            return store.affirmations
        } else {
            return store.affirmations.filter { $0.themes.contains { $0.localizedCaseInsensitiveCompare(selectedTheme) == .orderedSame } }
        }
    }
    
    var affirmationRows: some View {
        let affirmations = Array(filteredAffirmations.shuffled().prefix(displayedCount))
        var index = 0
        var rows: [AnyView] = []

        while index < affirmations.count {
            let item = affirmations[index]

            if item.text.count >= 60 {
                let view = AnyView(
                    VStack {
                        Text(item.text)
                            .font(fontStyle(for: store.affirmations.firstIndex(of: item) ?? 0))
                            .fontWeight(.semibold)
                            .padding()
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

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
                    .background(tileColor(for: store.affirmations.firstIndex(of: item) ?? 0))
                    .cornerRadius(20)
                    .shadow(radius: 4)
                    .padding(.horizontal)
                    .onAppear {
                        if item == affirmations.last {
                            displayedCount += 6
                        }
                    }
                )
                rows.append(view)
                index += 1
            } else {
                _ = affirmations.count - index
                let pair = affirmations[index..<min(index + 2, affirmations.count)].filter { $0.text.count < 60 }

                if pair.count == 2 {
                    let view = AnyView(
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(pair, id: \.id) { affirmation in
                                VStack {
                                    Text(affirmation.text)
                                        .font(fontStyle(for: store.affirmations.firstIndex(of: affirmation) ?? 0))
                                        .fontWeight(.semibold)
                                        .padding()
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)

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
                    // Render the last single short tile as a full-width item
                    if let single = pair.first {
                        let view = AnyView(
                            VStack {
                                Text(single.text)
                                    .font(fontStyle(for: store.affirmations.firstIndex(of: single) ?? 0))
                                    .fontWeight(.semibold)
                                    .padding()
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)

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

        return VStack(spacing: 20) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, rowView in
                rowView
            }
        }
        .padding()
    }
    
    var body: some View {
        VStack {
            // Theme Picker
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

            // Surprise Me Button
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

            // Show Surprise Affirmation
            //surpriseAffirmationView
            
            // Show Affirmation of the Day
            affirmationOfTheDayView

            ScrollView {
                affirmationRows
            }
        }
    }
    
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

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        self.state = UInt64(seed)
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}
