//
//  FavoritesView.swift
//  AffirmationApp
//
//  Created by Bethany Curtis on 4/9/25.
//
import SwiftUI
import WidgetKit

struct FavoritesView: View {
    @ObservedObject var store: AffirmationStore

    var body: some View {
        VStack {
            Text("Your Favorite Affirmations")
                .font(.headline)
                .padding()

            ScrollView {
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
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                        ForEach(store.favoriteAffirmations(), id: \.id) { affirmation in
                            let isPinned = UserDefaults(suiteName: "group.bethsitruc.affirmationapp")?.string(forKey: "selected_widget_affirmation") == affirmation.text

                            VStack {
                                Text(affirmation.text)
                                    .font(fontStyle(for: store.affirmations.firstIndex(of: affirmation) ?? 0))
                                    .fontWeight(.semibold)
                                    .padding()
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)

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
