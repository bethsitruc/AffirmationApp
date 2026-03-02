import AffirmationShared
import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// High-level façade that tries to generate a fresh affirmation with Apple's on-device Foundation Models,
/// then gracefully falls back to the lightweight network API or deterministic local seeds.
struct AffirmationGenerator {
    struct Result {
        let text: String
        let source: Source
        let metadata: Metadata
    }

    struct Metadata {
        let theme: String?
        let tone: Tone
        let note: String?
    }

    enum Source: String {
        case foundationModel
        case network
        case local
    }

    private let fmClient: FoundationModelClient
    private let fetcher: FreshAffirmationFetcher
    private let fallbackGenerator: AffirmationGenerating

    init(
        fmClient: FoundationModelClient = FoundationModelClient(),
        fetcher: FreshAffirmationFetcher = FreshAffirmationFetcher(),
        fallbackGenerator: AffirmationGenerating = LocalGenerator()
    ) {
        self.fmClient = fmClient
        self.fetcher = fetcher
        self.fallbackGenerator = fallbackGenerator
    }

    func foundationModelAvailability() -> FoundationModelAvailability {
        fmClient.availability
    }

    func generate(theme: String?, tone: Tone = .calm) async -> Result {
        if fmClient.availability.status == .available {
            if let text = try? await fmClient.generate(theme: theme, tone: tone) {
                return Result(
                    text: text,
                    source: .foundationModel,
                    metadata: Metadata(theme: theme, tone: tone, note: "Generated privately on-device with Apple Foundation Models.")
                )
            }
        }

        if let remote = await fetcher.fetch() {
            let styled = tone.stylizedText(for: remote, theme: theme)
            return Result(
                text: styled,
                source: .network,
                metadata: Metadata(theme: theme, tone: tone, note: "Fetched from affirmations.dev API fallback.")
            )
        }

        let local = (try? await fallbackGenerator.generate(theme: theme)) ?? "You are enough."
        let styledLocal = tone.stylizedText(for: local, theme: theme)
        return Result(
            text: styledLocal,
            source: .local,
            metadata: Metadata(theme: theme, tone: tone, note: "Local deterministic fallback.")
        )
    }
}

// MARK: - Tone configuration

extension AffirmationGenerator {
    enum Tone: String, CaseIterable, Identifiable {
        case calm
        case confident
        case playful
        case grateful

        var id: String { rawValue }

        var label: String {
            switch self {
            case .calm: return "Calm & Centered"
            case .confident: return "Bold & Confident"
            case .playful: return "Playful Boost"
            case .grateful: return "Gratitude"
            }
        }

        var instructionsQualifier: String {
            switch self {
            case .calm: return "Calm, steady, and reassuring."
            case .confident: return "Energizing, courageous, and direct."
            case .playful: return "Light, witty, and uplifting."
            case .grateful: return "Warm, appreciative, and heart-forward."
            }
        }

        var styleGuidance: String {
            switch self {
            case .calm:
                return "Soft cadences, soothing verbs, grounded imagery like breath, tides, or steady light."
            case .confident:
                return "Strong verbs, vivid momentum, language that feels like a pep talk before a big moment."
            case .playful:
                return "Surprising metaphors, lively verbs, maybe a wink of humor or rhythm (no sarcasm)."
            case .grateful:
                return "Language of appreciation, noticing small gifts, gentle warmth."
            }
        }

        var promptQualifier: String {
            switch self {
            case .calm: return "and make it sound like a gentle reset for the nervous system"
            case .confident: return "and make it sound bold enough for a pre-game rally"
            case .playful: return "and make it sound whimsical, upbeat, even a little cheeky"
            case .grateful: return "and make it sound thankful, savoring small gifts"
            }
        }

        var temperature: Double {
            switch self {
            case .calm: return 0.35
            case .confident: return 0.45
            case .playful: return 0.6
            case .grateful: return 0.4
            }
        }

        func stylizedText(for base: String?, theme: String?) -> String {
            let trimmed = base?.trimmingCharacters(in: .whitespacesAndNewlines)
            let focus = Self.focusPhrase(theme)
            switch self {
            case .calm:
                return trimmed?.ensuredSentence() ?? Self.calmFallback(for: focus)
            case .confident:
                let booster = Self.confidentBoost(for: focus)
                if let trimmed, !trimmed.isEmpty {
                    return "\(trimmed.ensuredSentence()) \(booster)"
                }
                return booster
            case .playful:
                let playful = Self.playfulTag(for: focus)
                if let trimmed, !trimmed.isEmpty {
                    return "\(trimmed.ensuredSentence()) \(playful)"
                }
                return playful
            case .grateful:
                let grateful = Self.gratefulTag(for: focus)
                if let trimmed, !trimmed.isEmpty {
                    return "\(trimmed.ensuredSentence()) \(grateful)"
                }
                return grateful
            }
        }

