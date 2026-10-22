import Foundation

/// Language names accepted in the CSV header, validated like `canonical_language`
/// in the Python app's `Reader.py`.
public enum LanguageError: Error, CustomStringConvertible, Equatable {
    case unsupported(String)

    public var description: String {
        switch self {
        case .unsupported(let value):
            return "Unsupported language '\(value)'. Use one of: Chinese, French, Spanish, English."
        }
    }
}

/// Header language name -> locale codes, in preference order (same values as
/// `Reader.py` `LANGUAGE_LOCALES`).
public let speechLocales: [String: [String]] = [
    "Chinese": ["zh_CN", "zh_TW", "zh_HK"],
    "French": ["fr_FR", "fr_CA"],
    "Spanish": ["es_ES", "es_MX"],
    "English": ["en_US", "en_GB"],
]

/// Header language name -> ISO 639-1 codes (`Reader.py` `LANGUAGE_CODES`).
public let speechLanguageCodes: [String: [String]] = [
    "Chinese": ["zh"],
    "French": ["fr"],
    "Spanish": ["es"],
    "English": ["en"],
]

/// Validate and standardise a language name from a CSV header cell.
public func canonicalLanguage(_ value: String) throws -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    for language in ["Chinese", "French", "Spanish", "English"]
    where trimmed.caseInsensitiveCompare(language) == .orderedSame {
        return language
    }
    throw LanguageError.unsupported(value)
}
