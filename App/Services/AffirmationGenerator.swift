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
                metadata: Metadata(theme: theme, tone: tone, note: "Fetched from ZenQuotes API fallback.")
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
            case .confident: return "Steady & Confident"
            case .playful: return "Playful & Bright"
            case .grateful: return "Grateful & Open"
            }
        }

        var instructionsQualifier: String {
            switch self {
            case .calm: return "Calm, steady, and reassuring."
            case .confident: return "Self-trusting, assured, and quietly strong."
            case .playful: return "Warm, whimsical, and genuinely witty."
            case .grateful: return "Openhearted, appreciative, and gently reverent."
            }
        }

        var styleGuidance: String {
            switch self {
            case .calm:
                return "Soft cadences, soothing verbs, grounded imagery like breath, tides, or steady light."
            case .confident:
                return "Clear, decisive language with grounded strength; confidence should feel rooted, not performative or shouty."
            case .playful:
                return "Use a clever turn of phrase, gentle wordplay, or a surprising but sincere image. No sarcasm, cringe slang, or trying too hard."
            case .grateful:
                return "Language of noticing, appreciation, and ordinary gifts; gratitude should feel specific, not generic."
            }
        }

        var promptQualifier: String {
            switch self {
            case .calm: return "and make it sound like a gentle reset for the nervous system"
            case .confident: return "and make it sound like deep self-trust before an important moment"
            case .playful: return "and make it sound whimsical, lightly clever, and a little delightfully unexpected"
            case .grateful: return "and make it sound like someone savoring ordinary gifts with intention"
            }
        }

        var extraPromptDirections: String {
            switch self {
            case .calm:
                return ""
            case .confident:
                return "Prefer steady conviction over hype."
            case .playful:
                return """
                A playful line should contain a wink of personality: a gentle pun, mischievous metaphor, or unexpectedly charming image.
                It should feel like something you'd text a friend to make them smile, while still being sincere.
                Avoid plain therapy language that could fit any tone.
                If the line could also pass for calm or grateful, it is not playful enough.
                Examples of the energy: “My tired soul deserves first-class rest.” “I give my inner child the aux cord today.” “I let this moment sparkle a little on purpose.”
                """
            case .grateful:
                return "Name something quietly good or worth noticing instead of saying gratitude in abstract terms."
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
                "I meet \(focus) with clear trust in myself.",
                "I move through \(focus) with steady conviction.",
                "I let \(focus) show me how capable I already am."
            ].randomElement()!
        }

        private static func playfulTag(for focus: String) -> String {
            [
                "I let \(focus) be a little lighter and a lot more alive.",
                "I bring sparkle, softness, and a tiny wink to \(focus).",
                "\(focus.capitalized) gets the confetti version of me today."
            ].randomElement()!
        }

        private static func gratefulTag(for focus: String) -> String {
            [
                "I notice the quiet goodness tucked inside \(focus).",
                "I let \(focus) remind me what is already here to cherish.",
                "\(focus.capitalized) becomes softer when I meet it with gratitude."
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
        • Avoid generic filler like “I am enough” or “I believe in myself” unless the prompt clearly calls for it.
        • Make the line feel tailored to the theme by using a concrete emotional lens, image, memory, or sensory detail.
        • Tone goal: \(tone.instructionsQualifier) \(tone.styleGuidance)
        """
    }
#endif

    static func prompt(for theme: String?, tone: AffirmationGenerator.Tone) -> String {
        guard let trimmed = sanitized(theme) else {
            return """
            Write one short (≤18 words) present-tense affirmation reinforcing self-belief, \(tone.promptQualifier).
            Make it vivid and specific instead of generic.
            \(tone.extraPromptDirections)
            """
        }

        let guidance = themeGuidance(for: trimmed)
        let thematicBrief = guidance.map {
            "Theme details: \($0.focus). Imagery to lean on: \($0.imagery). Avoid: \($0.avoidance)."
        } ?? "Translate the theme into a concrete emotional lens or lived image instead of using broad motivational language."

        let optionalAnchor = guidance.map { "Useful direction: \($0.anchorExample)" } ?? ""
        let toneSpecificGuidance = toneSpecificGuidance(for: trimmed, tone: tone)

        return """
        Write one short (≤18 words) present-tense affirmation about \(trimmed) that stays first-person and specific, \(tone.promptQualifier).
        \(thematicBrief)
        \(optionalAnchor)
        \(toneSpecificGuidance)
        \(tone.extraPromptDirections)
        """
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

    private static func toneSpecificGuidance(for theme: String, tone: AffirmationGenerator.Tone) -> String {
        let normalized = theme.lowercased()

        switch tone {
        case .playful:
            if ["tired", "fatigue", "burnout", "exhaust", "rest"].contains(where: normalized.contains) {
                return """
                For a playful take on tiredness, use cozy or funny rest imagery: blankets, soft landings, low-battery humor, naps, pajamas, dimmer switches, hibernation, or a gentle soft-reboot feeling.
                Avoid wellness clichés like “rest and recharge,” “embrace my tired body,” or anything that sounds like generic self-care copy.
                """
            }
            if ["nostalg", "childhood", "inner child", "memory"].contains(where: normalized.contains) {
                return """
                For playful nostalgia, lean into younger-self delight: stickers, cassette tapes, tree forts, snack breaks, glitter pens, or bike-riding freedom.
                """
            }
            return ""
        case .calm, .confident, .grateful:
            return ""
        }
    }

    private static func isTooGenericPlayful(_ text: String) -> Bool {
        let normalized = text.lowercased()
        let bannedPhrases = [
            "rest and recharge",
            "embrace my tired body",
            "trusting it to rest",
            "i trust myself to rest",
            "i allow myself to rest",
            "i give myself permission to rest",
            "i honor my need for rest",
            "i embrace",
            "i trust",
            "i allow"
        ]

        if bannedPhrases.contains(where: normalized.contains) {
            return true
        }

        let playfulSignals = [
            "sparkle", "confetti", "glitter", "wink", "aux", "pajama", "blanket",
            "nap", "soft reboot", "battery", "hibernate", "snack", "sticker"
        ]
        return !playfulSignals.contains(where: normalized.contains)
    }

    private static func themeGuidance(for theme: String) -> ThemeGuidance? {
        let normalized = theme.lowercased()

        let guidanceMap: [(keywords: [String], guidance: ThemeGuidance)] = [
            (
                ["nostalg", "childhood", "inner child", "memory", "younger self"],
                ThemeGuidance(
                    focus: "Let it feel tender and reflective, like reconnecting with a younger version of yourself.",
                    imagery: "childhood rooms, old songs, familiar scents, keepsakes, playground light, family rituals",
                    avoidance: "generic confidence slogans with no sense of memory or emotional warmth",
                    anchorExample: "Nostalgic should feel like healing through remembered softness, not just positivity."
                )
            ),
            (
                ["grief", "loss", "mourning"],
                ThemeGuidance(
                    focus: "Make space for sadness and continued love without trying to erase the ache.",
                    imagery: "held memories, quiet rituals, carrying love forward, soft strength",
                    avoidance: "forced silver linings or language that rushes someone past pain",
                    anchorExample: "The line should feel comforting and steady, not like a command to move on."
                )
            ),
            (
                ["anxious", "anxiety", "panic", "overwhelm", "stressed"],
                ThemeGuidance(
                    focus: "Ground the affirmation in safety, the body, and returning to the present moment.",
                    imagery: "breath, feet on the floor, steady hands, slowing down, softened shoulders",
                    avoidance: "abstract platitudes that ignore the physical experience of anxiety",
                    anchorExample: "It should sound usable in the middle of a tense moment."
                )
            ),
            (
                ["burnout", "exhaust", "tired", "rest", "fatigue"],
                ThemeGuidance(
                    focus: "Center permission, gentleness, and worth that does not depend on productivity.",
                    imagery: "rest, unclenching, quiet mornings, recovery, lighter pace",
                    avoidance: "hustle language or anything that sounds like a pep talk to keep pushing",
                    anchorExample: "The line should help someone soften, not perform harder."
                )
            ),
            (
                ["lonely", "alone", "isolated", "belong"],
                ThemeGuidance(
                    focus: "Emphasize belonging, being held in the world, and connection that can still be felt.",
                    imagery: "warmth, being welcomed, open doors, chosen people, quiet companionship",
                    avoidance: "statements that deny loneliness instead of meeting it honestly",
                    anchorExample: "The line should feel companioning and reassuring."
                )
            ),
            (
                ["transition", "change", "new chapter", "uncertain", "unknown"],
                ThemeGuidance(
                    focus: "Frame the affirmation around crossing a threshold with steadiness and trust.",
                    imagery: "doorways, bridges, unfolding paths, new seasons, first steps",
                    avoidance: "vague encouragement with no sense of movement or change",
                    anchorExample: "The line should feel like support during a real life shift."
                )
            ),
            (
                ["heartbreak", "breakup", "healing"],
                ThemeGuidance(
                    focus: "Center self-return, tenderness, and rebuilding trust in your own heart.",
                    imagery: "mending, coming home to yourself, soft courage, tenderness",
                    avoidance: "revenge energy or clichés about instantly being over it",
                    anchorExample: "The line should feel restorative and intimate."
                )
            ),
            (
                ["confidence", "bold", "courage", "brave"],
                ThemeGuidance(
                    focus: "Make it feel embodied and active, like someone stepping fully into their own voice.",
                    imagery: "clear posture, steady eye contact, strong steps, owning space",
                    avoidance: "empty boss-language or generic hype with no emotional center",
                    anchorExample: "Confidence should sound self-possessed, not performative."
                )
            ),
            (
                ["creative", "artist", "writing", "music", "design"],
                ThemeGuidance(
                    focus: "Support original expression and trusting your own creative instincts.",
                    imagery: "making, shaping, sketching, rhythm, color, unfinished drafts becoming something",
                    avoidance: "productivity language that strips out play or experimentation",
                    anchorExample: "The line should feel generative and alive."
                )
            )
        ]

        for entry in guidanceMap where entry.keywords.contains(where: normalized.contains) {
            return entry.guidance
        }

        return nil
    }
}

private struct ThemeGuidance {
    let focus: String
    let imagery: String
    let avoidance: String
    let anchorExample: String
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
        let firstPass = postprocess(response.content)

        guard tone == .playful, Self.isTooGenericPlayful(firstPass) else {
            return firstPass
        }

        let retryPrompt = """
        Rewrite this so it is unmistakably playful and specific, not calm or therapeutic:
        \(firstPass)

        Requirements:
        - keep it first-person and 8–18 words
        - include one whimsical image, mischievous metaphor, or lightly clever phrase
        - do not use generic rest language like "rest and recharge"
        - keep it sincere, not sarcastic
        Theme: \(sanitized(theme) ?? "none")
        """

        let retryResponse = try await session.respond(to: retryPrompt, options: options)
        return postprocess(retryResponse.content)
    }
}
#endif
