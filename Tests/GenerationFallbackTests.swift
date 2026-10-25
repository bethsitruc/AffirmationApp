import AffirmationShared
import Foundation
import Testing
@testable import AffirmationApp

extension GroundedTests {
    @Suite("Generation fallback execution", .serialized)
    struct GenerationFallbackTests {
        @Test("Available on-device generation wins without a network request")
        func onDeviceWins() async {
            let session = session(body: "[]")
            GenerationURLProtocol.requests = 0
            let generator = AffirmationGenerator(fmClient: FakeFoundationModel(available: true, fails: false),
                                                fetcher: FreshAffirmationFetcher(session: session), fallbackGenerator: FakeLocal(fails: true))
            let result = await generator.generate(theme: "morning", tone: .grateful)
            #expect(result.text == "On-device encouragement.")
            #expect(result.source == .foundationModel)
            #expect(result.metadata.theme == "morning")
            #expect(result.metadata.tone == .grateful)
            #expect(GenerationURLProtocol.requests == 0)
        }

        @Test("Unavailable or failing on-device generation falls back to network", arguments: [false, true])
        func networkFallback(available: Bool) async {
            let generator = AffirmationGenerator(fmClient: FakeFoundationModel(available: available, fails: true),
                fetcher: FreshAffirmationFetcher(session: session(body: """
                [{"q":"I trust my progress.","a":"Author"}]
                """)), fallbackGenerator: FakeLocal(fails: true))
            let result = await generator.generate(theme: nil)
            #expect(result.source == .network)
            #expect(!result.text.isEmpty)
            #expect(result.metadata.note?.contains("fallback") == true)
            #expect(!result.text.contains("Author"))
        }

        @Test("Network failure uses local output, then emergency text if local also fails", arguments: [false, true])
        func offlineFallback(localFails: Bool) async {
            let generator = AffirmationGenerator(fmClient: FakeFoundationModel(available: false, fails: true),
                fetcher: FreshAffirmationFetcher(session: session(body: "invalid")), fallbackGenerator: FakeLocal(fails: localFails))
            let result = await generator.generate(theme: "rest", tone: .calm)
            #expect(result.source == .local)
            #expect(!result.text.isEmpty)
            #expect(result.text.contains(localFails ? "enough" : "steady"))
            #expect(result.metadata.theme == "rest")
        }

        private func session(body: String) -> URLSession {
            GenerationURLProtocol.body = Data(body.utf8)
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [GenerationURLProtocol.self]
            return URLSession(configuration: config)
        }
    }
}

private struct FakeFoundationModel: FoundationModelGenerating {
    let available: Bool
    let fails: Bool
    var availability: FoundationModelAvailability { .init(status: available ? .available : .missingFramework, message: "Fake") }
    func generate(theme: String?, tone: AffirmationGenerator.Tone) async throws -> String {
        if fails { throw URLError(.unknown) }
        return "On-device encouragement."
    }
}
private struct FakeLocal: AffirmationGenerating {
    let fails: Bool
    func generate(theme: String?) async throws -> String {
        if fails { throw URLError(.unknown) }
        return "I am steady."
    }
}
private final class GenerationURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var requests = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests += 1
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
