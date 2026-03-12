import AppIntents
import AffirmationShared
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 17.0, *)
struct AffirmationWidgetEntry: TimelineEntry {
    let date: Date
    let text: String
    let theme: WidgetColorTheme
    let fontStyle: AffirmationWidgetFontStyle
}

@available(iOSApplicationExtension 17.0, *)
struct AffirmationWidgetProvider<Intent: AffirmationWidgetConfigurationIntent>: AppIntentTimelineProvider {
    private let repository = WidgetAffirmationRepository()

    func placeholder(in context: Context) -> AffirmationWidgetEntry {
        let currentTheme = AppearancePreferences.theme
        let currentFont = AppearancePreferences.font
        return AffirmationWidgetEntry(
            date: Date(),
            text: "You are enough.",
            theme: WidgetColorTheme(theme: currentTheme),
            fontStyle: currentFont.widgetStyle
        )
    }

    func snapshot(for configuration: Intent, in context: Context) async -> AffirmationWidgetEntry {
        entry(for: configuration, isSnapshot: true)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<AffirmationWidgetEntry> {
        let entry = entry(for: configuration, isSnapshot: false)
        let refresh: TimeInterval
        switch configuration.widgetMode {
        case .shuffle:
            let interval = configuration.shuffleInterval ?? .hourly
            refresh = TimeInterval(interval.rawValue)
        case .specific:
            refresh = 60 * 60 * 6 // refresh a few times per day for safety
        }

        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(refresh)))
    }

    private func entry(for configuration: Intent, isSnapshot: Bool) -> AffirmationWidgetEntry {
        let theme = WidgetColorTheme(theme: AppearancePreferences.theme)
        let text = resolveText(for: configuration, isSnapshot: isSnapshot)
        return AffirmationWidgetEntry(
            date: Date(),
            text: text,
            theme: theme,
            fontStyle: configuration.widgetFontStyle
        )
    }

    private func resolveText(for configuration: Intent, isSnapshot: Bool) -> String {
        let sourceAffirmations = repository.source(
            configuration.resolvedSource,
            fallbackToAll: false
        )

        switch configuration.widgetMode {
        case .specific:
            if let entity = configuration.affirmation,
               let match = repository.affirmation(with: entity.id) {
                return match.text
            }
            if let first = sourceAffirmations.first {
                return first.text
            }
            return "Pick a favorite or personal affirmation"
        case .shuffle:
            let pool = sourceAffirmations
            if let random = pool.randomElement() {
                return random.text
            }
            return "Favorite or add affirmations"
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
struct WidgetColorTheme {
    let background: Color
    let text: Color
    let accent: Color

    init(theme: AffirmationColorTheme) {
        let palette = theme.widgetColors
        self.background = palette.background
        self.text = palette.text
        self.accent = theme.accentColor
    }
}

@available(iOSApplicationExtension 17.0, *)
struct AffirmationWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsWidgetContainerBackground
    var entry: AffirmationWidgetEntry

    var body: some View {
        ZStack(alignment: .leading) {
            if !showsWidgetContainerBackground {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(entry.theme.background.opacity(isFullColorRendering ? 1 : 0.9))
            }

            textContent(for: family)
                .padding(layoutPadding(for: family))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .tint(entry.theme.accent)
        .containerBackground(for: .widget) {
            if isFullColorRendering {
                entry.theme.background
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private func textContent(for family: WidgetFamily) -> some View {
        switch family {
        case .systemMedium:
            HStack(alignment: .center, spacing: 16) {
                adaptiveTextStack(for: family)
                Spacer(minLength: 0)
            }
        case .systemLarge:
            VStack(alignment: .leading, spacing: 16) {
                adaptiveTextStack(for: family)
                Spacer(minLength: 0)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                adaptiveTextStack(for: family)
            }
        }
    }

    @ViewBuilder
    private func adaptiveTextStack(for family: WidgetFamily) -> some View {
        ViewThatFits(in: .vertical) {
            ForEach(fontCandidates(for: family), id: \.self) { size in
                textStack(
                    fontSize: size,
                    lineLimit: fallbackLineLimit(for: family)
                )
            }
            textStack(
                fontSize: minimumFont(for: family),
                lineLimit: fallbackLineLimit(for: family)
            )
        }
    }

    private func textStack(fontSize: CGFloat, lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.text)
                .font(contentFont(for: fontSize))
                .foregroundStyle(contentStyleColor)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.6)
                .allowsTightening(true)
                .lineLimit(lineLimit)
        }
    }

    private func fontCandidates(for family: WidgetFamily) -> [CGFloat] {
        switch family {
        case .systemSmall:
            return [22, 20, 18, 16, 15, 14, 13]
        case .systemMedium:
            return [26, 24, 22, 20, 18, 16, 15, 14]
        case .systemLarge:
            return [30, 28, 26, 24, 22, 20, 18, 16]
        default:
            return [22, 20, 18, 16, 15, 14]
        }
    }

    private func minimumFont(for family: WidgetFamily) -> CGFloat {
        fontCandidates(for: family).last ?? 14
    }

    private func fallbackLineLimit(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall:
            return 10
        case .systemMedium:
            return 14
        case .systemLarge:
            return 20
        default:
            return 12
        }
    }

    private func contentFont(for size: CGFloat) -> Font {
        switch entry.fontStyle {
        case .serif:
            return .system(size: size, weight: .semibold, design: .serif)
        case .rounded:
            return .system(size: size, weight: .semibold, design: .rounded)
        case .modern:
            return .system(size: size, weight: .semibold, design: .default)
        }
    }

    private func layoutPadding(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall: return 16
        case .systemMedium: return 20
        default: return 24
        }
    }

    private var contentStyleColor: AnyShapeStyle {
        if isFullColorRendering {
            AnyShapeStyle(entry.theme.text)
        } else {
            AnyShapeStyle(.primary)
        }
    }

    private var isFullColorRendering: Bool {
        renderingMode == .fullColor
    }
}

@available(iOSApplicationExtension 17.0, *)
struct AffirmationWidget_Previews: PreviewProvider {
    static var previews: some View {
        AffirmationWidgetEntryView(
            entry: AffirmationWidgetEntry(
                date: Date(),
                text: "You are exactly where you need to be.",
                theme: WidgetColorTheme(theme: .sage),
                fontStyle: .serif
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))

        AffirmationWidgetEntryView(
            entry: AffirmationWidgetEntry(
                date: Date(),
                text: "Small steps every day lead to big changes.",
                theme: WidgetColorTheme(theme: .sage),
                fontStyle: .modern
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}

@available(iOSApplicationExtension 17.0, *)
struct AffirmationSpecificWidget: Widget {
    let kind: String = "AffirmationWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: AffirmationSpecificWidgetIntent.self, provider: AffirmationWidgetProvider<AffirmationSpecificWidgetIntent>()) { entry in
            AffirmationWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Grounded Affirmation")
        .description("Pin one favorite or personal affirmation.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@available(iOSApplicationExtension 17.0, *)
struct AffirmationShuffleWidget: Widget {
    let kind: String = "AffirmationWidgetShuffle"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: AffirmationShuffleWidgetIntent.self, provider: AffirmationWidgetProvider<AffirmationShuffleWidgetIntent>()) { entry in
            AffirmationWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Grounded Shuffle")
        .description("Rotate favorites or personal affirmations.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@available(iOSApplicationExtension 17.0, *)
@main
struct AffirmationWidgetBundle: WidgetBundle {
    var body: some Widget {
        AffirmationSpecificWidget()
        AffirmationShuffleWidget()
    }
}
