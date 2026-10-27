import Foundation
import Testing

@testable import Koda

@Suite("Recipe link platform detection")
struct RecipeLinkPlatformTests {
    @Test(
        "Recognises the platform and the account of short-video links",
        arguments: [
            ("https://www.tiktok.com/@cocinaconana/video/7301234567890", RecipeLinkPlatform.tiktok, "@cocinaconana"),
            ("https://vm.tiktok.com/ZMabc123/", .tiktok, nil),
            ("https://m.tiktok.com/@koda/video/1?lang=es", .tiktok, "@koda"),
            ("https://www.instagram.com/reel/C1a2B3c4D5e/", .instagram, nil),
            ("https://instagram.com/p/C1a2B3c4D5e/?igsh=abc", .instagram, nil),
            ("https://www.instagram.com/recetasdelaabuela/reel/C1a2B3c4D5e/", .instagram, "@recetasdelaabuela"),
            ("https://youtube.com/shorts/aBcD1234xyz", .youtube, nil),
            ("https://m.youtube.com/shorts/aBcD1234xyz?feature=share", .youtube, nil),
            ("https://youtu.be/aBcD1234xyz", .youtube, nil),
            ("https://www.youtube.com/@chefkoda/shorts", .youtube, "@chefkoda"),
            ("https://www.directoalpaladar.com/recetas/arroz", .other, nil),
        ] as [(String, RecipeLinkPlatform, String?)]
    )
    func detectsPlatform(text: String, platform: RecipeLinkPlatform, account: String?) throws {
        let info = try #require(RecipeLinkPlatform.detect(url: text))
        #expect(info.platform == platform)
        #expect(info.account == account)
    }

    @Test("Trims whitespace and finds the link inside pasted text")
    func extractsFromText() throws {
        let pasted = "  Mira esta receta 😋 https://vm.tiktok.com/ZMabc123/. ¡Qué buena!\n"
        let info = try #require(RecipeLinkPlatform.detect(url: pasted))
        #expect(info.url.absoluteString == "https://vm.tiktok.com/ZMabc123/")
        #expect(info.platform == .tiktok)

        let wrapped = try #require(RecipeLinkPlatform.detect(url: "(https://youtu.be/aBcD1234xyz)"))
        #expect(wrapped.url.absoluteString == "https://youtu.be/aBcD1234xyz")

        let trimmed = try #require(RecipeLinkPlatform.detect(url: "\n https://www.instagram.com/reel/C1a2/ \t"))
        #expect(trimmed.platform == .instagram)
    }

    @Test("Accepts known hosts pasted without a scheme")
    func knownHostWithoutScheme() throws {
        let info = try #require(RecipeLinkPlatform.detect(url: "tiktok.com/@koda/video/1"))
        #expect(info.url.absoluteString == "https://tiktok.com/@koda/video/1")
        #expect(info.account == "@koda")
    }

    @Test(
        "Rejects text without a valid http(s) URL",
        arguments: [
            "", "   ", "hola", "ftp://tiktok.com/@koda", "https://", "javascript:alert(1)", "example.com/receta",
        ]
    )
    func rejectsInvalid(text: String) {
        #expect(RecipeLinkPlatform.detect(url: text) == nil)
    }

    @Test("Rejects URLs longer than the backend allows")
    func rejectsTooLong() {
        let long = "https://example.com/" + String(repeating: "a", count: RecipeLinkPlatform.maxURLLength)
        #expect(RecipeLinkPlatform.detect(url: long) == nil)
    }

    @Test("The source names the host, or the shorts feed on YouTube")
    func source() throws {
        #expect(
            try #require(RecipeLinkPlatform.detect(url: "https://youtube.com/shorts/x")).source == "youtube.com/shorts"
        )
        #expect(try #require(RecipeLinkPlatform.detect(url: "https://www.blog.es/receta")).source == "blog.es")
    }
}
