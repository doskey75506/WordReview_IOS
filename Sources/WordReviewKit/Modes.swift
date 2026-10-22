import Foundation

/// The screen title, recorded practice type and prompt text for one practice
/// mode (Python `DictationMode` / `SpellingMode` shared interface).
public protocol PracticeMode {
    var name: String { get }
    var recordKind: String { get }
    var autoPlay: Bool { get }

    /// `listenHint` is true on the practice screen and false during review,
    /// where the dictation "Listen to…" hint line is omitted.
    func view(primaryLanguage: String, secondaryLanguage: String, primaryText: String, listenHint: Bool) -> QuestionView
}

/// Dictation: play the prompt aloud, the learner types what they hear.
/// The practice type recorded in `Wrong.csv` is exactly `"Dictation"`.
public struct DictationMode: PracticeMode {
    public static let shared = DictationMode()

    public let name = "Dictation"
    public let recordKind = "Dictation"
    public let autoPlay = true

    public init() {}

    public func view(
        primaryLanguage: String,
        secondaryLanguage: String,
        primaryText: String,
        listenHint: Bool
    ) -> QuestionView {
        _ = primaryLanguage
        _ = primaryText // dictation never shows the written prompt
        return QuestionView(
            prompt: "\(secondaryLanguage) dictation",
            display: listenHint
                ? "Listen to the \(secondaryLanguage) pronunciation, then type the \(secondaryLanguage) text."
                : "",
            instruction: "Based on the \(secondaryLanguage) pronunciation, write the \(secondaryLanguage) text:"
        )
    }
}

/// Spelling: show the prompt text, the learner types the translation.
/// The practice type recorded in `Wrong.csv` is exactly `"spelling"`.
public struct SpellingMode: PracticeMode {
    public static let shared = SpellingMode()

    public let name = "Spelling Practice"
    public let recordKind = "spelling"
    public let autoPlay = false

    public init() {}

    public func view(
        primaryLanguage: String,
        secondaryLanguage: String,
        primaryText: String,
        listenHint: Bool
    ) -> QuestionView {
        _ = listenHint
        return QuestionView(
            prompt: "\(primaryLanguage) text",
            display: primaryText,
            instruction: "Based on the \(primaryLanguage) text, write the \(secondaryLanguage) text:"
        )
    }
}

/// Map a `Wrong.csv` practice type back to its mode (Python `mode_for_record_kind`).
/// Note: the comparison does **not** trim, matching the Python behaviour where
/// a hand-edited kind with surrounding spaces falls through to spelling.
public func mode(forRecordKind kind: String) -> PracticeMode {
    kind.lowercased() == "dictation" ? DictationMode.shared : SpellingMode.shared
}

/// Language pair label for the review filter (`review.language_label`).
public func languageLabel(_ entry: WrongEntry) -> String {
    if !entry.primaryLanguage.isEmpty, !entry.secondaryLanguage.isEmpty {
        return "\(entry.primaryLanguage) → \(entry.secondaryLanguage)"
    }
    return "Unknown"
}
