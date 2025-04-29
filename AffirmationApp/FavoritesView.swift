//
//  FavoritesView.swift
//  AffirmationApp
//
//  Created by Bethany Curtis on 4/9/25.
//
import SwiftUI
import WidgetKit

/// A view that displays the user's favorite affirmations.
/// Includes the ability to pin an affirmation to a widget and unpin it.
/// Users can also remove affirmations from favorites.
struct FavoritesView: View {
    // Reference to the shared affirmation store that holds all affirmations and favorites
    @ObservedObject var store: AffirmationStore

    var body: some View {
        // Main layout container for the Favorites screen
        VStack {
            // Title of the Favorites section
            Text("Your Favorite Affirmations")
                .font(.headline)
                .padding()

            // Scrollable area for either empty state or the list of favorite affirmations
            ScrollView {
                // Show empty state if no affirmations are favorited
                if store.favoriteAffirmations().isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "heart.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Favorite an affirmation to see it here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding()
                } else {
                    // Grid layout to display each favorite affirmation in a styled tile
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                        ForEach(store.favoriteAffirmations(), id: \.id) { affirmation in
                            // Determine if the current affirmation is the one pinned to the widget
                            let isPinned = UserDefaults(suiteName: "group.bethsitruc.affirmationapp")?.string(forKey: "selected_widget_affirmation") == affirmation.text

                            VStack {
                                Text(affirmation.text)
                                    .font(fontStyle(for: store.affirmations.firstIndex(of: affirmation) ?? 0))
                                    .fontWeight(.semibold)
                                    .padding()
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)

                                // Handle pinning or unpinning the affirmation to the home screen widget
                                if !isPinned {
                                    Button(action: {
                                        let affirmationText = affirmation.text
                                        UserDefaults(suiteName: "group.bethsitruc.affirmationapp")?.set(affirmationText, forKey: "selected_widget_affirmation")
                                        WidgetCenter.shared.reloadAllTimelines()
                                    }) {
                                        Label("Pin to Widget", systemImage: "pin")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.bottom, 4)
                                } else {
                                    Button(action: {
                                        UserDefaults(suiteName: "group.bethsitruc.affirmationapp")?.removeObject(forKey: "selected_widget_affirmation")
                                        WidgetCenter.shared.reloadAllTimelines()
                                    }) {
                                        Label("Unpin from Widget", systemImage: "pin.slash")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.bottom, 4)
                                }

                                // Handle unfavoriting the affirmation
                                Button(action: {
                                    withAnimation {
                                        store.toggleFavorite(for: affirmation)
                                    }
                                }) {
                                    Label("Remove Favorite", systemImage: "heart.slash")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            // Style the tile with color and pin highlight
                            .frame(height: 180)
                            .background(tileColor(for: store.affirmations.firstIndex(of: affirmation) ?? 0))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(isPinned ? Color.blue : Color.clear, lineWidth: 3)
                            )
                            .cornerRadius(20)
                            .shadow(radius: 4)
                            .padding(4)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Favorites")
    }
    
    // Returns a font style based on the index for visual variety
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
    
    // Returns a background color for the tile based on the index
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
}
