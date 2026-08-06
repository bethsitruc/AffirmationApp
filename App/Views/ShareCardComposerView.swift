import SwiftUI
import AffirmationShared
#if canImport(UIKit)
import UIKit
#endif

struct ShareCardComposerView: View {
    let affirmation: Affirmation

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @EnvironmentObject private var appearance: AppearanceSettings
    @State private var includeBadge: Bool = true
    @State private var sharePayload: SharePayload?
    @State private var shareError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    AffirmationShareCardView(
                        affirmation: affirmation,
                        theme: appearance.theme,
                        fontPreference: appearance.font,
                        includeBadge: includeBadge,
                        layout: .preview
                    )
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .frame(maxWidth: 720)
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
        .background(
            ActivityPresenter(payload: $sharePayload)
        )
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
        prepareShareItems()
    }

    private func prepareShareItems() {
        #if canImport(UIKit)
        let renderer = ImageRenderer(content:
            AffirmationShareCardView(
                affirmation: affirmation,
                theme: appearance.theme,
                fontPreference: appearance.font,
                includeBadge: includeBadge,
                layout: .export
            )
            .frame(width: 1200, height: 900)
        )
        // A scene can be resized independently of the physical display on iOS 27.
        // Use SwiftUI's scene-aware scale instead of the legacy main-screen API.
        renderer.scale = displayScale
        if let uiImage = renderer.uiImage {
            sharePayload = SharePayload(items: [uiImage])
        } else {
            shareError = "Could not render the card image."
        }
        #else
        shareError = "Sharing is only available on iOS."
        #endif
    }
}

private extension ShareCardComposerView {
    struct SharePayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }
}

struct AffirmationShareCardView: View {
    let affirmation: Affirmation
    let theme: AffirmationColorTheme
    let fontPreference: AffirmationFontPreference
    let includeBadge: Bool
    let layout: LayoutStyle

    var body: some View {
        ZStack {
            theme.gradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: layout.verticalSpacing) {
                if includeBadge {
                    Label {
                        Text("Grounded")
                    } icon: {
                        DS.Icons.badgeLeaf(size: layout.badgeIconSize, color: theme.accentColor)
                    }
                    .font(layout.badgeFont)
                    .foregroundStyle(theme.secondaryText)
                }

                Text(affirmation.text)
                    .font(fontPreference.font(size: layout.textSize, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .minimumScaleFactor(layout.minimumScaleFactor)
                    .lineSpacing(layout.lineSpacing)
                    .frame(maxHeight: .infinity, alignment: .center)

                HStack {
                    Spacer()
                    Text(Date.now, style: .date)
                        .font(layout.dateFont)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .padding(layout.padding)
        }
    }
}

extension AffirmationShareCardView {
    enum LayoutStyle {
        case preview
        case export

        var verticalSpacing: CGFloat {
            switch self {
            case .preview: 20
            case .export: 32
            }
        }

        var badgeIconSize: CGFloat {
            switch self {
            case .preview: 22
            case .export: 34
            }
        }

        var badgeFont: Font {
            switch self {
            case .preview: .headline
            case .export: .title3.weight(.semibold)
            }
        }

        var textSize: CGFloat {
            switch self {
            case .preview: 28
            case .export: 60
            }
        }

        var minimumScaleFactor: CGFloat {
            switch self {
            case .preview: 0.5
            case .export: 0.75
            }
        }

        var lineSpacing: CGFloat {
            switch self {
            case .preview: 6
            case .export: 10
            }
        }

        var dateFont: Font {
            switch self {
            case .preview: .footnote.weight(.semibold)
            case .export: .title3.weight(.semibold)
            }
        }

        var padding: CGFloat {
            switch self {
            case .preview: 32
            case .export: 64
            }
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
fileprivate struct ActivityPresenter: UIViewControllerRepresentable {
    @Binding var payload: ShareCardComposerView.SharePayload?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let payload, context.coordinator.presentedPayloadID != payload.id else {
            return
        }

        let activityController = UIActivityViewController(
            activityItems: payload.items,
            applicationActivities: nil
        )
        if let popover = activityController.popoverPresentationController {
            popover.sourceView = uiViewController.view
            popover.sourceRect = CGRect(
                x: uiViewController.view.bounds.midX,
                y: uiViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        activityController.completionWithItemsHandler = { _, _, _, _ in
            Task { @MainActor in
                context.coordinator.presentedPayloadID = nil
                self.payload = nil
            }
        }

        context.coordinator.presentedPayloadID = payload.id
        DispatchQueue.main.async {
            guard uiViewController.presentedViewController == nil else { return }
            uiViewController.present(activityController, animated: true)
        }
    }

    final class Coordinator {
        let parent: ActivityPresenter
        var presentedPayloadID: UUID?

        init(parent: ActivityPresenter) {
            self.parent = parent
        }
    }
}
#endif
