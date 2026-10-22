import XCTest
@testable import WordReviewKit

/// Answer checking and range selection (`models.py`).
final class AnswerTests: XCTestCase {
    func testNormaliseTrimsCollapsesAndLowercases() {
        XCTAssertEqual(normalise("  To   BE\t now "), "to be now")
        XCTAssertEqual(normalise(""), "")
        XCTAssertEqual(normalise("你好"), "你好")
    }

    func testCaseInsensitiveAndWhitespaceInsensitiveComparison() {
        XCTAssertTrue(isCorrectAnswer(given: "EST", expected: "est", allowAlternatives: true))
        XCTAssertTrue(isCorrectAnswer(given: " to   be ", expected: "to be", allowAlternatives: true))
    }

    func testAccentsAreNotStripped() {
        XCTAssertFalse(isCorrectAnswer(given: "francais", expected: "français", allowAlternatives: true))
        XCTAssertTrue(isCorrectAnswer(given: "français", expected: "français", allowAlternatives: true))
    }

    func testPipeAlternativesAsciiAndFullWidth() {
        XCTAssertTrue(isCorrectAnswer(given: "being", expected: "to be|being", allowAlternatives: true))
        XCTAssertTrue(isCorrectAnswer(given: "to be", expected: "to be|being", allowAlternatives: true))
        XCTAssertTrue(isCorrectAnswer(given: "您好", expected: "你好｜您好", allowAlternatives: true))
        XCTAssertFalse(isCorrectAnswer(given: "to", expected: "to be|being", allowAlternatives: true))
    }

    func testAlternativesOnlyApplyWhenAllowed() {
        XCTAssertFalse(isCorrectAnswer(given: "a", expected: "a|b", allowAlternatives: false))
        XCTAssertTrue(isCorrectAnswer(given: "a|b", expected: "a|b", allowAlternatives: false))
    }

    func testEmptyAnswerMatchesEmptyAlternative() {
        XCTAssertTrue(isCorrectAnswer(given: "", expected: "a|", allowAlternatives: true))
        XCTAssertFalse(isCorrectAnswer(given: "", expected: "a", allowAlternatives: true))
    }

    func testChineseCharactersCompareExactly() {
        XCTAssertTrue(isCorrectAnswer(given: "你好", expected: "你好", allowAlternatives: true))
        XCTAssertFalse(isCorrectAnswer(given: "您好", expected: "你好", allowAlternatives: true))
    }

    func testRangeSelection() throws {
        let exercises = (1...5).map { Exercise(source: "s\($0)", spelling: "p\($0)") }
        XCTAssertEqual(
            try selectExerciseRange(exercises, start: 2, end: 3),
            [exercises[1], exercises[2]]
        )
        XCTAssertEqual(try selectExerciseRange(exercises, start: 1, end: 5), exercises)

        for (start, end) in [(0, 5), (3, 2), (1, 6), (0, 0)] {
            XCTAssertThrowsError(try selectExerciseRange(exercises, start: start, end: end)) { error in
                XCTAssertEqual(error as? RangeError, .invalid(5))
                XCTAssertEqual((error as? RangeError)?.description, "Choose a valid range from 1 to 5.")
            }
        }
    }
}
