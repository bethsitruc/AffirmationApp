import SwiftUI

public extension AffirmationColorTheme {
    var gradient: LinearGradient {
        switch self {
        case .sage:
            return LinearGradient(
                colors: [
                    Color(red: 223/255, green: 239/255, blue: 231/255),
                    Color(red: 191/255, green: 220/255, blue: 205/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dusk:
            return LinearGradient(
                colors: [
                    Color(red: 27/255, green: 31/255, blue: 45/255),
                    Color(red: 65/255, green: 76/255, blue: 104/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .glow:
            return LinearGradient(
                colors: [
                    Color(red: 255/255, green: 227/255, blue: 205/255),
                    Color(red: 255/255, green: 194/255, blue: 214/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var accentColor: Color {
        switch self {
        case .sage:
            return Color(red: 99/255, green: 143/255, blue: 119/255)
        case .dusk:
            return Color(red: 173/255, green: 182/255, blue: 210/255)
        case .glow:
            return Color(red: 207/255, green: 103/255, blue: 141/255)
        }
    }

    var widgetColors: (background: Color, text: Color, subtitle: Color) {
        switch self {
        case .sage:
            return (
                Color(red: 228/255, green: 241/255, blue: 233/255),
                Color(red: 15/255, green: 59/255, blue: 46/255),
                Color(red: 76/255, green: 120/255, blue: 104/255)
            )
        case .dusk:
            return (
                Color(red: 28/255, green: 32/255, blue: 45/255),
                Color(red: 235/255, green: 239/255, blue: 255/255),
                Color(red: 158/255, green: 173/255, blue: 204/255)
            )
        case .glow:
            return (
                Color(red: 255/255, green: 232/255, blue: 223/255),
                Color(red: 89/255, green: 47/255, blue: 61/255),
                Color(red: 148/255, green: 91/255, blue: 110/255)
            )
        }
    }

    var cardBackground: Color {
        switch self {
        case .sage:
            return Color(red: 240/255, green: 247/255, blue: 241/255)
        case .dusk:
            return Color(red: 33/255, green: 38/255, blue: 55/255)
        case .glow:
            return Color(red: 255/255, green: 236/255, blue: 230/255)
        }
    }

    var cardStroke: Color {
        primaryText.opacity(0.18)
    }
}

public extension AffirmationFontPreference {
    private var fontDesign: Font.Design {
        switch self {
        case .serif: return .serif
        case .rounded: return .rounded
        case .modern: return .default
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: fontDesign)
    }

    var swiftUIFont: Font {
        font(size: 26, weight: .semibold)
    }
}

public extension AffirmationColorTheme {
    var primaryText: Color {
        switch self {
        case .sage: return Color(red: 15/255, green: 59/255, blue: 46/255)
        case .dusk: return Color(red: 232/255, green: 238/255, blue: 255/255)
        case .glow: return Color(red: 70/255, green: 36/255, blue: 47/255)
        }
    }

    var secondaryText: Color {
        primaryText.opacity(0.75)
    }
}
