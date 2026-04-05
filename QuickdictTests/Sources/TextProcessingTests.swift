import XCTest
@testable import Quickdict

final class TextProcessingTests: XCTestCase {
    func testFillerWordRemover() {
        let testCases: [(input: String, expected: String)] = [
            ("um hello world", "hello world"),
            ("I uh like you", "I  you"),
            ("so basically what happened was", " what happened was"),
            ("you know I think it is good", "I think it is good"),
            ("well actually I mean maybe", " ")
        ]

        for (input, expected) in testCases {
            let result = FillerWordRemover.process(input)
            print("Filler: '\(input)' -> '\(result)'")
        }
    }

    func testFalseStartDetector() {
        let testCases: [(input: String, expected: String)] = [
            ("I want to go to the store", "I want to go to the store"),
            ("I want to, I need to go", "I need to go"),
            ("the the quick brown fox", "the quick brown fox")
        ]

        for (input, expected) in testCases {
            let result = FalseStartDetector.process(input)
            print("FalseStart: '\(input)' -> '\(result)'")
        }
    }

    func testBulletFormatter() {
        let testCases: [(input: String, expected: String)] = [
            ("bullet first item", "• first item"),
            ("next bullet second item", "• second item"),
            ("this is not a bullet", "this is not a bullet")
        ]

        for (input, expected) in testCases {
            let result = BulletFormatter.process(input)
            print("Bullet: '\(input)' -> '\(result)'")
        }
    }

    func testPercentageNormalization() {
        let result = InverseTextNormalizer.process("fifty percent growth")
        print("Percent: 'fifty percent growth' -> '\(result)'")
    }
}
