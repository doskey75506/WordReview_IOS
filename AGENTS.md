# AGENTS.md

iPhone/iPad app that is a **feature-complete port of the Python/Tkinter app** at `/Users/jialishen/Coding/Python/WordReview` (relative: `../../Python/WordReview`) — same functionality, visually similar UI. All UI strings are English and live inline in the views (the Python app is English-only too; there is no `Strings.kt`-style localization here).

## Reference repo (source of truth for behaviour)

Read before changing behaviour: `../../Python/WordReview/AGENTS.md`, `README.md`, `doc/PROJECT.md`. The executable spec per area:

- `models.py` — answer checking (`is_correct_answer` always called with `allow_alternatives=True`), range validation
- `files.py` — exercise CSV contract + the `Wrong.csv` store (cleanup/rebuild/rewrite rules)
- `practice.py` / `review.py` — screen flows **and the exact dialog title/message strings**, copy them verbatim
- `dictation.py` / `spelling.py` — the shared mode interface and prompt/instruction texts
- `Reader.py` — language validation + TTS voice/rate rules
- `Resource/*.csv` — the four example files, bundled into the app under `App/WordReview/Resource/`

## Repo layout

- `Package.swift` — SPM package `WordReviewKit`: pure logic, **no SwiftUI/UIKit imports**. macOS 14 / iOS 17.
- `Sources/WordReviewKit/` — `Language.swift` (canonical_language), `Models.swift` (Exercise/WrongEntry/QuestionView, answer check, range), `CSV.swift` (`loadExercises` + a small RFC 4180 parser + shared `csvLine` serializer), `WrongStore.swift` (Wrong.csv load/write), `Modes.swift` (Dictation/Spelling `view(...)`, `mode(forRecordKind:)`, `languageLabel`).
- `Tests/WordReviewTests/` — port of `test_wrong_entries.py` plus CSV/answer/mode contracts. This is the executable spec for the kit.
- `App/WordReview/` — SwiftUI app: `AppState.swift` holds **all** flow state and logic (counterpart of `PracticeApp` + `PracticeMixin` + `ReviewMixin`; views are dumb), `RootView.swift` (screen switch + the single shared alert), `HomeView` / `PracticeQuestionView` / `ReviewListView` / `ReviewQuestionView` / `WordListView` / `WordEditorView`, `SpeechService.swift` (AVSpeechSynthesizer), `Resource/*.csv` (bundled).
- `App/WordReview.xcodeproj/` — hand-written Xcode 16 project: **file-system-synchronized root group** (new `.swift`/`.csv` files under `App/WordReview/` are picked up automatically — never edit pbxproj to add files), iPhone + iPad (`TARGETED_DEVICE_FAMILY=1,2`), bundle id `com.wordreview.app`, iOS 17.0 target, references the local SPM package at `..`.

## Commands (all verified)

```bash
# kit logic tests on the macOS host — run after any Sources/ or Tests/ change
swift test                                        # 36 tests

# app build — run after any App/ change
xcodebuild -project App/WordReview.xcodeproj -scheme WordReview \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build build
# → build/Build/Products/Debug-iphonesimulator/WordReview.app
# (DEVELOPMENT_TEAM is set in the project now; `CODE_SIGNING_ALLOWED=NO` also still works)
```

Manual testing on the simulator (device `iPad (A16)` = `9EFB7FC4-1EB3-4BF8-A290-8DD366D1E8D5`):

```bash
xcrun simctl boot 9EFB7FC4-1EB3-4BF8-A290-8DD366D1E8D5
xcrun simctl install 9EFB7FC4-1EB3-4BF8-A290-8DD366D1E8D5 build/Build/Products/Debug-iphonesimulator/WordReview.app
xcrun simctl launch 9EFB7FC4-1EB3-4BF8-A290-8DD366D1E8D5 com.wordreview.app
# inspect app data (Documents/Word_resource = word lists, Documents/Data/Wrong.csv):
xcrun simctl get_app_container 9EFB7FC4-1EB3-4BF8-A290-8DD366D1E8D5 com.wordreview.app data
```

