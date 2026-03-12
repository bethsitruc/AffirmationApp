import AppIntents
import AffirmationShared

enum AffirmationWidgetDisplayMode {
    case specific
    case shuffle
}

enum AffirmationWidgetContentSource: String, AppEnum {
    case favorites
    case personal

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Content Source")
    static var caseDisplayRepresentations: [AffirmationWidgetContentSource: DisplayRepresentation] = [
        .favorites: DisplayRepresentation(title: .init(stringLiteral: "Favorites")),
        .personal: DisplayRepresentation(title: .init(stringLiteral: "My Affirmations"))
    ]
}

enum AffirmationSpecificSource: String, AppEnum {
    case favorites
    case personal

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Content Source")
    static var caseDisplayRepresentations: [AffirmationSpecificSource: DisplayRepresentation] = [
        .favorites: DisplayRepresentation(title: .init(stringLiteral: "Favorites")),
        .personal: DisplayRepresentation(title: .init(stringLiteral: "My Affirmations"))
    ]
}

enum AffirmationWidgetFontStyle: String, AppEnum {
    case serif
    case rounded
    case modern

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Typography")
    static var caseDisplayRepresentations: [AffirmationWidgetFontStyle: DisplayRepresentation] = [
        .serif: DisplayRepresentation(title: .init(stringLiteral: "Serif")),
        .rounded: DisplayRepresentation(title: .init(stringLiteral: "Rounded")),
        .modern: DisplayRepresentation(title: .init(stringLiteral: "Modern Sans"))
    ]
}

enum AffirmationWidgetShuffleInterval: Int, AppEnum {
    case minutes15 = 900
    case minutes30 = 1800
    case hourly = 3600

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Shuffle Frequency")
    static var caseDisplayRepresentations: [AffirmationWidgetShuffleInterval: DisplayRepresentation] = [
        .minutes15: DisplayRepresentation(title: .init(stringLiteral: "Every 15 min")),
        .minutes30: DisplayRepresentation(title: .init(stringLiteral: "Every 30 min")),
        .hourly: DisplayRepresentation(title: .init(stringLiteral: "Hourly"))
    ]
}

protocol AffirmationWidgetConfigurationIntent: WidgetConfigurationIntent {
    var widgetMode: AffirmationWidgetDisplayMode { get }
    var resolvedSource: AffirmationWidgetContentSource { get }
    var widgetFontStyle: AffirmationWidgetFontStyle { get }
    var affirmation: AffirmationEntity? { get }
    var shuffleInterval: AffirmationWidgetShuffleInterval? { get }
}

extension AffirmationWidgetConfigurationIntent {
    var widgetFontStyle: AffirmationWidgetFontStyle {
        AppearancePreferences.font.widgetStyle
    }
}

struct AffirmationSpecificWidgetIntent: AffirmationWidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Specific Affirmation"
    static var description = IntentDescription("Pin one favorite or personal affirmation.")

    @Parameter(title: "Choose", requestValueDialog: IntentDialog("Pick a favorite or personal affirmation"))
    var affirmation: AffirmationEntity?

    var widgetMode: AffirmationWidgetDisplayMode { .specific }
    var resolvedSource: AffirmationWidgetContentSource { .favorites }
    var shuffleInterval: AffirmationWidgetShuffleInterval? { nil }

    init() {
        self.affirmation = nil
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Choose \(\.$affirmation)")
    }
}

struct AffirmationShuffleWidgetIntent: AffirmationWidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Shuffle Affirmations"
    static var description = IntentDescription("Rotate your selected affirmation set.")

    @Parameter(title: "Source")
    var source: AffirmationWidgetContentSource?

    var widgetMode: AffirmationWidgetDisplayMode { .shuffle }
    var resolvedSource: AffirmationWidgetContentSource { source ?? .favorites }
    var affirmation: AffirmationEntity? { nil }
    var shuffleInterval: AffirmationWidgetShuffleInterval? { .hourly }

    init() {
        self.source = .favorites
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Source \(\.$source)")
    }
}

struct AffirmationEntity: AppEntity, Identifiable, Sendable {
    let id: UUID
    let text: String
    let origin: Origin

    enum Origin: String, Sendable {
        case favorite
        case personal
        case builtIn
    }

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: .init(stringLiteral: "Affirmation"))
    static var defaultQuery = AffirmationQuery()

    var displayRepresentation: DisplayRepresentation {
        let preview = Self.previewText(from: text)
        let subtitle: String
        switch origin {
        case .favorite: subtitle = "Favorite"
        case .personal: subtitle = "Mine"
        case .builtIn: subtitle = "Built In"
        }
        return DisplayRepresentation(
            title: .init(stringLiteral: preview),
            subtitle: .init(stringLiteral: subtitle)
        )
    }

    private static func previewText(from text: String) -> String {
        let flattened = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard flattened.count > 34 else { return flattened }
        return String(flattened.prefix(31)) + "..."
    }

    init(_ affirmation: Affirmation, origin: Origin) {
        self.id = affirmation.id
        self.text = affirmation.text
        self.origin = origin
    }
}

struct AffirmationQuery: EntityQuery {
    private let repository = WidgetAffirmationRepository()

    init() {}

    func entities(for identifiers: [AffirmationEntity.ID]) async throws -> [AffirmationEntity] {
        let mapped = selectedPool().map { entity(for: $0) }
        return mapped.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [AffirmationEntity] {
        return selectedPool().prefix(15).map { entity(for: $0) }
    }

    func entities(matching string: String) async throws -> [AffirmationEntity] {
        guard !string.isEmpty else { return try await suggestedEntities() }
        return selectedPool()
            .filter { $0.text.localizedCaseInsensitiveContains(string) }
            .prefix(15)
            .map { entity(for: $0) }
    }

    private func selectedPool() -> [Affirmation] {
        let favorites = repository.source(.favorites, fallbackToAll: false)
        let personal = repository.source(.personal, fallbackToAll: false)
        var seen = Set<UUID>()
        var combined: [Affirmation] = []

        for affirmation in favorites + personal {
            if seen.insert(affirmation.id).inserted {
                combined.append(affirmation)
            }
        }
        return combined
    }

    private func entity(for affirmation: Affirmation, origin: AffirmationEntity.Origin? = nil) -> AffirmationEntity {
        let resolvedOrigin: AffirmationEntity.Origin
        if affirmation.isUserCreated {
            resolvedOrigin = .personal
        } else if affirmation.isFavorite {
            resolvedOrigin = .favorite
        } else {
            resolvedOrigin = .builtIn
        }
        return AffirmationEntity(affirmation, origin: origin ?? resolvedOrigin)
    }
}

extension AffirmationFontPreference {
    var widgetStyle: AffirmationWidgetFontStyle {
        switch self {
        case .serif: return .serif
        case .rounded: return .rounded
        case .modern: return .modern
        }
    }
}
