import Foundation

public enum Config {
    // Update this to match your App Group identifier enabled for both app and widget targets.
    public static let appGroup = "group.bethsitruc.affirmationapp"

    // Default refresh interval for widget timelines (in seconds).
    // Keep this in the shared module so both app and widget can use a single source of truth.
    public static let widgetRefreshInterval: TimeInterval = 60 * 60 // 1 hour

    // Throttle launch-time quote fetches so we do not hit the quote API on every app open.
    public static let latestAffirmationFetchInterval: TimeInterval = 60 * 60 * 6 // 6 hours
}
