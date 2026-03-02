import SwiftUI
import AffirmationShared
#if canImport(UIKit)
import UIKit
#endif

struct ShareCardComposerView: View {
    let affirmation: Affirmation

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appearance: AppearanceSettings
    @State private var includeBadge: Bool = true
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?
    @State private var shareError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    AffirmationShareCardView(
                        affirmation: affirmation,
                        theme: appearance.theme,
                        fontPreference: appearance.font,
                        includeBadge: includeBadge
                    )
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .padding(.horizontal)

                    Toggle("Show app badge", isOn: $includeBadge)
                        .tint(appearance.theme.accentColor)
                    .padding(.horizontal)

                    Button(action: renderAndShare) {
                        Label("Share Image", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appearance.theme.accentColor)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Share Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(appearance.theme.accentColor)
        .sheet(isPresented: $showingShareSheet) {
            if let image = shareImage {
                ActivityView(activityItems: [image])
            }
        }
        .alert("Unable to Share", isPresented: Binding(
            get: { shareError != nil },
            set: { if !$0 { shareError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(shareError ?? "Something went wrong while preparing the card.")
        }
    }

    private func renderAndShare() {
        #if canImport(UIKit)
        let renderer = ImageRenderer(content:
            AffirmationShareCardView(
                affirmation: affirmation,
                theme: appearance.theme,
                fontPreference: appearance.font,
                includeBadge: includeBadge
            )
            .frame(width: 1080, height: 1350)
        )
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            shareImage = uiImage
            showingShareSheet = true
        } else {
            shareError = "Could not render the card image."
        }
        #else
        shareError = "Sharing is only available on iOS."
        #endif
    }
}

struct AffirmationShareCardView: View {
    let affirmation: Affirmation
    let theme: AffirmationColorTheme
    let fontPreference: AffirmationFontPreference
    let includeBadge: Bool

    var body: some View {
        ZStack {
            theme.gradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                if includeBadge {
                    Label {
                        Text("AffirmationApp")
                    } icon: {
                        DS.Icons.badgeLeaf(size: 30, color: theme.accentColor)
                    }
                    .font(.headline)
                    .foregroundStyle(theme.secondaryText)
                }

                Text(affirmation.text)
                    .font(fontPreference.swiftUIFont)
                    .foregroundStyle(theme.primaryText)
                    .minimumScaleFactor(0.5)
                    .lineSpacing(6)

                Spacer()

                Text(Date.now, style: .date)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(48)
        }
    }
}

#if DEBUG
struct ShareCardComposerView_Previews: PreviewProvider {
    static var previews: some View {
        ShareCardComposerView(affirmation: Affirmation(id: UUID(), text: "You are enough.", isFavorite: false, isUserCreated: false, themes: []))
            .environmentObject(AppearanceSettings())
    }
}
#endif

#if canImport(UIKit)
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
