import Foundation
import Observation
import WordReviewKit

/// Single observable UI state — the counterpart of the Python `PracticeApp`
/// (state in `app.py` plus the `PracticeMixin` / `ReviewMixin` flows).
///
/// Wrong answers live in `<Documents>/Data/Wrong.csv`; word lists live in
/// `<Documents>/Word_resource/` (default read/write folder, seeded from the
/// bundled example CSVs or migrated from the legacy `Resource/` folder).
@MainActor
@Observable
final class AppState {
    enum Screen {
        case home
        case question
        case reviewList
        case reviewQuestion
        case wordList
        case wordEditor
    }

    struct AlertData {
        let title: String
        let message: String
        var okTitle = "OK"
        var cancelTitle: String?
        var onOK: (() -> Void)?
    }

    struct WordFileSummary {
        let name: String
        let entries: Int
    }

    var screen: Screen = .home
    var alert: AlertData?

    // Home screen -----------------------------------------------------------

    var exercises: [Exercise] = []
    var columnLanguages: (String, String) = ("English", "English")
    /// The Python app enables the Dictation/Spelling buttons after the first
    /// successful load and never disables them again — keep that behaviour.
    var canStart = false
    var status = "Choose a CSV file to begin."
    var randomOrder = true
    var secondColumnPrimary = false
    var rangeStart = "1"
    var rangeEnd = ""
    var rangeHint = "Load a CSV file to see the total number of rows."

    // Practice session ------------------------------------------------------

    var session: [Exercise] = []
    var current = 0
    var modeKind = ""
    var wrongAnswers: [(Exercise, String)] = []
    var answer = ""

    // Wrong-answer review ---------------------------------------------------

    var allWrongEntries: [WrongEntry] = []
    var reviewRemoved: Set<Int> = []
    var reviewQueue: [Int] = []
    var reviewPos = 0
    var reviewCorrect = 0
    var reviewIncorrect = 0
    var reviewLanguage = "All languages"
    var reviewFrom = "" // YYYY-MM-DD, or "" for no bound
    var reviewTo = ""
    var selectedRows: Set<Int> = []

