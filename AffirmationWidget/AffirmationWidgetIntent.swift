import AppIntents
import AffirmationShared

enum AffirmationWidgetDisplayMode {
    case specific
    case shuffle
}

enum AffirmationWidgetContentSource: String, AppEnum {
    case favorites
    case personal
    case all

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Content Source")
    static var caseDisplayRepresentations: [AffirmationWidgetContentSource: DisplayRepresentation] = [
        .favorites: DisplayRepresentation(title: .init(stringLiteral: "Favorites")),
        .personal: DisplayRepresentation(title: .init(stringLiteral: "My Affirmations")),
        .all: DisplayRepresentation(title: .init(stringLiteral: "All Affirmations"))
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

@available(iOSApplicationExtension 17.0, *)
protocol AffirmationWidgetConfigurationIntent: WidgetConfigurationIntent {
    var widgetMode: AffirmationWidgetDisplayMode { get }
    var source: AffirmationWidgetContentSource? { get }
    var widgetFontStyle: AffirmationWidgetFontStyle { get }
    var affirmation: AffirmationEntity? { get }
    var shuffleInterval: AffirmationWidgetShuffleInterval? { get }
}

@available(iOSApplicationExtension 17.0, *)
extension AffirmationWidgetConfigurationIntent {
    var widgetFontStyle: AffirmationWidgetFontStyle {
        AppearancePreferences.font.widgetStyle
    }
}

@available(iOSApplicationExtension 17.0, *)
struct AffirmationSpecificWidgetIntent: AffirmationWidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Specific Affirmation"
    static var description = IntentDescription("Surface one of your favorites or personal affirmations.")

    @Parameter(title: "Source")
    var source: AffirmationWidgetContentSource?

    @Parameter(title: "Specific Affirmation", requestValueDialog: IntentDialog("Pick a favorite or personal affirmation"))
    var affirmation: AffirmationEntity?

    var widgetMode: AffirmationWidgetDisplayMode { .specific }
    var shuffleInterval: AffirmationWidgetShuffleInterval? { nil }

    init() {
        self.source = .favorites
        self.affirmation = nil
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Affirmation \(\.$affirmation) • Source \(\.$source)")
    }
}

@available(iOSApplicationExtension 17.0, *)
struct AffirmationShuffleWidgetIntent: AffirmationWidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Shuffle Affirmations"
    static var description = IntentDescription("Rotate through a set of affirmations automatically.")

    @Parameter(title: "Source")
    var source: AffirmationWidgetContentSource?

    @Parameter(title: "Shuffle Every")
    var shuffleInterval: AffirmationWidgetShuffleInterval?

    var widgetMode: AffirmationWidgetDisplayMode { .shuffle }
    var affirmation: AffirmationEntity? { nil }

    init() {
        self.source = .favorites
        self.shuffleInterval = .hourly
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Source \(\.$source) • Every \(\.$shuffleInterval)")
    }
}

@available(iOSApplicationExtension 17.0, *)
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
        let subtitle: String
        switch origin {
        case .favorite: subtitle = "Favorite"
        case .personal: subtitle = "Mine"
        case .builtIn: subtitle = "Built In"
        }
        return DisplayRepresentation(
            title: .init(stringLiteral: text),
            subtitle: .init(stringLiteral: subtitle)
        )
    }

    init(_ affirmation: Affirmation, origin: Origin) {
        self.id = affirmation.id
        self.text = affirmation.text
        self.origin = origin
    }
}

@available(iOSApplicationExtension 17.0, *)
struct AffirmationQuery: EntityQuery {
    private let repository = WidgetAffirmationRepository()

    init() {}

    func entities(for identifiers: [AffirmationEntity.ID]) async throws -> [AffirmationEntity] {
        let combined = repository.allAffirmations() + repository.personalAffirmations()
        let mapped = combined.map { entity(for: $0) }
        return mapped.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [AffirmationEntity] {
        let favorites = repository.favorites()
        if favorites.isEmpty {
            return repository.personalAffirmations().prefix(10).map { entity(for: $0, origin: .personal) }
        }
        return favorites.prefix(10).map { entity(for: $0, origin: .favorite) }
    }

    func entities(matching string: String) async throws -> [AffirmationEntity] {
        guard !string.isEmpty else { return try await suggestedEntities() }
        let pool = repository.allAffirmations() + repository.personalAffirmations()
        return pool
            .filter { $0.text.localizedCaseInsensitiveContains(string) }
            .prefix(15)
            .map { entity(for: $0) }
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