        private static func focusPhrase(_ theme: String?) -> String {
            guard
                let raw = theme?.trimmingCharacters(in: .whitespacesAndNewlines),
                !raw.isEmpty
            else {
                return "today"
            }
            return raw
        }

        private static func calmFallback(for focus: String) -> String {
            [
                "I breathe into \(focus) and feel grounded.",
                "I move through \(focus) with ease and trust.",
                "I let \(focus) unfold in its own gentle rhythm."
            ].randomElement()!
        }

        private static func confidentBoost(for focus: String) -> String {
            [
                "I charge into \(focus) with fearless energy.",
                "I lead \(focus) with bold, clear action.",
                "I turn \(focus) into proof of my power."
            ].randomElement()!
        }

        private static func playfulTag(for focus: String) -> String {
            [
                "Let’s make \(focus) a joyful improv.",
                "I dance through \(focus) with laughter and light.",
                "\(focus.capitalized) gets the confetti treatment today."
            ].randomElement()!
        }

        private static func gratefulTag(for focus: String) -> String {
            [
                "I savor \(focus) with a thankful heart.",
                "I honor the tiny blessings tucked inside \(focus).",
                "\(focus.capitalized) is another chance to practice gratitude."
            ].randomElement()!
        }
    }
}

private extension String {
    func ensuredSentence() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return trimmed }
        if ".!?".contains(last) {
            return trimmed
        }
        return "\(trimmed)."
    }
}

// MARK: - Foundation Model support

struct FoundationModelAvailability: Equatable {
    enum Status {
        case available
        case needsSetup
        case downloading
        case notSupported
        case osTooOld
        case missingFramework
    }

    let status: Status
    let message: String
}

struct FoundationModelClient {
    var availability: FoundationModelAvailability {
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 15.0, *) {
            return Self.appleIntelligenceAvailability()
        } else {
            return .init(status: .osTooOld, message: "Requires iOS 26 / macOS 15 or newer.")
        }
#else
        return .init(status: .missingFramework, message: "Apple Intelligence isn't bundled in this build yet.")
#endif
    }

    func generate(theme: String?, tone: AffirmationGenerator.Tone) async throws -> String {
#if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 15.0, *) else {
            throw GenerationError.osTooOld
        }
        return try await Self.appleIntelligenceGenerate(theme: theme, tone: tone)
#else
        throw GenerationError.frameworkMissing
#endif
    }

    enum GenerationError: Error {
        case frameworkMissing
        case osTooOld
        case notReady
    }

#if canImport(FoundationModels)
    @available(iOS 26.0, macOS 15.0, *)
    private static func instructions(for tone: AffirmationGenerator.Tone) -> String {
        """
        You are an inclusive affirmation coach. Follow the rules:
        • Reply with exactly one first-person statement, 8–18 words, no emojis/hashtags.
        • Use accessible language people can read aloud without cringing.
        • Tone goal: \(tone.instructionsQualifier) \(tone.styleGuidance)
        """
    }
#endif

    private static func prompt(for theme: String?, tone: AffirmationGenerator.Tone) -> String {
        guard let trimmed = sanitized(theme) else {
            return "Write one short (≤18 words) present-tense affirmation reinforcing self-belief, \(tone.promptQualifier)."
        }
        return "Write one short (≤18 words) present-tense affirmation about \(trimmed) that stays first-person and specific, \(tone.promptQualifier)."
    }

    private static func sanitized(_ theme: String?) -> String? {
        guard let theme else { return nil }
        let trimmed = theme.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.replacingOccurrences(of: "\"", with: "")
    }

    private static func postprocess(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 15.0, *)
private extension FoundationModelClient {
    static func appleIntelligenceAvailability() -> FoundationModelAvailability {
        let availability = SystemLanguageModel.default.availability
        switch availability {
        case .available:
            return .init(status: .available, message: "Apple Intelligence is ready to use on this device.")
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .init(status: .notSupported, message: "This device does not support Apple Intelligence.")
            case .appleIntelligenceNotEnabled:
                return .init(status: .needsSetup, message: "Enable Apple Intelligence under Settings ▸ Siri & Search.")
            case .modelNotReady:
                return .init(status: .downloading, message: "Apple Intelligence is still downloading required components.")
            @unknown default:
                return .init(status: .notSupported, message: "Apple Intelligence reported an unknown availability issue.")
            }
        @unknown default:
            return .init(status: .notSupported, message: "Apple Intelligence availability could not be determined.")
        }
    }

    static func appleIntelligenceGenerate(theme: String?, tone: AffirmationGenerator.Tone) async throws -> String {
        guard SystemLanguageModel.default.isAvailable else {
            throw GenerationError.notReady
        }

        let prompt = prompt(for: theme, tone: tone)
        let session = LanguageModelSession(instructions: instructions(for: tone))
        var options = GenerationOptions()
        options.temperature = tone.temperature
        options.maximumResponseTokens = 48

        let response = try await session.respond(to: prompt, options: options)
        return postprocess(response.content)
    }
}
#endif
