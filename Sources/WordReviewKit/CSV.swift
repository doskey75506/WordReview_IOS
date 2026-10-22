import Foundation

public enum ExerciseCSVError: Error, CustomStringConvertible, Equatable {
    case emptyFile
    case missingLanguages
    case invalidLanguage(String)
    case rowTooShort(Int)
    case rowEmptyCell(Int)
    case noExercises
    case notUTF8

    public var description: String {
        switch self {
        case .emptyFile:
            return "The CSV file is empty."
        case .missingLanguages:
            return "The first row must name the languages of both columns."
        case .invalidLanguage(let value):
            return LanguageError.unsupported(value).description
        case .rowTooShort(let row):
            return "Row \(row) has fewer than two columns."
        case .rowEmptyCell(let row):
            return "Row \(row) has an empty source or spelling."
        case .noExercises:
            return "The CSV file contains no exercises."
        case .notUTF8:
            return "The file could not be decoded as UTF-8 text."
        }
    }
}

/// Minimal RFC 4180 parser matching Python's `csv.reader` default dialect:
/// comma separator, `"` quoting with `""` escapes, embedded newlines,
/// unterminated quotes run to end of input. Whitespace around unquoted
/// fields is preserved.
public func parseCSVRows(_ text: String) -> [[String]] {
    var rows: [[String]] = []
    var row: [String] = []
    var field = ""
    var inQuotes = false
    var index = text.startIndex
    while index < text.endIndex {
        let char = text[index]
        if inQuotes {
            if char == "\"" {
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "\"" {
                    field.append("\"")
                    index = text.index(after: next)
                    continue
                }
                inQuotes = false
            } else {
                field.append(char)
            }
        } else if char == "\"" && field.isEmpty {
            // Quotes only open a quoted field at field start; elsewhere they are literal.
            inQuotes = true
        } else if char == "," {
            row.append(field)
            field = ""
        } else if char == "\n" || char == "\r" || char == "\r\n" {
            // "\r\n" is a single grapheme cluster in Swift, so one check covers CRLF.
            row.append(field)
            rows.append(row)
            row = []
            field = ""
        } else {
            field.append(char)
        }
        index = text.index(after: index)
    }
    if !field.isEmpty || !row.isEmpty {
        row.append(field)
        rows.append(row)
    }
    return rows
}

/// Decode CSV bytes as UTF-8, dropping a leading BOM (Python reads with `utf-8-sig`).
public func decodeCSVText(_ data: Data) -> String? {
    guard let text = String(data: data, encoding: .utf8) else { return nil }
    return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
}

/// One RFC 4180 row with minimal quoting, CRLF terminator by default
/// (Python `csv.writer` defaults). Shared by the wrong-answer store and the
/// word-list editor so everything the app writes round-trips through
/// `loadExercises`.
public func csvLine(_ fields: [String], terminator: String = "\r\n") -> String {
    let line = fields.map { field -> String in
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }.joined(separator: ",")
    return line + terminator
}

/// Read a two-column CSV whose first row names the two languages
/// (Python `files.load_exercises`).
public func loadExercises(from data: Data) throws -> ([Exercise], (String, String)) {
    guard let text = decodeCSVText(data) else {
        throw ExerciseCSVError.notUTF8
    }
    let rows = parseCSVRows(text)
    guard let header = rows.first else {
        throw ExerciseCSVError.emptyFile
    }
    guard header.count >= 2 else {
        throw ExerciseCSVError.missingLanguages
    }
    let languages: (String, String)
    do {
        languages = (try canonicalLanguage(header[0]), try canonicalLanguage(header[1]))
    } catch let error as LanguageError {
        switch error {
        case .unsupported(let value):
            throw ExerciseCSVError.invalidLanguage(value)
        }
    }
    var exercises: [Exercise] = []
    for (offset, row) in rows.dropFirst().enumerated() {
        let rowNumber = offset + 2
        if row.isEmpty || !row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            continue
        }
        guard row.count >= 2 else {
            throw ExerciseCSVError.rowTooShort(rowNumber)
        }
        let source = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let spelling = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
        if source.isEmpty || spelling.isEmpty {
            throw ExerciseCSVError.rowEmptyCell(rowNumber)
        }
        exercises.append(Exercise(source: source, spelling: spelling))
    }
    guard !exercises.isEmpty else {
        throw ExerciseCSVError.noExercises
    }
    return (exercises, languages)
}
