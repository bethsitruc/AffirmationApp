import Foundation

/// Protocol for generating a short affirmation. Implementations may be on-device, remote, or local canned.
public protocol AffirmationGenerating {
    /// Generate a single affirmation for an optional theme.
    /// - Returns: The generated affirmation text.
    func generate(theme: String?) async throws -> String
}

/// A small deterministic local generator used as a safe default.
public struct LocalGenerator: AffirmationGenerating {
    public init() {}

    private let canned = [
        "I choose progress over perfection.",
        "I am steady, capable, and calm.",
        "I honor my limits and grow daily."
    ]

    public func generate(theme: String?) async throws -> String {
        // Simple deterministic selection based on optional theme hash to vary outputs.
        if let theme, !theme.isEmpty {
            let idx = abs(theme.hashValue) % canned.count
            return canned[idx]
        }
        return canned.randomElement() ?? canned[0]
    }
}
