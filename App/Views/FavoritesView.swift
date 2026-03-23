//
//  FavoritesView.swift
//  AffirmationApp
//
//  Created by Bethany Curtis on 4/9/25.
//
import SwiftUI
import AffirmationShared

/// A view that displays the user's favorite affirmations.
/// Includes the ability to pin an affirmation to a widget and unpin it.
/// Users can also remove affirmations from favorites.
struct FavoritesView: View {
    // Reference to the shared affirmation store that holds all affirmations and favorites
    @ObservedObject var store: AffirmationStore
    @EnvironmentObject private var appearance: AppearanceSettings

    var body: some View {
        ZStack {
            appearance.theme.gradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Layout.tilePadding) {
                    header

                    if store.favoriteAffirmations().isEmpty {
                        VStack(spacing: 16) {
                            DS.Icons.placeholderLeaf(size: 72, color: appearance.theme.accentColor)
                            Text("Favorite an affirmation to see it here")
                                .font(.body)
                                .foregroundColor(appearance.theme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .padding(DS.Layout.tilePadding)
                    } else {
                        let favorites = store.favoriteAffirmations()
                        LazyVGrid(columns: [GridItem(.flexible())], spacing: DS.Layout.tilePadding) {
                            ForEach(favorites) { affirmation in
                                FavoriteTileView(affirmation: affirmation, store: store)
                                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, DS.Layout.tilePadding)
                    }
                }
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Layout.tilePadding)
                .padding(.bottom, DS.Layout.tilePadding)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Favorites")
                .font(appearance.font.font(size: 32, weight: .bold))
            Text("Pinned encouragement at a glance.")
                .font(.footnote)
                .foregroundColor(appearance.theme.secondaryText)
        }
        .foregroundColor(appearance.theme.primaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Layout.tilePadding)
    }
    
    // Returns a font style based on the index for visual variety
    static func fontStyle(for index: Int) -> Font {
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
    static func tileColor(for index: Int) -> Color {
        // Use a single shared tile color (pale sage) for consistent look
        return SharedDS.Colors.card
    }
}


// MARK: - Favorite Tile Subview
private struct FavoriteTileView: View {
    let affirmation: Affirmation
    @ObservedObject var store: AffirmationStore

    // Centralized removal logic with animation
    private func removeFavorite() {
        withAnimation {
            store.toggleFavorite(for: affirmation)
        }
    }

    var body: some View {
        AffirmationTileView(
            affirmation: affirmation,
            isUserSubmitted: affirmation.isUserCreated,
            style: .compact
        ) {
            removeFavorite()
        }
    }
}
