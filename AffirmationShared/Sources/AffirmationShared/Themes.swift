import Foundation

@available(*, deprecated, message: "Themes removed. This enum is kept as a no-op for compatibility.")
public enum Themes {
    public static let all: [String] = []
    public static func contains(_ theme: String) -> Bool { false }
    public static func normalized(_ theme: String) -> String? { nil }
}
