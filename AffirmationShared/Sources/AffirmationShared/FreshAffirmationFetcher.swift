import Foundation

/// Fetches fresh quotes from ZenQuotes.
public struct FreshAffirmationFetcher {
    private let quotesURL = URL(string: "https://zenquotes.io/api/quotes")!
    private let session: URLSession

    private struct QuoteResponse: Decodable {
        let q: String
        let a: String?
    }

    // Lightweight local moderation to keep feed content aligned with an uplifting/affirming product.
    private static let upliftingKeywords: [String] = [
        "believe", "confidence", "confident", "courage", "dream", "enough",
        "faith", "future", "gratitude", "grateful", "growth", "heal",
        "healing", "hope", "joy", "kind", "kindness", "learn", "light",
        "love", "peace", "progress", "resilience", "smile", "strength",
        "thrive", "trust", "worthy"
    ]

    private static let blockedTerms: [String] = [
        "abuse", "blood", "despair", "die", "dying", "hate", "hopeless",
        "kill", "murder", "racist", "revenge", "self-harm", "sexist",
        "suicide", "terror", "violence", "weapon", "worthless"
    ]

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches a single quote body (without attribution), suitable for converting into an affirmation.
    public func fetch() async -> String? {
        await fetchQuote(includeAuthor: false)
    }

    /// Fetches one quote. Include attribution when displaying as a quote in the feed.
    public func fetchQuote(includeAuthor: Bool = true) async -> String? {
        let quotes = await fetchBatch(limit: 50, includeAuthor: includeAuthor)
        return quotes.randomElement()
    }

    /// Fetches up to `limit` quotes from ZenQuotes.
    public func fetchBatch(limit: Int = 50, includeAuthor: Bool = true) async -> [String] {
        guard limit > 0 else { return [] }

        var request = URLRequest(url: quotesURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 12

        do {
            let (data, response) = try await session.data(for: request)
            if Task.isCancelled { return [] }

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return []
            }

            let decoded = try JSONDecoder().decode([QuoteResponse].self, from: data)

            var seen = Set<String>()
            var output: [String] = []
            output.reserveCapacity(min(limit, decoded.count))

            for quote in decoded {
                guard Self.isUplifting(quote.q) else { continue }
                guard let text = Self.formattedText(for: quote, includeAuthor: includeAuthor) else { continue }
                if seen.insert(text).inserted {
                    output.append(text)
                    if output.count == limit {
                        break
                    }
                }
            }

            return output
        } catch {
#if DEBUG
            print("FreshAffirmationFetcher failed:", error)
#endif
            return []
        }
    }

    private static func formattedText(for quote: QuoteResponse, includeAuthor: Bool) -> String? {
        let text = quote.q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        guard includeAuthor else {
            return text
        }

        let author = quote.a?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !author.isEmpty else {
            return text
        }
        return "\(text) — \(author)"
    }

    private static func isUplifting(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let lowered = text.lowercased()

        // Reject obvious unsafe/off-tone content first.
        for blocked in blockedTerms {
            if lowered.contains(blocked) {
                return false
            }
        }

        // Require at least one uplifting signal for home-feed freshness.
        for keyword in upliftingKeywords {
            if lowered.contains(keyword) {
                return true
            }
        }

        return false
    }
}
