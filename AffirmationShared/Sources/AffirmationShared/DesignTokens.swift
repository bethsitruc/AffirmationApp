import SwiftUI

/// Shared design tokens for both app and widget. Keep these minimal and cross-platform.
public enum SharedDS {
    public enum Colors {
        // System-aware background/card colors (single pale sage tile color)
        #if canImport(UIKit)
        public static let bg = Color(UIColor.systemBackground)
        public static var card: Color {
            Color(UIColor { tc in
                // Pale sage in light mode, slightly deeper sage in dark mode for contrast
                if tc.userInterfaceStyle == .dark {
                    return UIColor(red: 28/255, green: 40/255, blue: 36/255, alpha: 1.0)
                } else {
                    return UIColor(red: 231/255, green: 241/255, blue: 232/255, alpha: 1.0)
                }
            })
        }
        #elseif canImport(AppKit)
        public static let bg = Color(NSColor.windowBackgroundColor)
        public static let card = Color(NSColor(calibratedRed: 231/255, green: 241/255, blue: 232/255, alpha: 1.0))
        #else
        public static let bg = Color.white
        public static let card = Color(red: 231/255, green: 241/255, blue: 232/255)
        #endif
        public static let text = Color.primary
        public static let stroke = Color.secondary.opacity(0.12)

        // Accent color (pale sage) used for prominent actions and accents
        public static var accent: Color {
            #if canImport(UIKit)
            return Color(UIColor { tc in
                if tc.userInterfaceStyle == .dark {
                    return UIColor(red: 134/255, green: 165/255, blue: 150/255, alpha: 1.0)
                } else {
                    return UIColor(red: 99/255, green: 143/255, blue: 119/255, alpha: 1.0)
                }
            })
            #elseif canImport(AppKit)
            return Color(NSColor(calibratedRed: 99/255, green: 143/255, blue: 119/255, alpha: 1.0))
            #else
            return Color(red: 99/255, green: 143/255, blue: 119/255)
            #endif
        }
    }

    public enum Layout {
        public static let cornerRadius: CGFloat = 16
        public static let tilePadding: CGFloat = 16
        public static let compactTilePadding: CGFloat = 12
        public static let featuredTilePadding: CGFloat = 20
        public static let tileShadowColor: Color = Color.black.opacity(0.06)
        public static let tileShadowRadius: CGFloat = 8
        public static let buttonMinHeight: CGFloat = 44
        public static let buttonVerticalPadding: CGFloat = 12
        public static let buttonHorizontalPadding: CGFloat = 20
    }

    public enum Fonts {
        public static func title() -> Font { .system(.title2, design: .serif).weight(.semibold) }
        public static func compactTitle() -> Font { .system(.headline, design: .serif).weight(.semibold) }
        public static func body() -> Font { .system(.body, design: .rounded) }
        public static func note() -> Font { .footnote }
    }
}
