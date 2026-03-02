// DesignSystem.swift
// Centralized palette, typography, and a simple card style.
// Keep this boring and obvious so the rest of the app stays clean.

import SwiftUI
import AffirmationShared
#if canImport(UIKit)
import UIKit
#endif

enum DS {
    enum Icons {
        static func leafTemplate() -> Image {
            Image("SageLeaf").renderingMode(.template)
        }

        static func leafOriginal() -> Image {
            Image("SageLeaf").renderingMode(.original)
        }

        static func tabLeaf() -> Image {
#if canImport(UIKit)
            if let glyph = LeafIconCache.shared.tabGlyph {
                return Image(uiImage: glyph)
            }
#endif
            return leafTemplate()
        }

        static func badgeLeaf(size: CGFloat = 20, color: Color? = nil) -> some View {
            LeafSymbol(size: size, color: color, padded: false)
        }

        static func placeholderLeaf(size: CGFloat = 54, color: Color? = nil) -> some View {
            LeafSymbol(size: size, color: color, padded: true)
        }

        struct LeafSymbol: View {
            var size: CGFloat
            var color: Color? = nil
            var padded: Bool = true

            private var inset: CGFloat {
                padded ? max(size * 0.18, 4) : 0
            }

            var body: some View {
                Image("SageLeaf")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .padding(inset)
                    .frame(width: size, height: size)
                    .modifier(OptionalTint(color: color))
                    .accessibilityHidden(true)
            }
        }

        private struct OptionalTint: ViewModifier {
            let color: Color?
            func body(content: Content) -> some View {
                if let color {
                    content.foregroundStyle(color)
                } else {
                    content
                }
            }
        }
    }

    enum Colors {
        // Forward to shared tokens
        static var bg: Color { SharedDS.Colors.bg }
        static var card: Color { SharedDS.Colors.card }
        static var text: Color { SharedDS.Colors.text }
        static var stroke: Color { SharedDS.Colors.stroke }
    }

    enum Layout {
        // Forward to shared tokens
        static var cornerRadius: CGFloat { SharedDS.Layout.cornerRadius }
        static var tilePadding: CGFloat { SharedDS.Layout.tilePadding }
        static var compactTilePadding: CGFloat { SharedDS.Layout.compactTilePadding }
        static var featuredTilePadding: CGFloat { SharedDS.Layout.featuredTilePadding }
        static var tileShadowColor: Color { SharedDS.Layout.tileShadowColor }
        static var tileShadowRadius: CGFloat { SharedDS.Layout.tileShadowRadius }
        static var buttonMinHeight: CGFloat { SharedDS.Layout.buttonMinHeight }
    }

    enum Fonts {
        // Forward to shared fonts
        static func title() -> Font { SharedDS.Fonts.title() }
        static func compactTitle() -> Font { SharedDS.Fonts.compactTitle() }
        static func body()  -> Font { SharedDS.Fonts.body() }
        static func note()  -> Font { SharedDS.Fonts.note() }
    }

    struct Card: ViewModifier {
        func body(content: Content) -> some View {
            content
                .background(Colors.card)
                .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                        .strokeBorder(Colors.stroke, lineWidth: 1)
                )
                .shadow(color: Layout.tileShadowColor, radius: Layout.tileShadowRadius, x: 0, y: 4)
        }
    }

    struct PrimaryPillButtonStyle: ButtonStyle {
        var prominent: Bool = true
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline)
                .foregroundColor(prominent ? Color.white : Color.accentColor)
                .padding(.vertical, SharedDS.Layout.buttonVerticalPadding)
                .padding(.horizontal, SharedDS.Layout.buttonHorizontalPadding)
                .frame(minHeight: SharedDS.Layout.buttonMinHeight)
                .background(prominent ? Color.accentColor : Color(UIColor.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
        }
    }

    struct SecondaryPillButtonStyle: ButtonStyle {
        var destructive: Bool = false
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.subheadline)
                .foregroundColor(destructive ? Color.red : Color.accentColor)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .frame(minHeight: Layout.buttonMinHeight - 8)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                        .stroke(destructive ? Color.red.opacity(0.18) : Color.accentColor.opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
        }
    }
}

extension View {
    func dsCard() -> some View { modifier(DS.Card()) }
}

#if canImport(UIKit)
private final class LeafIconCache {
    static let shared = LeafIconCache()
    private init() {}

    lazy var tabGlyph: UIImage? = {
        guard let base = UIImage(named: "SageLeaf") else { return nil }
        return base.symbolIcon(of: CGSize(width: 40, height: 40), inset: 2)
    }()
}

private extension UIImage {
    func symbolIcon(of size: CGSize, inset: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let fitRect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let aspect = min(fitRect.width / self.size.width, fitRect.height / self.size.height)
            let drawSize = CGSize(width: self.size.width * aspect, height: self.size.height * aspect)
            let origin = CGPoint(
                x: fitRect.midX - drawSize.width / 2,
                y: fitRect.midY - drawSize.height / 2
            )
            self.draw(in: CGRect(origin: origin, size: drawSize))
        }.withRenderingMode(.alwaysTemplate)
    }
}
#endif
