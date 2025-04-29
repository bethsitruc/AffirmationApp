// MyAffirmationsView.swift
// View displaying user-submitted affirmations and allowing theme filtering and submission

import SwiftUI

// Main view for user-submitted affirmations
struct MyAffirmationsView: View {
    @ObservedObject var store: AffirmationStore
    @State private var showingSubmitView = false
    @State private var selectedTheme: String = "All"

    var body: some View {
        // Main navigation container
        NavigationStack {
            VStack {
                // Menu allowing filtering affirmations by theme
                Menu {
                    Picker("Theme", selection: $selectedTheme) {
                        Text("All").tag("All")
                        let themes = Set(store.userSubmittedAffirmations.flatMap { $0.themes.map { $0.capitalized } }).sorted()
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

                // Displays filtered user-submitted affirmations
                UserSubmittedSection(store: store, selectedTheme: $selectedTheme)

                // Button to add a new user affirmation
                Button(action: {
                    showingSubmitView = true
                }) {
                    Label("Submit Your Own Affirmation", systemImage: "plus.circle")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .padding(.bottom)
                .sheet(isPresented: $showingSubmitView) {
                    // Present submission view modally
                    SubmitAffirmationView()
                        .environmentObject(store)
                }
            }
            .navigationTitle("My Affirmations")
        }
    }
}

// Shows user-submitted affirmations in a scrollable, tile-style grid
private struct UserSubmittedSection: View {
    @ObservedObject var store: AffirmationStore
    @Binding var selectedTheme: String

    var body: some View {
        // Vertical scrolling container
        ScrollView {
            LazyVStack(spacing: 16) {
                // Filter affirmations based on selected theme and display each
                ForEach(store.userSubmittedAffirmations.filter { selectedTheme == "All" || $0.themes.contains { $0.caseInsensitiveCompare(selectedTheme) == .orderedSame } }) { affirmation in
                    Section {
                        // Tapping a tile navigates to the edit view
                        NavigationLink(destination: EditAffirmationView(affirmation: affirmation, store: store)) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(affirmation.text)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)

                                if affirmation.isFavorite {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.pink)
                                }

                                Label("User Submitted", systemImage: "person.crop.circle.badge.plus")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: 300)
                            .background(tileColor(for: affirmation))
                            .cornerRadius(20)
                            .shadow(radius: 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    // Generates a background color for tiles based on text hash
    func tileColor(for affirmation: Affirmation) -> Color {
        return Color(hue: Double(affirmation.text.hashValue % 360) / 360.0, saturation: 0.2, brightness: 1.0)
    }
}
