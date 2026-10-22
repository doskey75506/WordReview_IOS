import Foundation

/// One CSV data row: the primary ("source") and secondary ("spelling") column values.
public struct Exercise: Hashable, Sendable {
    public let source: String
    public let spelling: String

    public init(source: String, spelling: String) {
        self.source = source
        self.spelling = spelling
    }
}

/// One row of `Wrong.csv`; `kind` is stored exactly as it appeared in the file
/// (raw, untrimmed) so a round-trip rewrites what was read.
public struct WrongEntry: Hashable, Sendable {
    public let when: Date?
    public let kind: String
    public let primaryLanguage: String
    public let secondaryLanguage: String
    public let primaryText: String
    public let expected: String
    public let given: String

    public init(
        when: Date?,
        kind: String,
        primaryLanguage: String,
        secondaryLanguage: String,
        primaryText: String,
        expected: String,
        given: String
    ) {
        self.when = when
        self.kind = kind
        self.primaryLanguage = primaryLanguage
        self.secondaryLanguage = secondaryLanguage
        self.primaryText = primaryText
        self.expected = expected
        self.given = given
    }
}

/// What a practice/review screen shows for one question. An empty `display`
/// means "show no text under the prompt".
public struct QuestionView: Hashable, Sendable {
    public let prompt: String
    public let display: String
    public let instruction: String

    public init(prompt: String, display: String, instruction: String) {
        self.prompt = prompt
        self.display = display
        self.instruction = instruction
    }
}

public enum RangeError: Error, CustomStringConvertible, Equatable {
    case invalid(Int)

    public var description: String {
        switch self {
        case .invalid(let count):
            return "Choose a valid range from 1 to \(count)."
        }
    }
}

/// Compare answers without making Latin-only assumptions: trim, collapse
/// whitespace runs to single spaces, lowercase (Python `normalise`).
public func normalise(_ value: String) -> String {
    value.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
}

/// Accept ASCII/full-width pipe-separated alternatives, such as `to be|being`.
/// Comparison collapses whitespace and case but does not strip accents.
public func isCorrectAnswer(given: String, expected: String, allowAlternatives: Bool = false) -> Bool {
    if allowAlternatives {
        let alternatives = expected.split(
            maxSplits: Int.max,
            omittingEmptySubsequences: false,
            whereSeparator: { $0 == "|" || $0 == "｜" }
        ).map { normalise(String($0)) }
        return alternatives.contains(normalise(given))
    }
    return normalise(given) == normalise(expected)
}

/// Inclusive, one-based row range after validating it (Python `select_exercise_range`).
public func selectExerciseRange(_ exercises: [Exercise], start: Int, end: Int) throws -> [Exercise] {
    guard start >= 1, end >= start, end <= exercises.count else {
        throw RangeError.invalid(exercises.count)
    }
    return Array(exercises[(start - 1)..<end])
}
