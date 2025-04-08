import SwiftUI

struct AffirmationView: View {
    @ObservedObject var store: AffirmationStore
    @State private var showFavoritesOnly = false

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var filteredAffirmations: [Affirmation] {
        showFavoritesOnly ? store.favoriteAffirmations() : store.affirmations
    }

    var affirmationOfTheDay: Affirmation? {
        guard !store.affirmations.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let seed = (components.year ?? 0) * 100 + (components.month ?? 0)
        
        var generator = SeededGenerator(seed: seed)
        let shuffled = store.affirmations.shuffled(using: &generator)
        return shuffled.first
    }

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Spacer()

                    Toggle(isOn: $showFavoritesOnly.animation()) {
                        Label("Favorites Only", systemImage: "heart")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .pink))
                }
                .padding(.horizontal)

                ScrollView {
                    if let daily = affirmationOfTheDay {
                        VStack {
                            Text("Affirmation of the Day")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(daily.text)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding()
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)

                            HStack(spacing: 20) {
                                Button(action: {
                                    withAnimation {
                                        store.toggleFavorite(for: daily)
                                    }
                                }) {
                                    Image(systemName: daily.isFavorite ? "heart.fill" : "heart")
                                        .foregroundColor(daily.isFavorite ? .pink : .gray)
                                        .scaleEffect(daily.isFavorite ? 1.2 : 1.0)
                                        .animation(.easeInOut, value: daily.isFavorite)
                                }

                                ShareLink(item: daily.text) {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.bottom)
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

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredAffirmations) { affirmation in
                            VStack {
                                Text(affirmation.text)
                                    .font(.headline)
                                    .padding()
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)

                                Button(action: {
                                    withAnimation(.spring()) {
                                        store.toggleFavorite(for: affirmation)
                                    }
                                }) {
                                    Image(systemName: affirmation.isFavorite ? "heart.fill" : "heart")
                                        .foregroundColor(affirmation.isFavorite ? .pink : .gray)
                                        .scaleEffect(affirmation.isFavorite ? 1.2 : 1.0)
                                        .animation(.easeInOut, value: affirmation.isFavorite)
                                }
                                .padding(.bottom, 8)
                            }
                            .frame(minHeight: 150)
                            .background(LinearGradient(
                                gradient: Gradient(colors: [Color.white, Color(.systemGray6)]),
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .cornerRadius(20)
                            .shadow(radius: 4)
                            .padding(4)
                            .transition(.scale)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Affirmations")
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
