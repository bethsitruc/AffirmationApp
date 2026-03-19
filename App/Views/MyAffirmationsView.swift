// MyAffirmationsView.swift
// View displaying user-submitted affirmations and allowing theme filtering and submission

import SwiftUI
import AffirmationShared

// Main view for user-submitted affirmations
struct MyAffirmationsView: View {
    @ObservedObject var store: AffirmationStore
    @State private var showingSubmitView = false
    @EnvironmentObject private var appearance: AppearanceSettings

    // Generator used for quick surprise creation
    private let generator = AffirmationGenerator()
    @State private var isGenerating = false
    @State private var showGenerationError = false
    @State private var generationErrorMessage: String = ""

    var body: some View {
        ZStack {
            appearance.theme.gradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Layout.tilePadding) {
                    header

                    HStack(spacing: 12) {
                        Button(action: {
                            showingSubmitView = true
                        }) {
                            Label("Submit Your Own Affirmation", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .accessibilityIdentifier("submit-own-affirmation-button")
                        .buttonStyle(DS.PrimaryPillButtonStyle(prominent: true))
                    }
                    .padding(.horizontal, DS.Layout.tilePadding)

                    UserSubmittedSection(store: store)
                        .padding(.horizontal, DS.Layout.tilePadding)
                }
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Layout.tilePadding)
                .padding(.bottom, DS.Layout.tilePadding)
            }
        }
        .sheet(isPresented: $showingSubmitView) {
            SubmitAffirmationView()
                .environmentObject(store)
                .environmentObject(appearance)
        }
        .alert("Generation Failed", isPresented: $showGenerationError, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(generationErrorMessage)
        })
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("My Affirmations")
                .font(appearance.font.font(size: 32, weight: .bold))
            Text("Everything you’ve written or generated.")
                .font(.footnote)
                .foregroundColor(appearance.theme.secondaryText)
        }
        .foregroundColor(appearance.theme.primaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Layout.tilePadding)
    }
}

// Shows user-submitted affirmations in a scrollable, tile-style grid
private struct UserSubmittedSection: View {
    @ObservedObject var store: AffirmationStore
    @EnvironmentObject private var appearance: AppearanceSettings
    private let columns = [
        GridItem(.adaptive(minimum: 320, maximum: 420), spacing: DS.Layout.tilePadding)
    ]

    var body: some View {
        if store.userSubmittedAffirmations.isEmpty {
            VStack(spacing: 16) {
                DS.Icons.placeholderLeaf(size: 72, color: appearance.theme.accentColor)
                Text("Add your first personal affirmation.")
                    .font(.body.weight(.semibold))
                    .foregroundColor(appearance.theme.primaryText)
                Text("Use the button above or let Apple Intelligence draft one.")
                    .font(.footnote)
                    .foregroundColor(appearance.theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            if store.userSubmittedAffirmations.count == 1, let affirmation = store.userSubmittedAffirmations.first {
                affirmationCard(for: affirmation)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: DS.Layout.tilePadding) {
                    ForEach(store.userSubmittedAffirmations) { affirmation in
                        affirmationCard(for: affirmation)
                            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
                    }
                }
            }
        }
    }

    private func affirmationCard(for affirmation: Affirmation) -> some View {
        NavigationLink(destination: EditAffirmationView(affirmation: affirmation, store: store)) {
            VStack(alignment: .leading, spacing: 8) {
                Text(affirmation.text)
                    .font(appearance.font.font(size: 22))
                    .foregroundColor(appearance.theme.primaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                if affirmation.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundColor(appearance.theme.accentColor)
                }

                Label(
                    affirmation.isAIGenerated ? "Apple Intelligence" : "User Submitted",
                    systemImage: affirmation.isAIGenerated ? "sparkles" : "person.crop.circle.badge.plus"
                )
                .font(.footnote)
                .foregroundColor(affirmation.isAIGenerated ? appearance.theme.accentColor : appearance.theme.secondaryText)
            }
            .padding(DS.Layout.compactTilePadding)
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            .background(tileColor(for: affirmation))
            .cornerRadius(DS.Layout.cornerRadius)
            .shadow(color: appearance.theme.primaryText.opacity(0.08), radius: DS.Layout.tileShadowRadius, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // Generates a background color for tiles based on text hash
    func tileColor(for affirmation: Affirmation) -> Color {
        appearance.theme.cardBackground
    }
}