No linter, formatter or CI exists for Swift in this repo — rely on `swift test` + a clean `xcodebuild` (keep it warning-free).

## Porting gotchas (already hit — don't reintroduce)

- **SwiftUI identity**: in both question views, `.task { … }` must be applied **before/outside-to-inside** `.id(...)` (i.e. `.task{}.id(x)` — id outermost). The reverse order (`.id(x).task{}`) keeps the task node's identity stable across questions, so auto-play and focus ran only for question 1 and never again. Same trap applies to any per-item `.task`.
- **Chained alerts**: dialogs advance the flow via `onOK`. `RootView` clears `state.alert` and runs the callback on the next runloop turn (`DispatchQueue.main.async`) — otherwise a follow-up alert ("Complete" after "Answer Recorded") set in the same transaction may not present.
- **Deliberate Python quirks, kept for parity** (change them only if the Python side changes):
  - Dictation/Spelling buttons enable after the first successful load and never disable; a failed load clears `exercises` but keeps `status`, the range fields and the enabled buttons (so a later start fails with "Choose a valid range from 1 to 0.").
  - `mode(forRecordKind:)` compares **without trimming** — a hand-edited `" Dictation "` row falls through to the spelling view.
  - Review: row identity = index into `allWrongEntries`; correct/deleted rows are removed by index and the **whole file** is rewritten — never write back the filtered subset. Changing any filter clears the table selection (the Tk Treeview rebuild did).
- **`Wrong.csv` contract**: exact 7-column header; kinds are exactly `Dictation` / `spelling`; timestamps `yyyy-MM-dd HH:mm:ss`; new files get a UTF-8 BOM (Excel expects it — don't "fix"); `load()` purges malformed rows, restores a missing header, rebuilds an emptied file, and rewrites **only when something was cleaned**; hand edits are tolerated. Store path: `Documents/Data/Wrong.csv`, user-facing label `Data/Wrong.csv`.
- **Exercise CSV**: BOM stripped (`utf-8-sig` parity), header = 2 canonical language names (`English`/`French`/`Spanish`/`Chinese`, case-insensitive; error text lists them as "Chinese, French, Spanish, English"), cells trimmed, blank rows skipped **without consuming row numbers**, ≥2 cells required (extra columns ignored).
- **Word lists live in `Documents/Word_resource/`** (default read/write folder; user-facing label "Word_resource"). On first launch: if the legacy `Documents/Resource/` folder exists its CSVs are moved into `Word_resource` and the folder deleted; otherwise the bundled examples are seeded. `Wrong.csv` is never in `Word_resource` — it stays in `Documents/Data/`. The editor writes BOM + CRLF via the kit's shared `csvLine` (same serializer as `WrongStore`); every save is validated by round-tripping through `loadExercises` first, so a written file always loads. New files are only created on the first successful save. Editor header defaults to ("English","Chinese") and is canonicalized on save. Dirty-back shows a "Unsaved Changes" confirm (Discard / Keep Editing) via `AlertData.cancelTitle`.
- **`AlertData` supports `okTitle`/`cancelTitle`**: the shared alert in `RootView` renders a cancel button when `cancelTitle` is set and makes OK destructive; the discard confirm relies on this.
- **Answer check**: trim + collapse whitespace runs + lowercase; `|`/`｜` split alternatives; accents/Chinese characters are never normalised away.
- **TTS**: text is lowercased before speaking (Python `speech_text`); English uses the system default voice at the default rate; non-English picks a locale voice (`zh-CN`/`fr-FR`/`es-ES`, falling back to prefix match, then the synthesizer default) with rate `default × 150/175` (Python's 150 wpm); auto-play fires 250 ms after a question appears; speech failures are silent **by design**, don't add error reporting. Deviation from Python: we `stopSpeaking` before each new utterance (the Python app lets overlapping `say` processes stack).
- **CSV seeding**: bundled `*.csv` are copied to `Documents/Resource/` only when that folder does not exist (first launch). Deleting individual files won't re-copy; deleting the folder re-seeds. `Wrong.csv` is never bundled.
