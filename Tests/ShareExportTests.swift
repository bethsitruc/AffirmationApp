import AffirmationShared
import SwiftUI
import Testing
import UIKit
@testable import AffirmationApp

extension GroundedTests {
    @MainActor
    @Suite("Share image export")
    struct ShareExportTests {
        @Test("Long-text exports produce decodable PNG images in every theme, with and without branding",
              arguments: AffirmationColorTheme.allCases, [false, true])
        func exports(theme: AffirmationColorTheme, badge: Bool) throws {
            let long = String(repeating: "I honor my progress and make room for rest. ", count: 12)
            let image = try #require(ShareCardRenderer.image(
                affirmation: Affirmation(text: long), theme: theme, font: .serif, includeBadge: badge, scale: 1
            ))
            #expect(image.size == CGSize(width: 1200, height: 900))
            let png = try #require(image.pngData())
            #expect(png.count > 1000)
            let decoded = try #require(UIImage(data: png)?.cgImage)
            #expect(decoded.width == 1200 && decoded.height == 900)
        }
    }
}
