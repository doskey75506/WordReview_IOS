import XCTest
@testable import WordReviewKit

/// Port of the exercise-CSV contract from `files.load_exercises` + README.
final class CSVTests: XCTestCase {
    var exampleData: Data {
        Data("English,French\nis,est\nFrench,français\nI,je\nhe,il\n".utf8)
    }

    func testExampleFileLoadsFourExercises() throws {
        let (exercises, languages) = try loadExercises(from: exampleData)
        XCTAssertEqual(languages.0, "English")
        XCTAssertEqual(languages.1, "French")
        XCTAssertEqual(exercises.count, 4)
        XCTAssertEqual(exercises[0], Exercise(source: "is", spelling: "est"))
        XCTAssertEqual(exercises[1], Exercise(source: "French", spelling: "français"))
    }

    func testBOMIsStrippedLikeUtf8Sig() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(exampleData)
        let (exercises, _) = try loadExercises(from: data)
        XCTAssertEqual(exercises.count, 4)
    }

    func testHeaderLanguageNamesAreCaseInsensitive() throws {
        let data = Data("english,FRENCH\nis,est\n".utf8)
        let (_, languages) = try loadExercises(from: data)
        XCTAssertEqual(languages.0, "English")
        XCTAssertEqual(languages.1, "French")
    }

    func testCellsAreTrimmedAndBlankRowsSkippedWithoutConsumingRowNumbers() throws {
        let data = Data("English,French\n  is  ,  est  \n\n,,\nI,je\n".utf8)
        let (exercises, _) = try loadExercises(from: data)
        XCTAssertEqual(exercises.map(\.source), ["is", "I"])
        XCTAssertThrowsError(try loadExercises(from: Data("English,French\n\nonlyone\n".utf8))) { error in
            XCTAssertEqual(error as? ExerciseCSVError, .rowTooShort(3))
        }
    }

    func testQuotedFieldsMayContainCommasAndExtraColumnsAreIgnored() throws {
        let data = Data("English,French\n\"hello, world\",\"grand, large\",extra\n".utf8)
        let (exercises, _) = try loadExercises(from: data)
        XCTAssertEqual(exercises, [Exercise(source: "hello, world", spelling: "grand, large")])
    }

    /// The serializer the editor and WrongStore share must always produce a
    /// file that `loadExercises` accepts (BOM + quoting + CRLF round-trip).
    func testCsvLineSerializationRoundTripsThroughLoader() throws {
        var text = "\u{FEFF}"
        text += csvLine(["English", "Chinese"])
        text += csvLine(["hello, world", "said \"hi\""])
        text += csvLine(["multi\nline", "正常"])
        let (exercises, languages) = try loadExercises(from: Data(text.utf8))
        XCTAssertEqual(languages.0, "English")
        XCTAssertEqual(languages.1, "Chinese")
        XCTAssertEqual(exercises, [
            Exercise(source: "hello, world", spelling: "said \"hi\""),
            Exercise(source: "multi\nline", spelling: "正常"),
        ])
    }

    func testValidationErrors() {
        XCTAssertThrowsError(try loadExercises(from: Data())) { error in
            XCTAssertEqual(error as? ExerciseCSVError, .emptyFile)
        }
        XCTAssertThrowsError(try loadExercises(from: Data("English\n".utf8))) { error in
            XCTAssertEqual(error as? ExerciseCSVError, .missingLanguages)
        }
        XCTAssertThrowsError(try loadExercises(from: Data("English,German\na,b\n".utf8))) { error in
            XCTAssertEqual(error as? ExerciseCSVError, .invalidLanguage("German"))
            XCTAssertEqual(
                (error as? ExerciseCSVError)?.description,
                "Unsupported language 'German'. Use one of: Chinese, French, Spanish, English."
            )
        }
        XCTAssertThrowsError(try loadExercises(from: Data("English,French\nis,\n".utf8))) { error in
            XCTAssertEqual(error as? ExerciseCSVError, .rowEmptyCell(2))
        }
        XCTAssertThrowsError(try loadExercises(from: Data("English,French\n".utf8))) { error in
            XCTAssertEqual(error as? ExerciseCSVError, .noExercises)
        }
        XCTAssertThrowsError(try loadExercises(from: Data("English,French\n,\n".utf8))) { error in
            XCTAssertEqual(error as? ExerciseCSVError, .noExercises)
        }
        XCTAssertThrowsError(try loadExercises(from: Data([0xFF, 0xFE, 0x41]))) { error in
            XCTAssertEqual(error as? ExerciseCSVError, .notUTF8)
        }
    }
}
