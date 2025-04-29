//
//  EditAffirmationView.swift
//  AffirmationApp
//
//  Created by Bethany Curtis on 4/21/25.
//
// This view allows users to edit or delete an existing user-submitted affirmation.

import SwiftUI

/// A view for editing and deleting a user-submitted affirmation.
struct EditAffirmationView: View {
    /// The original affirmation passed into the view.
    var affirmation: Affirmation
    /// A copy of the affirmation being edited, tracked as state.
    @State private var editedAffirmation: Affirmation
    /// Reference to the shared affirmation store.
    @ObservedObject var store: AffirmationStore
    /// Environment property to allow dismissing the view.
    @Environment(\.dismiss) var dismiss
    /// State variable to control the display of the delete confirmation alert.
    @State private var showingDeleteConfirmation = false
    /// State variable to trigger an alert if the affirmation is not found in the store.
    @State private var showNotFoundAlert = false

    /// Initializes the view with a given affirmation and store.
    init(affirmation: Affirmation, store: AffirmationStore) {
        self.affirmation = affirmation
        self._editedAffirmation = State(initialValue: affirmation)
        self.store = store
    }

    var body: some View {
        // Main form containing editable affirmation fields and actions.
        Form {
            // Section for editing the affirmation's text.
            Section(header: Text("Edit Affirmation")) {
                TextEditor(text: $editedAffirmation.text)
                    .frame(minHeight: 100)
            }

            // Section to select and toggle affirmation themes.
            Section(header: Text("Themes")) {
                let availableThemes = ["self-worth", "confidence", "resilience", "growth", "kindness", "optimism", "motivation"]
                ForEach(availableThemes, id: \.self) { theme in
                    let isSelected = editedAffirmation.themes.contains(theme)
                    Button(action: {
                        if isSelected {
                            editedAffirmation.themes.removeAll { $0 == theme }
                        } else {
                            editedAffirmation.themes.append(theme)
                        }
                    }) {
                        HStack {
                            Text(theme.capitalized)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            
            // Section to save the updated affirmation.
            Section {
                Button("Save Changes") {
                    store.update(editedAffirmation)
                    dismiss()
                }
                .disabled(editedAffirmation.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // Section to delete the affirmation, with confirmation.
            Section {
                Button("Delete Affirmation", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .alert("Are you sure you want to delete this affirmation?", isPresented: $showingDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        if store.userSubmittedAffirmations.contains(where: { $0.id == affirmation.id }) {
                            store.deleteUserAffirmation(affirmation)
                            dismiss()
                        } else {
                            showNotFoundAlert = true
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This action cannot be undone.")
                }
            }
        }
        .navigationTitle("Edit Affirmation")
        .navigationBarTitleDisplayMode(.inline)
        // Alert shown when the affirmation to delete is not found in the store.
        .alert("Affirmation not found", isPresented: $showNotFoundAlert) {
            Button("OK", role: .cancel) {}
        }
    }
}
