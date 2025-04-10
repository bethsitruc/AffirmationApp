import Foundation

public struct Affirmation: Identifiable, Codable, Equatable {
    public let id: UUID
    public let text: String
    public var isFavorite: Bool = false
    var themes: Array<String>
}
