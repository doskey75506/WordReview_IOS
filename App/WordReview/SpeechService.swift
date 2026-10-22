import AVFoundation
import Foundation
import WordReviewKit

/// Text-to-speech — the counterpart of `Reader.read_text_aloud`.
///
/// Speech failures are expected/normal: nothing here throws or reports errors.
/// Voice selection is best-effort by locale (English always uses the system
/// default voice, like `say text` with no `-v` in the Python app); a missing
/// voice falls back to the synthesizer default. Non-English languages use a
/// slower rate equivalent to the Python app's 150 words per minute.
@MainActor
final class SpeechService {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, language: String) {
        // Python `speech_text` lowercases so capitals are not spelled out.
        let utterance = AVSpeechUtterance(string: text.lowercased())
        if language != "English" {
            utterance.voice = matchingVoice(for: language)
            // `say`'s default rate is ~175 wpm; the Python app asks for 150 wpm
            // for every non-English language (`NON_ENGLISH_RATE`).
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 150.0 / 175.0
        }
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    private func matchingVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let locales = speechLocales[language] ?? []
        let voices = AVSpeechSynthesisVoice.speechVoices()
        for locale in locales {
            let appleTag = locale.replacingOccurrences(of: "_", with: "-")
            if let exact = voices.first(where: { $0.language.caseInsensitiveCompare(appleTag) == .orderedSame }) {
                return exact
            }
        }
        for locale in locales {
            let prefix = locale.prefix(2).lowercased()
            if let match = voices.first(where: { $0.language.lowercased().hasPrefix(prefix) }) {
                return match
            }
        }
        return nil
    }
}
