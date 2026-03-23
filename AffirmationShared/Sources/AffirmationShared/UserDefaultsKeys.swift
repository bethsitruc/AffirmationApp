import Foundation

extension UserDefaults {
    public struct Keys {
        public static let latestAffirmation = "latestAffirmation"
        public static let latestAffirmationFetchedAt = "latestAffirmationFetchedAt"
        public static let affirmations = "affirmations"
        public static let userSubmittedAffirmations = "userSubmittedAffirmations"
        public static let deletedUserAffirmationTombstones = "deletedUserAffirmationTombstones"
        public static let favoriteAffirmations = "favoriteAffirmations"
        public static let deletedFavoriteAffirmationTombstones = "deletedFavoriteAffirmationTombstones"
    }
}
