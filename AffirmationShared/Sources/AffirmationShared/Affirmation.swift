// Model lives in the app target; no separate module needed.
import Foundation

/// Represents a single affirmation entry, including its content, metadata, and categorization.
public struct Affirmation: Identifiable, Codable, Equatable {
    /// A unique identifier for the affirmation.
    public let id: UUID

    /// The text content of the affirmation.
    public var text: String

    /// Indicates whether the affirmation has been marked as a favorite by the user.
    public var isFavorite: Bool

    /// Indicates whether the affirmation was created by the user.
    public var isUserCreated: Bool

    /// A list of themes associated with the affirmation, used for filtering and categorization.
    public var themes: [String]

    /// Timestamp for when the affirmation entered the user’s library. Nil for legacy/built-in entries.
    public var createdAt: Date?

    /// Indicates whether this entry was generated via Apple Intelligence.
    public var isAIGenerated: Bool

    private enum CodingKeys: String, CodingKey {
        case id, text, isFavorite, isUserCreated, themes, createdAt, isAIGenerated
    }

    public init(
        id: UUID = UUID(),
        text: String,
        isFavorite: Bool = false,
        isUserCreated: Bool = false,
        themes: [String] = [],
        createdAt: Date? = nil,
        isAIGenerated: Bool = false
    ) {
        self.id = id
        self.text = text
        self.isFavorite = isFavorite
        self.isUserCreated = isUserCreated
        self.themes = themes
        self.createdAt = createdAt
        self.isAIGenerated = isAIGenerated
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.text = try container.decode(String.self, forKey: .text)
        self.isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.isUserCreated = try container.decodeIfPresent(Bool.self, forKey: .isUserCreated) ?? false
        self.themes = try container.decodeIfPresent([String].self, forKey: .themes) ?? []
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.isAIGenerated = try container.decodeIfPresent(Bool.self, forKey: .isAIGenerated) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(isUserCreated, forKey: .isUserCreated)
        try container.encode(themes, forKey: .themes)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encode(isAIGenerated, forKey: .isAIGenerated)
    }
}