    let store: WrongStore
    /// Default read/write folder for word lists — visible in the Files app
    /// under On My iPad > WordReview > Word_resource.
    let wordDir: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        store = WrongStore(
            fileURL: documents.appendingPathComponent("Data").appendingPathComponent("Wrong.csv"),
            relativeTo: documents
        )
        wordDir = documents.appendingPathComponent("Word_resource")
        Self.prepareWordResourceDir(documents: documents)
    }

    /// First launch: create `Documents/Word_resource` and fill it — from the
    /// legacy `Documents/Resource` folder if that exists (migrates installs
    /// that predate the rename), otherwise from the bundled example CSVs.
    private static func prepareWordResourceDir(documents: URL) {
        let fileManager = FileManager.default
        let wordDir = documents.appendingPathComponent("Word_resource")
        let legacy = documents.appendingPathComponent("Resource")
        guard !fileManager.fileExists(atPath: wordDir.path) else { return }
        if fileManager.fileExists(atPath: legacy.path) {
            try? fileManager.createDirectory(at: wordDir, withIntermediateDirectories: true)
            let items = (try? fileManager.contentsOfDirectory(
                at: legacy, includingPropertiesForKeys: nil
            )) ?? []
            for item in items {
                try? fileManager.moveItem(
                    at: item,
                    to: wordDir.appendingPathComponent(item.lastPathComponent)
                )
            }
            try? fileManager.removeItem(at: legacy)
        } else {
            seedBundledCSVs(into: wordDir)
        }
    }

    /// First launch with no legacy folder: copy the bundled example CSVs into
    /// Word_resource so the file list starts with content.
    private static func seedBundledCSVs(into directory: URL) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: directory.path) else { return }
        let csvs = (Bundle.main.urls(forResourcesWithExtension: "csv", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent != "Wrong.csv" }
        guard !csvs.isEmpty else { return }
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        for url in csvs {
            try? fileManager.copyItem(at: url, to: directory.appendingPathComponent(url.lastPathComponent))
        }
    }

    // Alerts ----------------------------------------------------------------

    func showAlert(
        title: String,
        message: String,
        okTitle: String = "OK",
        cancelTitle: String? = nil,
        onOK: (() -> Void)? = nil
    ) {
        alert = AlertData(
            title: title,
            message: message,
            okTitle: okTitle,
            cancelTitle: cancelTitle,
            onOK: onOK
        )
    }

    // Home ------------------------------------------------------------------

    func loadExerciseFile(at url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: url) else {
            showAlert(
                title: "Unable to Read File",
                message: "The first row must name two supported languages, followed by two data columns.\n\nThe file could not be read."
            )
            return
        }
        do {
            let (items, languages) = try loadExercises(from: data)
            exercises = items
            columnLanguages = languages
            canStart = true
            status = "Loaded \(items.count) exercise(s): \(url.lastPathComponent)"
            rangeStart = "1"
            rangeEnd = String(items.count)
            rangeHint = "Total loaded rows: \(items.count). Choose a range from 1 to \(items.count)."
        } catch {
            exercises = []
            showAlert(
                title: "Unable to Read File",
                message: "The first row must name two supported languages, followed by two data columns.\n\n\(error)"
            )
        }
    }

    func goHome() {
        screen = .home
    }

    // Practice flow ---------------------------------------------------------

    var currentMode: PracticeMode {
        modeKind == "spelling" ? SpellingMode.shared : DictationMode.shared
    }

    func primaryText(_ item: Exercise) -> String {
        secondColumnPrimary ? item.spelling : item.source
    }

    func secondaryText(_ item: Exercise) -> String {
        secondColumnPrimary ? item.source : item.spelling
    }

    func primaryLanguage() -> String {
        secondColumnPrimary ? columnLanguages.1 : columnLanguages.0
    }

    func secondaryLanguage() -> String {
        secondColumnPrimary ? columnLanguages.0 : columnLanguages.1
    }

    func start(_ mode: String) {
        let startText = rangeStart.trimmingCharacters(in: .whitespaces)
        let endText = rangeEnd.trimmingCharacters(in: .whitespaces)
        guard let start = Int(startText), let end = Int(endText) else {
            showAlert(title: "Invalid Exam Range", message: "Start row and End row must be whole numbers.")
            return
        }
        let picked: [Exercise]
        do {
            picked = try selectExerciseRange(exercises, start: start, end: end)
        } catch {
            showAlert(title: "Invalid Exam Range", message: "\(error)")
            return
        }
        modeKind = mode
        current = 0
        wrongAnswers = []
        session = picked
        if randomOrder {
            session.shuffle()
        }
        answer = ""
        screen = .question
    }

    func speakCurrentQuestion() {
        speakSecondary(session[current])
    }

    func speakSecondary(_ item: Exercise) {
        SpeechService.shared.speak(secondaryText(item), language: secondaryLanguage())
    }

    func submit() {
        let item = session[current]
        let given = answer
        let expected = secondaryText(item)
        // Either CSV column may contain alternatives, including in dictation.
        if isCorrectAnswer(given: given, expected: expected, allowAlternatives: true) {
            advanceAfterSubmit()
        } else {
            wrongAnswers.append((item, given.trimmingCharacters(in: .whitespacesAndNewlines)))
            showAlert(title: "Answer Recorded", message: "Correct answer:\n\(expected)") { [weak self] in
                self?.advanceAfterSubmit()
            }
        }
    }

    private func advanceAfterSubmit() {
        if current + 1 >= session.count {
            finish()
        } else {
            current += 1
            answer = ""
        }
    }

    private func finish() {
        if wrongAnswers.isEmpty {
            showAlert(title: "Complete", message: "Practice complete. All answers were correct!") { [weak self] in
                self?.goHome()
            }
            return
        }
        saveWrongAnswers()
        let message =
            "Practice complete. \(wrongAnswers.count) incorrect answer(s) were saved to:\n\(store.label)"
        showAlert(title: "Complete", message: message) { [weak self] in
            self?.goHome()
        }
    }

    private func saveWrongAnswers() {
        var entries = store.load()
        let now = Date()
        let kind = currentMode.recordKind
        for (item, given) in wrongAnswers {
            entries.append(
                WrongEntry(
                    when: now,
                    kind: kind,
                    primaryLanguage: primaryLanguage(),
                    secondaryLanguage: secondaryLanguage(),
                    primaryText: primaryText(item),
                    expected: secondaryText(item),
                    given: given
                )
            )
        }
        try? store.write(entries)
    }

    // Review: list and filters ---------------------------------------------

    var languageOptions: [String] {
        ["All languages"] + Set(allWrongEntries.map(languageLabel)).sorted()
    }

    func normalizeReviewLanguage() {
        if !languageOptions.contains(reviewLanguage) {
            reviewLanguage = "All languages"
        }
    }

    func openReview() {
        let entries = store.load()
        guard !entries.isEmpty else {
            showAlert(title: "No Wrong Answers", message: "There are no wrong answers recorded yet.")
            return
        }
        allWrongEntries = entries
        reviewRemoved = []
        selectedRows = []
        normalizeReviewLanguage()
        screen = .reviewList
    }

    private func parseFilterDate(_ value: String, label: String) throws -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return nil
        }
        guard trimmed.range(of: #"\A\d{4}-\d{2}-\d{2}\z"#, options: .regularExpression) != nil else {
            throw FilterError.badDate(label)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: trimmed) else {
            throw FilterError.badDate(label)
        }
        return date
    }

    enum FilterError: Error, CustomStringConvertible {
        case badDate(String)
        case toBeforeFrom

        var description: String {
            switch self {
            case .badDate(let label):
                return "\(label) must use YYYY-MM-DD."
            case .toBeforeFrom:
                return "The to date is before the from date."
            }
        }
    }

    /// Visible row indices under the current filter, newest mistakes first
    /// (Python `_filtered_indices`).
    func filteredIndices() throws -> [Int] {
        let dateFrom = try parseFilterDate(reviewFrom, label: "From date")
        let dateTo = try parseFilterDate(reviewTo, label: "To date")
        if let dateFrom, let dateTo, dateTo < dateFrom {
            throw FilterError.toBeforeFrom
        }
        var indices: [Int] = []
        for (index, entry) in allWrongEntries.enumerated() {
            if reviewRemoved.contains(index) {
                continue
            }
            if reviewLanguage != "All languages", languageLabel(entry) != reviewLanguage {
                continue
            }
            if dateFrom != nil || dateTo != nil {
                guard let when = entry.when else { continue }
                let day = Calendar.current.startOfDay(for: when)
                if let dateFrom, day < dateFrom {
                    continue
                }
                if let dateTo, day > dateTo {
                    continue
                }
            }
            indices.append(index)
        }
        indices.sort {
            (allWrongEntries[$0].when ?? .distantPast) > (allWrongEntries[$1].when ?? .distantPast)
        }
        return indices
    }

    func filteredIndicesUnchecked() -> [Int] {
        (try? filteredIndices()) ?? []
    }

    /// A filter changed: the visible list re-renders automatically; selection
    /// is cleared (the Python app's Treeview rebuild drops the selection) and
    /// the filter is validated like `_refresh_review_list`.
    func filterChanged() {
        selectedRows = []
        do {
            _ = try filteredIndices()
        } catch {
            showAlert(title: "Invalid Filter", message: "\(error)")
        }
    }

    func toggleRow(_ index: Int) {
        if selectedRows.contains(index) {
            selectedRows.remove(index)
        } else {
            selectedRows.insert(index)
        }
    }

    private func saveReviewRemovals() {
        let kept = allWrongEntries.enumerated()
            .filter { !reviewRemoved.contains($0.offset) }
            .map(\.element)
        try? store.write(kept)
    }

    func deleteSelected() {
        guard !selectedRows.isEmpty else {
            showAlert(title: "Nothing Selected", message: "Select one or more mistakes in the list first.")
            return
        }
        reviewRemoved.formUnion(selectedRows)
        selectedRows = []
        saveReviewRemovals()
        if filteredIndicesUnchecked().isEmpty {
            showAlert(title: "No Wrong Answers", message: "All wrong answers have been removed.") { [weak self] in
                self?.goHome()
            }
        }
    }

    func startReview() {
        let filtered = filteredIndicesUnchecked()
        // Selected rows are reviewed first, in display order; with no
        // selection the whole filtered list is reviewed (Python behaviour).
        let queue = selectedRows.isEmpty ? filtered : filtered.filter { selectedRows.contains($0) }
        guard !queue.isEmpty else {
            showAlert(title: "Nothing to Review", message: "No mistakes match the current filter.")
            return
        }
        reviewQueue = queue
        reviewPos = 0
        reviewCorrect = 0
        reviewIncorrect = 0
        answer = ""
        screen = .reviewQuestion
    }

    // Review: quiz ----------------------------------------------------------

    var currentReviewEntry: WrongEntry {
        allWrongEntries[reviewQueue[reviewPos]]
    }

    var currentReviewMode: PracticeMode {
        mode(forRecordKind: currentReviewEntry.kind)
    }

    func speakCurrentReview() {
        let entry = currentReviewEntry
        SpeechService.shared.speak(entry.expected, language: entry.secondaryLanguage)
    }

    func reviewSubmit() {
        let entry = currentReviewEntry
        if isCorrectAnswer(given: answer, expected: entry.expected, allowAlternatives: true) {
            // A corrected mistake leaves the wrong-answer file.
            reviewCorrect += 1
            reviewRemoved.insert(reviewQueue[reviewPos])
            saveReviewRemovals()
            advanceReview()
        } else {
            reviewIncorrect += 1
            showAlert(title: "Still Incorrect", message: "Correct answer:\n\(entry.expected)") { [weak self] in
                self?.advanceReview()
            }
        }
    }

    private func advanceReview() {
        if reviewPos + 1 >= reviewQueue.count {
            reviewFinish()
        } else {
            reviewPos += 1
            answer = ""
        }
    }

    private func reviewFinish() {
        var message =
            "Review complete. \(reviewCorrect) answer(s) are now correct and were removed from \(store.label)."
        if reviewIncorrect > 0 {
            message += "\n\(reviewIncorrect) answer(s) are still incorrect and stay in the list."
        }
        showAlert(title: "Review Complete", message: message) { [weak self] in
            guard let self else { return }
            allWrongEntries = store.load()
            reviewRemoved = []
            selectedRows = []
            if allWrongEntries.isEmpty {
                goHome()
            } else {
                normalizeReviewLanguage()
                screen = .reviewList
            }
        }
    }

    // Word-list editor ------------------------------------------------------

    var wordFiles: [WordFileSummary] = []
    var editorFileName = ""
    var editorIsNew = false
    var editorLang1 = "English"
    var editorLang2 = "Chinese"
    /// Exactly two cells per row (extra columns in hand-edited files are kept
    /// on disk until the row is saved, then reduced to the two columns).
    var editorRows: [[String]] = []
    var editorDirty = false
    var editorStatus = ""

    func openWordLists() {
        refreshWordFiles()
        screen = .wordList
    }

    func refreshWordFiles() {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: wordDir.path)) ?? [])
            .filter { $0.lowercased().hasSuffix(".csv") }
            .sorted { $0.lowercased() < $1.lowercased() }
        wordFiles = names.map { name in
            WordFileSummary(name: name, entries: entryCount(at: wordDir.appendingPathComponent(name)))
        }
    }

    private func entryCount(at url: URL) -> Int {
        guard let data = try? Data(contentsOf: url), let text = decodeCSVText(data) else { return 0 }
        let rows = parseCSVRows(text)
        guard rows.count > 1 else { return 0 }
        return rows.dropFirst().filter {
            $0.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }.count
    }

    func openWordFile(_ name: String) {
        let url = wordDir.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url), let text = decodeCSVText(data) else {
            showAlert(title: "Unable to Read File", message: "The file could not be read as UTF-8 text.")
            return
        }
        let rows = parseCSVRows(text)
        if let header = rows.first {
            editorLang1 = header.count > 0 ? header[0].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            editorLang2 = header.count > 1 ? header[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        } else {
            editorLang1 = "English"
            editorLang2 = "Chinese"
        }
        editorRows = rows.dropFirst()
            .filter { $0.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
            .map {
                [
                    $0.count > 0 ? $0[0] : "",
                    $0.count > 1 ? $0[1] : "",
                ]
            }
        editorFileName = name
        editorIsNew = false
        editorDirty = false
        editorStatus = ""
        screen = .wordEditor
    }

    /// Prepare a new (not yet written) file in the editor; the CSV is only
    /// created on the first successful save, so abandoning it leaves no junk.
    func startNewWordFile(rawName: String) {
        var name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        guard !name.isEmpty else {
            showAlert(title: "Invalid File Name", message: "Enter a file name.")
            return
        }
        if !name.lowercased().hasSuffix(".csv") {
            name += ".csv"
        }
        guard !FileManager.default.fileExists(atPath: wordDir.appendingPathComponent(name).path) else {
            showAlert(
                title: "File Exists",
                message: "\(name) already exists in Word_resource. Open it from the list to edit it."
            )
            return
        }
        editorFileName = name
        editorIsNew = true
        editorLang1 = "English"
        editorLang2 = "Chinese"
        editorRows = []
        editorDirty = false
        editorStatus = "Not saved yet."
        screen = .wordEditor
    }

    func addEditorRow() {
        editorRows.append(["", ""])
        editorDirty = true
    }

    func deleteEditorRows(at offsets: IndexSet) {
        editorRows.remove(atOffsets: offsets)
        editorDirty = true
    }

    /// Import an external CSV (picked with the document picker) into
    /// `Word_resource`, validating it with the kit loader first. On a name
    /// conflict, asks before replacing.
    func importWordFile(at url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: url) else {
            showAlert(title: "Unable to Read File", message: "The file could not be read.")
            return
        }
        do {
            _ = try loadExercises(from: data)
        } catch {
            showAlert(title: "Cannot Import", message: "\(error)")
            return
        }
        var name = url.lastPathComponent
        if !name.lowercased().hasSuffix(".csv") {
            name += ".csv"
        }
        try? FileManager.default.createDirectory(at: wordDir, withIntermediateDirectories: true)
        let destination = wordDir.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: destination.path) {
            showAlert(
                title: "File Exists",
                message: "\(name) already exists in Word_resource. Replace it?",
                okTitle: "Replace",
                cancelTitle: "Cancel"
            ) { [weak self] in
                self?.writeImport(data: data, to: destination)
            }
        } else {
            writeImport(data: data, to: destination)
        }
    }

    private func writeImport(data: Data, to destination: URL) {
        do {
            try data.write(to: destination)
        } catch {
            showAlert(title: "Cannot Import", message: "The file could not be copied.\n\(error)")
            return
        }
        refreshWordFiles()
    }

    func leaveEditor() {
        guard editorDirty else {
            screen = .wordList
            return
        }
        showAlert(
            title: "Unsaved Changes",
            message: "Changes to \(editorFileName) will be lost.",
            okTitle: "Discard",
            cancelTitle: "Keep Editing"
        ) { [weak self] in
            self?.screen = .wordList
        }
    }

    /// Validate and write the editor contents to `Word_resource/<name>`.
    /// The serialized text must pass `loadExercises` first, so every saved
    /// file is guaranteed to load (same contract as the Python loader).
    func saveWordFile() {
        let canonical1: String
        let canonical2: String
        do {
            canonical1 = try canonicalLanguage(editorLang1)
            canonical2 = try canonicalLanguage(editorLang2)
        } catch {
            showAlert(title: "Cannot Save", message: "\(error)")
            return
        }
        let cleaned = editorRows
            .map {
                [
                    $0[0].trimmingCharacters(in: .whitespacesAndNewlines),
                    $0[1].trimmingCharacters(in: .whitespacesAndNewlines),
                ]
            }
            .filter { !$0[0].isEmpty || !$0[1].isEmpty }
        guard !cleaned.isEmpty else {
            showAlert(title: "Cannot Save", message: ExerciseCSVError.noExercises.description)
            return
        }
        var text = "\u{FEFF}" + csvLine([canonical1, canonical2])
        for row in cleaned {
            text += csvLine(row)
        }
        guard let data = text.data(using: .utf8) else {
            showAlert(title: "Cannot Save", message: "The contents could not be encoded as UTF-8.")
            return
        }
        do {
            _ = try loadExercises(from: data)
        } catch {
            showAlert(title: "Cannot Save", message: "\(error)")
            return
        }
        let url = wordDir.appendingPathComponent(editorFileName)
        do {
            try data.write(to: url)
        } catch {
            showAlert(title: "Cannot Save", message: "The file could not be written.\n\(error)")
            return
        }
        editorLang1 = canonical1
        editorLang2 = canonical2
        editorRows = cleaned
        editorIsNew = false
        editorDirty = false
        editorStatus = "Saved to Word_resource/\(editorFileName)"
        refreshWordFiles()
    }
}
