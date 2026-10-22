import Foundation

public let wrongHeader = [
    "Practice time",
    "Practice type",
    "Primary language",
    "Secondary language",
    "Primary text",
    "Correct answer",
    "User answer",
]

/// Hand-editable wrong-answer CSV store — the port of `files.py`
/// (`WRONG_FILE` / `load_wrong_entries` / `write_wrong_entries`).
///
/// `load()` tolerates hand edits: malformed rows are purged, a missing header
/// is restored, an emptied file is rebuilt, and the file is rewritten only
/// when something had to be cleaned. `write()` creates the parent directory
/// and prefixes new files with a UTF-8 BOM (Excel expects it — don't remove).
public struct WrongStore {
    public let fileURL: URL
    private let baseURL: URL?

    public init(fileURL: URL, relativeTo baseURL: URL? = nil) {
        self.fileURL = fileURL
        self.baseURL = baseURL
    }

    /// User-facing path for messages: relative to `baseURL` when possible
    /// (Python `wrong_file_label` shows `Resource/Data/Wrong.csv`).
    public var label: String {
        guard let baseURL else { return fileURL.path }
        let base = baseURL.standardizedFileURL.path
        let path = fileURL.standardizedFileURL.path
        if path.hasPrefix(base + "/") {
            return String(path.dropFirst(base.count + 1))
        }
        return path
    }

    public static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    /// Parse `%Y-%m-%d %H:%M:%S` strictly and fully (Python `parse_wrong_time`).
    public static func parseTimestamp(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"\A\d{4}-\d{1,2}-\d{1,2}\s+\d{1,2}:\d{1,2}:\d{1,2}\z"#
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
        guard parts.count == 2 else { return nil }
        let dateParts = parts[0].split(separator: "-").compactMap { Int($0) }
        let timeParts = parts[1].split(separator: ":").compactMap { Int($0) }
        guard dateParts.count == 3, timeParts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        var components = DateComponents()
        components.year = dateParts[0]
        components.month = dateParts[1]
        components.day = dateParts[2]
        components.hour = timeParts[0]
        components.minute = timeParts[1]
        components.second = timeParts[2]
        guard let date = calendar.date(from: components) else { return nil }
        let back = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard back.year == dateParts[0], back.month == dateParts[1], back.day == dateParts[2],
              back.hour == timeParts[0], back.minute == timeParts[1], back.second == timeParts[2]
        else { return nil }
        return date
    }

    /// The entry of a well-formed row, or nil if the row is malformed
    /// (Python `_entry_from_row`). Fields are stored raw, untrimmed.
    private func entry(from row: [String]) -> WrongEntry? {
        guard row.count == 7 else { return nil }
        guard let when = Self.parseTimestamp(row[0]) else { return nil }
        guard ["dictation", "spelling"].contains(row[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        else { return nil }
        guard !row[4].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !row[5].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        for language in [row[2], row[3]] {
            guard !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            guard (try? canonicalLanguage(language)) != nil else { return nil }
        }
        return WrongEntry(
            when: when,
            kind: row[1],
            primaryLanguage: row[2],
            secondaryLanguage: row[3],
            primaryText: row[4],
            expected: row[5],
            given: row[6]
        )
    }

    public func load() -> [WrongEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        guard let data = try? Data(contentsOf: fileURL), let text = decodeCSVText(data) else { return [] }
        let rows = parseCSVRows(text).filter {
            $0.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        if rows.isEmpty {
            try? write([])
            return []
        }
        let hasHeader = rows[0] == wrongHeader
        var entries: [WrongEntry] = []
        var needsCleanup = !hasHeader
        for row in (hasHeader ? rows.dropFirst() : rows[...]) {
            if let entry = entry(from: row) {
                entries.append(entry)
            } else {
                needsCleanup = true
            }
        }
        if needsCleanup {
            try? write(entries)
        }
        return entries
    }

    public func write(_ entries: [WrongEntry]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var text = "\u{FEFF}" + csvLine(wrongHeader)
        for entry in entries {
            text += csvLine([
                entry.when.map(Self.timestamp) ?? "",
                entry.kind,
                entry.primaryLanguage,
                entry.secondaryLanguage,
                entry.primaryText,
                entry.expected,
                entry.given,
            ])
        }
        guard let data = text.data(using: .utf8) else { return }
        try data.write(to: fileURL)
    }
}
