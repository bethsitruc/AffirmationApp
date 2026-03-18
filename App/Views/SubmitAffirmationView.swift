//
// This file defines the view where users can submit a new custom affirmation.
// It includes a text editor for input and multiple selection for themes.
//

import SwiftUI
import AffirmationShared

/// A view that allows users to submit a new affirmation with selected themes.
struct SubmitAffirmationView: View {
    @EnvironmentObject var store: AffirmationStore
    @EnvironmentObject private var appearance: AppearanceSettings
    @Environment(\.dismiss) var dismiss
    
    @State private var text: String = ""
    @State private var showAlert = false

    private let generator = AffirmationGenerator()
    @State private var selectedTone: AffirmationGenerator.Tone = .calm
    @State private var thematicHint: String = ""
    @State private var fmAvailability = FoundationModelAvailability(status: .missingFramework, message: "Checking availability…")
    @State private var isGenerating = false
    @State private var generationNote: String?

    var body: some View {
        // Main layout inside a navigation view
        NavigationView {
            Form {
                Section(header: Text("Need inspiration?").foregroundColor(appearance.theme.secondaryText)) {
                    TextField("Optional theme or prompt (e.g., \"calm mornings\")", text: $thematicHint)

                    Picker("Tone", selection: $selectedTone) {
                        ForEach(AffirmationGenerator.Tone.allCases) { tone in
                            Text(tone.label).tag(tone)
                        }
                    }

                    Button(action: triggerGeneration) {
                        Label(isGenerating ? "Generating…" : "Ask Apple Intelligence", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isGenerating)
                    .buttonStyle(DS.PrimaryPillButtonStyle(prominent: false))

                    if isGenerating {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Writing a \(selectedTone.label.lowercased()) affirmation…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let note = generationNote {
                        Label(note, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if fmAvailability.status != .available {
                        Label(fmAvailability.message, systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Section for user to input affirmation text
                Section(header: Text("Your Affirmation").foregroundColor(appearance.theme.secondaryText)) {
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                        .accessibilityIdentifier("submit-affirmation-editor")
                }

                // Button to submit the new affirmation
                Button(action: {
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        showAlert = true
                    } else {
                        store.addUserAffirmation(text: text.trimmingCharacters(in: .whitespacesAndNewlines), themes: [], isUserCreated: true)
                        dismiss()
                    }
                }) {
                    Text("Submit Affirmation")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .accessibilityIdentifier("submit-affirmation-confirm-button")
                .buttonStyle(DS.PrimaryPillButtonStyle(prominent: true))
            }
            .navigationTitle("Submit Affirmation")
            .task {
                fmAvailability = generator.foundationModelAvailability()
            }
            // Show an alert if the form is incomplete
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Missing Information"), message: Text("Please enter text."), dismissButton: .default(Text("OK")))
            }
        }
        .tint(appearance.theme.accentColor)
    }
}

private extension SubmitAffirmationView {
    func triggerGeneration() {
        guard !isGenerating else { return }
        isGenerating = true
        generationNote = nil

        Task {
            let result = await generator.generate(theme: thematicHint, tone: selectedTone)
            await MainActor.run {
                text = result.text
                generationNote = result.metadata.note
                fmAvailability = generator.foundationModelAvailability()
                isGenerating = false
            }
        }
    }
}


/// Preview provider to preview the SubmitAffirmationView during development.
struct SubmitAffirmationView_Previews: PreviewProvider {
    static var previews: some View {
        SubmitAffirmationView()
            .environmentObject(AffirmationStore())
            .environmentObject(AppearanceSettings())
    }
}
