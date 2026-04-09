import XCTest
@testable import Quickdict

final class TextProcessingTests: XCTestCase {
    func testFillerWordRemoverStripsCommonFillers() {
        XCTAssertEqual(FillerWordRemover.process("um hello world"), "hello world")
        XCTAssertEqual(FillerWordRemover.process("you know I think it is good"), "I think it is good")
        XCTAssertEqual(FillerWordRemover.process("well actually I mean maybe"), "")
    }

    func testFalseStartDetectorRemovesRepeatedLeadIn() {
        XCTAssertEqual(FalseStartDetector.process("the the quick brown fox"), "the quick brown fox")
        XCTAssertEqual(FalseStartDetector.process("I want to go to the store"), "I want to go to the store")
    }

    func testNumberConversionHandlesNumbersCurrencyAndPercentages() {
        XCTAssertEqual(InverseTextNormalizer.process("twenty three dollars"), "$23")
        XCTAssertEqual(InverseTextNormalizer.process("forty two percent growth"), "42% growth")
        XCTAssertEqual(InverseTextNormalizer.process("one hundred twenty five"), "125")
    }

    func testBulletFormatterHandlesSpokenBulletTriggers() {
        let input = "bullet bananas next bullet peanuts next bullet apples"
        let expected = "• Bananas\n• Peanuts\n• Apples"
        XCTAssertEqual(BulletFormatter.process(input), expected)
    }

    func testBulletFormatterConvertsSimpleNumberedListToBullets() {
        let input = "1 bananas 2 peanuts 3 apples"
        let expected = "• Bananas\n• Peanuts\n• Apples"
        XCTAssertEqual(BulletFormatter.process(input), expected)
    }

    func testBulletFormatterConvertsShoppingSentenceToBullets() {
        let input = "I'm gonna go to the grocery store to get some bananas, peanuts, apples, potatoes."
        let expected = "• Bananas\n• Peanuts\n• Apples\n• Potatoes"
        XCTAssertEqual(BulletFormatter.process(input), expected)
    }

    func testBulletFormatterSplitsSpokenTodoSeparators() {
        let input = "I need to do workout also homework also finalize the contract"
        let expected = "• Workout\n• Homework\n• Finalize the contract"
        XCTAssertEqual(BulletFormatter.process(input), expected)
    }

    func testBulletFormatterSupportsMultilingualListCue() {
        let input = "lista de compras leche, huevos, pan"
        let expected = "• Leche\n• Huevos\n• Pan"
        XCTAssertEqual(BulletFormatter.process(input), expected)
    }
}
