import Foundation
import Testing
@testable import CommonMark

/// Runs every example of the CommonMark 0.31.2 specification against the strict pipeline.
struct CommonMarkSpecTests {
    struct Example: Decodable, CustomTestStringConvertible, Sendable {
        let markdown: String
        let html: String
        let example: Int
        let section: String

        var testDescription: String { "#\(example) \(section)" }
    }

    static let examples: [Example] = {
        let data = try! Data(contentsOf: SharedFiles.spec.appendingPathComponent("commonmark-0.31.2.json"))
        return try! JSONDecoder().decode([Example].self, from: data)
    }()

    @Test func specificationHasAllExamples() {
        #expect(Self.examples.count == 652)
    }

    @Test(arguments: examples)
    func exampleRendersAsSpecified(_ example: Example) {
        #expect(SpecHTML.normalize(MarkdownPipeline.commonMark.renderHTML(example.markdown)) == SpecHTML.normalize(example.html))
    }
}
