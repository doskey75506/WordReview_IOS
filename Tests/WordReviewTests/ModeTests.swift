import XCTest
@testable import WordReviewKit

/// The shared mode interface (`dictation.py` / `spelling.py`) and labels.
final class ModeTests: XCTestCase {
    func testDictationViewWithListenHint() {
        let view = DictationMode.shared.view(
            primaryLanguage: "English",
            secondaryLanguage: "French",
            primaryText: "is",
            listenHint: true
        )
        XCTAssertEqual(view.prompt, "French dictation")
        XCTAssertEqual(
            view.display,
            "Listen to the French pronunciation, then type the French text."
        )
        XCTAssertEqual(
            view.instruction,
            "Based on the French pronunciation, write the French text:"
        )
    }

    func testDictationViewDuringReviewHasNoDisplay() {
        let view = DictationMode.shared.view(
            primaryLanguage: "English",
            secondaryLanguage: "French",
            primaryText: "is",
            listenHint: false
        )
        XCTAssertEqual(view.display, "")
    }

    func testSpellingViewShowsPrimaryText() {
        let view = SpellingMode.shared.view(
            primaryLanguage: "English",
            secondaryLanguage: "French",
            primaryText: "is",
            listenHint: true
        )
        XCTAssertEqual(view.prompt, "English text")
        XCTAssertEqual(view.display, "is")
        XCTAssertEqual(view.instruction, "Based on the English text, write the French text:")
    }

    func testRecordKindsAreTheExactWrongCsvValues() {
        XCTAssertEqual(DictationMode.shared.recordKind, "Dictation")
        XCTAssertEqual(SpellingMode.shared.recordKind, "spelling")
        XCTAssertEqual(DictationMode.shared.name, "Dictation")
        XCTAssertEqual(SpellingMode.shared.name, "Spelling Practice")
        XCTAssertTrue(DictationMode.shared.autoPlay)
        XCTAssertFalse(SpellingMode.shared.autoPlay)
    }

    func testModeForRecordKind() {
        XCTAssertEqual(mode(forRecordKind: "Dictation").name, "Dictation")
        XCTAssertEqual(mode(forRecordKind: "dictation").name, "Dictation")
        XCTAssertEqual(mode(forRecordKind: "spelling").name, "Spelling Practice")
        XCTAssertEqual(mode(forRecordKind: "SPELLING").name, "Spelling Practice")
        // Parity with Python: the kind is compared without trimming, so a
        // hand-edited padded kind falls through to the spelling view.
        XCTAssertEqual(mode(forRecordKind: " Dictation ").name, "Spelling Practice")
    }

    func testLanguageLabel() {
        let entry = WrongEntry(
            when: nil,
            kind: "spelling",
            primaryLanguage: "English",
            secondaryLanguage: "French",
            primaryText: "a",
            expected: "b",
            given: "c"
        )
        XCTAssertEqual(languageLabel(entry), "English → French")
        let unknown = WrongEntry(
            when: nil,
            kind: "spelling",
            primaryLanguage: "",
            secondaryLanguage: "French",
            primaryText: "a",
            expected: "b",
            given: "c"
        )
        XCTAssertEqual(languageLabel(unknown), "Unknown")
    }

    func testCanonicalLanguage() throws {
        XCTAssertEqual(try canonicalLanguage(" english "), "English")
        XCTAssertEqual(try canonicalLanguage("CHINESE"), "Chinese")
        XCTAssertThrowsError(try canonicalLanguage("German")) { error in
            XCTAssertEqual(error as? LanguageError, .unsupported("German"))
            XCTAssertEqual(
                (error as? LanguageError)?.description,
                "Unsupported language 'German'. Use one of: Chinese, French, Spanish, English."
            )
        }
    }
}
