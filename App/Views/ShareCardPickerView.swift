import SwiftUI
import AffirmationShared

struct ShareCardPickerView: View {
    let favorites: [Affirmation]
    let personal: [Affirmation]
    let builtIn: [Affirmation]
    let onSelect: (Affirmation) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !favorites.isEmpty {
                    Section("Favorites") {
                        ForEach(favorites) { affirmation in
                            shareRow(for: affirmation)
                        }
                    }
                }

                if !personal.isEmpty {
                    Section("My Affirmations") {
                        ForEach(personal) { affirmation in
                            shareRow(for: affirmation)
                        }
                    }
                }

                if !builtIn.isEmpty {
                    Section("All Affirmations") {
                        ForEach(builtIn) { affirmation in
                            shareRow(for: affirmation)
                        }
                    }
                }
            }
            .navigationTitle("Share an Affirmation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func shareRow(for affirmation: Affirmation) -> some View {
        Button {
            onSelect(affirmation)
            dismiss()
        } label: {
            HStack {
                Text(affirmation.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}
