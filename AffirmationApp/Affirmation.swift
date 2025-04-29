// MARK: - Affirmation Model
// This file defines the Affirmation struct, which represents a single affirmation
// used within the AffirmationApp. It conforms to Identifiable, Codable, and Equatable
// protocols to support SwiftUI lists, data persistence, and equality checks.

import Foundation

/// Represents a single affirmation entry, including its content, metadata, and categorization.
public struct Affirmation: Identifiable, Codable, Equatable {
    /// A unique identifier for the affirmation.
    public let id: UUID

    /// The text content of the affirmation.
    public var text: String

    /// Indicates whether the affirmation has been marked as a favorite by the user.
    public var isFavorite: Bool = false

    /// Indicates whether the affirmation was created by the user.
    public var isUserCreated: Bool = false

    /// A list of themes associated with the affirmation, used for filtering and categorization.
    public var themes: Array<String>
}
