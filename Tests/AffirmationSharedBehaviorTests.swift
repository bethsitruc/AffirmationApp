import AffirmationShared
import Foundation
import Testing

extension GroundedTests {
@Suite("Fresh Quotes", .serialized)
struct FreshAffirmationFetcherTests {
    @Test("Fetch batch keeps only uplifting quotes and removes duplicates")
    func fetchBatchFiltersAndDeduplicates() async {
        let session = makeMockSession(
            statusCode: 200,
            body: """
            [
              {"q":"Believe in your strength.", "a":"Author A"},
              {"q":"Believe in your strength.", "a":"Author A"},
              {"q":"Hate clouds your heart.", "a":"Author B"},
              {"q":"The future is bright when you trust yourself.", "a":"Author C"},
              {"q":"Time is a flat circle.", "a":"Author D"}
            ]
            """
        )

        let fetcher = FreshAffirmationFetcher(session: session)
        let quotes = await fetcher.fetchBatch(limit: 10, includeAuthor: true)

        #expect(quotes.count == 2)
        #expect(quotes.contains("Believe in your strength. — Author A"))
        #expect(quotes.contains("The future is bright when you trust yourself. — Author C"))
    }

    @Test("Fetch batch omits attribution when requested")
    func fetchBatchOmitsAuthorWhenRequested() async {
        let session = makeMockSession(
            statusCode: 200,
            body: """
            [
              {"q":"You are enough to grow and thrive.", "a":"Author A"}
            ]
            """
        )

        let fetcher = FreshAffirmationFetcher(session: session)
        let quotes = await fetcher.fetchBatch(limit: 1, includeAuthor: false)

        #expect(quotes == ["You are enough to grow and thrive."])
    }

    @Test("Fetch returns nil when the response is invalid")
    func fetchReturnsNilOnFailure() async {
        let session = makeMockSession(
            statusCode: 500,
            body: "[]"
        )

        let fetcher = FreshAffirmationFetcher(session: session)
        let quote = await fetcher.fetch()

        #expect(quote == nil)
    }

    @Test("Malformed, empty, and fully filtered payloads return no quotes", arguments: ["not-json", "[]", "[{\"q\":\"Hate and violence\"}]"])
    func unusablePayload(body: String) async {
        let fetcher = FreshAffirmationFetcher(session: makeMockSession(statusCode: 200, body: body))
        #expect(await fetcher.fetchBatch().isEmpty)
    }

    @Test("Zero limit makes no request and positive limit caps output")
    func requestLimits() async {
        let requests = LockedCounter()
        let session = makeMockSession(statusCode: 200, body: """
        [{"q":"I trust myself."},{"q":"I believe in growth."},{"q":"I choose joy."}]
        """)
        let response = AppTestMockURLProtocol.response
        AppTestMockURLProtocol.response = { requests.increment(); return try response() }
        let fetcher = FreshAffirmationFetcher(session: session)
        #expect(await fetcher.fetchBatch(limit: 0).isEmpty)
        #expect(requests.value == 0)
        #expect(await fetcher.fetchBatch(limit: 2).count == 2)
        #expect(requests.value == 1)
    }

    @Test("Transport failures yield an empty result")
    func transportFailure() async {
        let session = makeMockSession(statusCode: 200, body: "[]")
        AppTestMockURLProtocol.response = { throw URLError(.notConnectedToInternet) }
        #expect(await FreshAffirmationFetcher(session: session).fetchBatch().isEmpty)
    }

    @Test("Whitespace is trimmed and blank or missing author values add no separator")
    func authorFormatting() async {
        let fetcher = FreshAffirmationFetcher(session: makeMockSession(statusCode: 200, body: """
        [{"q":"  I trust myself.  ","a":"  "},{"q":"I choose joy."},{"q":"I believe in growth.","a":" Writer "}]
        """))
        #expect(await fetcher.fetchBatch() == ["I trust myself.", "I choose joy.", "I believe in growth. — Writer"])
    }

    @Test("Cancelled fetch does not return content")
    func cancelledFetch() async {
        let fetcher = FreshAffirmationFetcher(session: makeMockSession(statusCode: 200, body: """
        [{"q":"I trust myself."}]
        """))
        let task = Task { await fetcher.fetchBatch() }
        task.cancel()
        #expect(await task.value.isEmpty)
    }

    private func makeMockSession(statusCode: Int, body: String) -> URLSession {
        AppTestMockURLProtocol.response = {
            let response = HTTPURLResponse(
                url: URL(string: "https://zenquotes.io/api/quotes")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(body.utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppTestMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
}


extension GroundedTests {
@Suite("Shared Preferences", .serialized)
struct SharedPreferencesTests {
    private let keys = [
        "autoGeneration.cadence",
        "autoGeneration.last",
        "homeRefresh.cadence",
        "homeRefresh.last",
    ]

    @Test("Auto generation preferences round-trip")
    func autoGenerationPreferencesRoundTrip() {
        let snapshot = SharedPreferencesSnapshot(keys: keys)
        defer { snapshot.restore() }
        clearPreferences()

        AutoGenerationPreferences.cadence = .daily
        let expectedDate = Date(timeIntervalSince1970: 1_700_000_000)
        AutoGenerationPreferences.lastGeneratedDate = expectedDate

        #expect(AutoGenerationPreferences.cadence == .daily)
        #expect(AutoGenerationPreferences.lastGeneratedDate == expectedDate)
    }

    @Test("Home feed refresh preferences default and round-trip")
    func homeFeedRefreshPreferencesRoundTrip() {
        let snapshot = SharedPreferencesSnapshot(keys: keys)
        defer { snapshot.restore() }
        clearPreferences()

        #expect(HomeFeedRefreshPreferences.cadence == .weekly)
        #expect(HomeFeedRefreshPreferences.lastRefreshDate == nil)

        let expectedDate = Date(timeIntervalSince1970: 1_800_000_000)
        HomeFeedRefreshPreferences.cadence = .daily
        HomeFeedRefreshPreferences.lastRefreshDate = expectedDate

        #expect(HomeFeedRefreshPreferences.cadence == .daily)
        #expect(HomeFeedRefreshPreferences.lastRefreshDate == expectedDate)
    }

    private func clearPreferences() {
        keys.forEach {
            SharedDefaults.removeObject(forKey: $0)
            CloudPreferenceStore.removeObject(forKey: $0)
        }
    }
}
}


private final class AppTestMockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var response: @Sendable () throws -> (HTTPURLResponse, Data) = {
        throw URLError(.badServerResponse)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (response, data) = try Self.response()
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private struct SharedPreferencesSnapshot {
    let entries: [String: Any]
    let missingKeys: Set<String>

    init(keys: [String]) {
        var stored: [String: Any] = [:]
        var missing = Set<String>()

        for key in keys {
            if let value = SharedDefaults.object(forKey: key) {
                stored[key] = value
            } else {
                missing.insert(key)
            }
        }

        entries = stored
        missingKeys = missing
    }

    func restore() {
        for key in missingKeys {
            SharedDefaults.removeObject(forKey: key)
            CloudPreferenceStore.removeObject(forKey: key)
        }
        for (key, value) in entries {
            SharedDefaults.set(value, forKey: key)
            switch value {
            case let string as String:
                CloudPreferenceStore.set(string, forKey: key)
            case let number as NSNumber:
                CloudPreferenceStore.set(number.doubleValue, forKey: key)
            default:
                break
            }
        }
    }
}
