//
// This file defines the view where users can submit a new custom affirmation.
// It includes a text editor for input and multiple selection for themes.
//

import SwiftUI

/// A view that allows users to submit a new affirmation with selected themes.
struct SubmitAffirmationView: View {
    @EnvironmentObject var store: AffirmationStore
    @Environment(\.dismiss) var dismiss
    
    @State private var text: String = ""
    @State private var selectedThemes: Set<String> = []
    @State private var showAlert = false

    private let availableThemes = ["self-worth", "confidence", "resilience", "growth", "kindness", "optimism", "motivation"]

    var body: some View {
        // Main layout inside a navigation view
        NavigationView {
            Form {
                // Section for user to input affirmation text
                Section(header: Text("Your Affirmation")) {
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                }

                // Section for user to select one or more themes
                Section(header: Text("Select Themes")) {
                    ForEach(availableThemes, id: \.self) { theme in
                        MultipleSelectionRow(title: theme, isSelected: selectedThemes.contains(theme)) {
                            if selectedThemes.contains(theme) {
                                selectedThemes.remove(theme)
                            } else {
                                selectedThemes.insert(theme)
                            }
                        }
                    }
                }

                // Button to submit the new affirmation
                Button(action: {
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedThemes.isEmpty {
                        showAlert = true
                    } else {
                        store.addUserAffirmation(text: text, themes: Array(selectedThemes), isUserCreated: true)
                        dismiss()
                    }
                }) {
                    Text("Submit Affirmation")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Submit Affirmation")
            // Show an alert if the form is incomplete
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Missing Information"), message: Text("Please enter text and select at least one theme."), dismissButton: .default(Text("OK")))
            }
        }
    }
}

/// A reusable view representing a selectable row with a checkmark when selected.
struct MultipleSelectionRow: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        // Layout for a row showing the theme and a checkmark if selected
        Button(action: self.action) {
            HStack {
                Text(self.title)
                if self.isSelected {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}

/// Preview provider to preview the SubmitAffirmationView during development.
struct SubmitAffirmationView_Previews: PreviewProvider {
    static var previews: some View {
        SubmitAffirmationView().environmentObject(AffirmationStore())
    }
}
