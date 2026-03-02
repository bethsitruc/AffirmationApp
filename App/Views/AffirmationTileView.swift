import SwiftUI
import AffirmationShared

struct AffirmationTileView: View {
    /// Tile style controls typography and spacing.
    enum TileStyle { case compact, featured, featuredToday }

    let affirmation: Affirmation
    let isUserSubmitted: Bool
    let style: TileStyle
    let action: () -> Void
    let shareAction: (() -> Void)?
    @EnvironmentObject private var appearance: AppearanceSettings

    init(
        affirmation: Affirmation,
        isUserSubmitted: Bool,
        style: TileStyle = .compact,
        action: @escaping () -> Void,
        shareAction: (() -> Void)? = nil
    ) {
        self.affirmation = affirmation
        self.isUserSubmitted = isUserSubmitted
        self.style = style
        self.action = action
        self.shareAction = shareAction
    }

    var body: some View {
        // Build the core content once to avoid duplicating text/button layout
        let core = VStack(alignment: .leading, spacing: 12) {
            if style == .featuredToday {
                // Top row: 'Today' on the left, heart on the right
                HStack(alignment: .top) {
                    Text("Today")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(theme.secondaryText)
                        .padding(.leading, 2)

                    Spacer()

                    Button(action: action) {
                        Image(systemName: affirmation.isFavorite ? "heart.fill" : "heart")
                            .font(.subheadline)
                            .imageScale(.medium)
                            .foregroundColor(affirmation.isFavorite ? accentColor : theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .contentShape(Circle())
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(affirmation.isFavorite ? "Remove Favorite" : "Add to Favorites")
                }

                // Main text - left aligned under the Today label
                Text(affirmation.text)
                    .font(titleFont(for: .featuredToday))
                    .foregroundColor(theme.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.95)
                    .lineLimit(nil)
                    .truncationMode(.tail)
            } else {
                Text(affirmation.text)
                    .font(titleFont(for: style))
                    .foregroundColor(theme.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(style == .featured ? 0.9 : 0.75)
                    .lineLimit(style == .featured ? nil : 4)
                    .truncationMode(.tail)

                // Top-right favorite button (kept subtle and accessible)
                HStack {
                    Spacer()

                    Button(action: action) {
                        Image(systemName: affirmation.isFavorite ? "heart.fill" : "heart")
                            .font(.subheadline)
                            .imageScale(.medium)
                            .foregroundColor(affirmation.isFavorite ? accentColor : theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .padding(8) // visual padding; expands tappable area
                    .contentShape(Circle())
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .accessibilityLabel(affirmation.isFavorite ? "Remove Favorite" : "Add to Favorites")
                    .accessibilityHint("Double tap to toggle favorite")
                    .accessibilityAddTraits(.isButton)
                }

                // Bottom row: keep 'User Submitted' small and quiet.
                    HStack {
                        if affirmation.isAIGenerated {
                            Label("Apple Intelligence", systemImage: "sparkles")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(accentColor)
                        } else if isUserSubmitted {
                            Label("My Affirmation", systemImage: "person.crop.circle.badge.plus")
                                .font(.footnote)
                                .foregroundColor(theme.secondaryText)
                        }
                        Spacer()
                    }
            }
        }

        // Apply separate visual treatments for the Today card vs. normal cards
        let base = Group {
            if style == .featuredToday {
                core
                    .padding(DS.Layout.featuredTilePadding + 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Layout.cornerRadius + 12, style: .continuous)
                            .fill(theme.gradient)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius + 12, style: .continuous)
                                    .stroke(theme.cardStroke, lineWidth: 1)
                            )
                    )
                    .shadow(color: theme.primaryText.opacity(0.18), radius: DS.Layout.tileShadowRadius + 8, x: 0, y: 8)
                    .padding(.horizontal, -DS.Layout.tilePadding)
            } else {
                core
                    .padding(style == .featured ? DS.Layout.featuredTilePadding : DS.Layout.compactTilePadding)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Layout.cornerRadius, style: .continuous)
                            .fill(theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius, style: .continuous)
                                    .stroke(theme.cardStroke, lineWidth: 1)
                            )
                    )
                    .shadow(color: theme.primaryText.opacity(0.08), radius: DS.Layout.tileShadowRadius, x: 0, y: 4)
            }
        }
        
        if let shareAction {
            base.contextMenu {
                Button(action: shareAction) {
                    Label("Share Card", systemImage: "square.and.arrow.up")
                }
            }
        } else {
            base
        }
    }
}

private extension AffirmationTileView {
    var theme: AffirmationColorTheme { appearance.theme }
    var accentColor: Color { theme.accentColor }

    func titleFont(for style: TileStyle) -> Font {
        switch style {
        case .featuredToday:
            return appearance.font.font(size: 30)
        case .featured:
            return appearance.font.font(size: 24)
        case .compact:
            return appearance.font.font(size: 20)
        }
    }
}

// Small helper to allow conditional modifier in above pipeline
struct AnyViewModifier: ViewModifier {
    func body(content: Content) -> some View { content }
}

#Preview {
    let sample = Affirmation(id: UUID(), text: "You are enough.", isFavorite: false, isUserCreated: false, themes: ["self-worth"])
    VStack(spacing: 16) {
        AffirmationTileView(affirmation: sample, isUserSubmitted: false, style: .featuredToday) {}
            .padding(DS.Layout.tilePadding)
        AffirmationTileView(affirmation: sample, isUserSubmitted: true, style: .compact) {}
            .padding(DS.Layout.tilePadding)
    }
    .environmentObject(AppearanceSettings())
}


#Preview {
    let sample = Affirmation(id: UUID(), text: "You are enough.", isFavorite: false, isUserCreated: false, themes: ["self-worth"])
    VStack(spacing: 16) {
        AffirmationTileView(affirmation: sample, isUserSubmitted: false, style: .featured) {}
            .padding(DS.Layout.tilePadding)
        AffirmationTileView(affirmation: sample, isUserSubmitted: true, style: .compact) {}
            .padding(DS.Layout.tilePadding)
    }
    .environmentObject(AppearanceSettings())
}
