import SwiftUI

struct ContentView: View {
    @StateObject var store = AffirmationStore()

    var body: some View {
        NavigationView {
            List {
                ForEach(store.affirmations) { affirmation in
                    HStack {
                        Text(affirmation.text)
                        Spacer()
                        Button(action: {
                            store.toggleFavorite(for: affirmation)
                        }) {
                            Image(systemName: affirmation.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(.pink)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Affirmations")
        }
    }
}