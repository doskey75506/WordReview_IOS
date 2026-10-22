import XCTest
@testable import WordReviewKit

/// Port of the Python repo's `test_wrong_entries.py`: cleanup, rebuild and
/// round-trip behaviour of the wrong-answer CSV store.
final class WrongStoreTests: XCTestCase {
    var tmpDir: URL!
    var fileURL: URL!
    var store: WrongStore!

    let headerRow = wrongHeader.joined(separator: ",")
    let goodOne = "2026-09-16 10:05:00,spelling,English,French,grand,big,gros"
    let goodTwo = "2026-10-01 09:00:00,dictation,English,French,hello,bonjour,banojour"

    let malformedRows = [
        "too,few",
        "2026-09-16 10:05:00,spelling,English,French,a,b,c,extra",
        "not-a-time,spelling,English,French,a,b,c",
        "2026-09-16 10:05:00,Reading,English,French,a,b,c",
        "2026-09-16 10:05:00,spelling,English,German,a,b,c",
        "2026-09-16 10:05:00,spelling,,French,a,b,c",
        "2026-09-16 10:05:00,spelling,English,French,a,,c",
    ]

    override func setUpWithError() throws {
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordreview-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        fileURL = tmpDir.appendingPathComponent("Data").appendingPathComponent("Wrong.csv")
        store = WrongStore(fileURL: fileURL, relativeTo: tmpDir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func writeRaw(_ text: String) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(text.utf8).write(to: fileURL)
    }

    func diskRows() throws -> [[String]] {
        let data = try Data(contentsOf: fileURL)
        let text = decodeCSVText(data) ?? ""
        return parseCSVRows(text)
    }

    func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return calendar.date(from: components)!
    }

    // --- rebuild from zero -------------------------------------------------

    func testMissingFileReadsEmptyWithoutCreatingIt() throws {
        XCTAssertEqual(store.load(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testEmptiedFileIsRebuiltWithHeaderOnly() throws {
        try writeRaw("")
        XCTAssertEqual(store.load(), [])
        XCTAssertEqual(try diskRows(), [wrongHeader])
    }

    func testWriteCreatesMissingParentDirectories() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.deletingLastPathComponent().path))
        let entry = WrongEntry(
            when: makeDate(2026, 10, 6, 12, 0, 0),
            kind: "spelling",
            primaryLanguage: "English",
            secondaryLanguage: "French",
            primaryText: "is",
            expected: "est",
            given: "wrong"
        )
        try store.write([entry])
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(store.load(), [entry])
    }

    func testNewFileStartsWithUTF8BOM() throws {
        try store.write([])
        XCTAssertEqual(Array(try Data(contentsOf: fileURL).prefix(3)), [0xEF, 0xBB, 0xBF])
    }

    // --- cleanup of malformed rows ----------------------------------------

    func testLegacyFiveColumnRowsArePurged() throws {
        try writeRaw(
            "Practice time,Practice type,Primary text,Correct answer,User answer\n"
                + "2026-09-16 10:05:00,spelling,grand,big,\n"
        )
        XCTAssertEqual(store.load(), [])
        XCTAssertEqual(try diskRows(), [wrongHeader])
    }

    func testMalformedRowsAreDroppedAndValidRowsKeptVerbatim() throws {
        let text = ([headerRow, goodOne] + malformedRows + [goodTwo]).joined(separator: "\n") + "\n"
        try writeRaw(text)
        let entries = store.load()
        XCTAssertEqual(entries.map(\.primaryText), ["grand", "hello"])
        XCTAssertEqual(
            try diskRows(),
            [wrongHeader, goodOne.split(separator: ",").map(String.init), goodTwo.split(separator: ",").map(String.init)]
        )
    }

    func testMissingHeaderIsRestoredKeepingValidRows() throws {
        try writeRaw(goodOne + "\n")
        let entries = store.load()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].expected, "big")
        XCTAssertEqual(try diskRows(), [wrongHeader, goodOne.split(separator: ",").map(String.init)])
    }

    func testCaseVariantKindAndBlankUserAnswerAreValid() throws {
        try writeRaw(headerRow + "\n2026-09-16 10:05:00,dictation,English,French,hello,bonjour,\n")
        let entries = store.load()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].given, "")
    }

    // --- hand edits and round-trips ----------------------------------------

    func testValidHandEditedRowSurvivesUnchanged() throws {
        try writeRaw(headerRow + "\n" + goodOne + "\n")
        let entries = store.load()
        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.when, makeDate(2026, 9, 16, 10, 5, 0))
        XCTAssertEqual(entry.kind, "spelling")
        XCTAssertEqual(entry.primaryLanguage, "English")
        XCTAssertEqual(entry.secondaryLanguage, "French")
        XCTAssertEqual(entry.primaryText, "grand")
        XCTAssertEqual(entry.expected, "big")
        XCTAssertEqual(entry.given, "gros")
    }

    func testCleanFileIsNotRewrittenOnLoad() throws {
        try writeRaw(headerRow + "\n" + goodOne + "\n")
        let past = Date(timeIntervalSince1970: 1_000_000_000)
        try FileManager.default.setAttributes([.modificationDate: past], ofItemAtPath: fileURL.path)
        _ = store.load()
        let after = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date
        XCTAssertEqual(after, past)
    }

    func testRoundTripPreservesEveryField() throws {
        let entry = WrongEntry(
            when: makeDate(2026, 10, 6, 9, 30, 15),
            kind: "spelling",
            primaryLanguage: "French",
            secondaryLanguage: "English",
            primaryText: "bonjour",
            expected: "hello",
            given: "hi"
        )
        try store.write([entry])
        XCTAssertEqual(store.load(), [entry])
    }

    func testFieldsContainingCommasSurviveRoundTrip() throws {
        let entry = WrongEntry(
            when: makeDate(2026, 10, 6, 9, 30, 15),
            kind: "spelling",
            primaryLanguage: "English",
            secondaryLanguage: "Chinese",
            primaryText: "hello, world",
            expected: "你好，世界",
            given: "wrong"
        )
        try store.write([entry])
        XCTAssertEqual(store.load(), [entry])
    }

    func testLabelIsRelativeToBaseAndFallsBackToFullPathOutside() throws {
        XCTAssertEqual(store.label, "Data/Wrong.csv")
        let outside = WrongStore(
            fileURL: URL(fileURLWithPath: "/tmp/other/Wrong.csv"),
            relativeTo: tmpDir
        )
        XCTAssertEqual(outside.label, "/tmp/other/Wrong.csv")
    }

    func testTimestampParsingRejectsGarbageAndAcceptsOurFormat() {
        XCTAssertNotNil(WrongStore.parseTimestamp("2026-09-16 10:05:00"))
        XCTAssertNotNil(WrongStore.parseTimestamp("2026-9-6 1:5:0"))
        XCTAssertNil(WrongStore.parseTimestamp("not-a-time"))
        XCTAssertNil(WrongStore.parseTimestamp("2026-09-16 10:05:00 extra"))
        XCTAssertNil(WrongStore.parseTimestamp("2026-13-16 10:05:00"))
        XCTAssertNil(WrongStore.parseTimestamp("2026-02-30 10:05:00"))
        XCTAssertNil(WrongStore.parseTimestamp("2026-09-16 25:05:00"))
    }
}
