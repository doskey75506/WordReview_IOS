# WordReview for iOS

Dictation and spelling practice for iPhone/iPad — a feature-complete port of a
Python/Tkinter desktop app (same functionality, similar UI, English-only strings).

- **Dictation**: play a word/phrase from the secondary column, type what you hear.
- **Spelling practice**: show the primary column, type the translation from the other column.
- **Review**: wrong answers are recorded to a `Wrong.csv` store and can be re-practised,
  filtered, and cleared.
- **Word lists**: manage the exercise CSV files on-device (create/edit/import), bundled
  with four examples (`example`, `Chinese`, `French`, `Spanish`).

CSV format: first row names the two languages (case-insensitive `English`, `French`,
`Spanish`, `Chinese`), every later row holds the two values. UTF-8 CSV with or without BOM.

## Requirements

- Xcode 16+, iOS 17.0 target (device family: iPhone + iPad)
- Swift 5.10 (SPM package `WordReviewKit`, macOS 14 / iOS 17)

## Project layout

| Path | Contents |
| --- | --- |
| `Sources/WordReviewKit/` | Pure logic SPM package (no UI imports): models, answer checking, CSV parsing, `Wrong.csv` store, mode config |
| `Tests/WordReviewTests/` | Executable spec for the kit (36 tests) |
| `App/WordReview/` | SwiftUI app: `AppState.swift` holds all flow state, views are dumb, `SpeechService.swift` does TTS |
| `App/WordReview.xcodeproj/` | Hand-written Xcode project, file-system-synchronized group (new files under `App/WordReview/` are picked up automatically) |

## Build & test

```bash
# logic tests (macOS host) — run after any Sources/ or Tests/ change
swift test

# app build (iOS Simulator) — run after any App/ change
xcodebuild -project App/WordReview.xcodeproj -scheme WordReview \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build build
# → build/Build/Products/Debug-iphonesimulator/WordReview.app
```

Run on the simulator:

```bash
xcrun simctl boot 9EFB7FC4-1EB3-4BF8-A290-8DD366D1E8D5   # iPad (A16)
xcrun simctl install 9EFB7FC4-1EB3-4BF8-A290-8DD366D1E8D5 build/Build/Products/Debug-iphonesimulator/WordReview.app
xcrun simctl launch 9EFB7FC4-1EB3-4BF8-A290-8DD366D1E8D5 com.wordreview.app
```

## On-device data

- `Documents/Word_resource/` — word list CSVs (default read/write folder; bundled
  examples are seeded on first launch)
- `Documents/Data/Wrong.csv` — wrong-answer store (7-column CSV with UTF-8 BOM)

There is no linter, formatter or CI: rely on `swift test` plus a warning-free `xcodebuild`.
