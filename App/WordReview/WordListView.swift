import SwiftUI
import UniformTypeIdentifiers

/// Word-list file browser over `Documents/Word_resource`: pick a CSV to edit,
/// create a new one (the file is only written on the first save), or import an
/// existing CSV from Files/elsewhere into Word_resource.
struct WordListView: View {
    @Bindable var state: AppState
    @State private var showNewFileAlert = false
    @State private var newFileName = ""
    @State private var showImporter = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Home") {
                    state.goHome()
                }
                Spacer()
                Text("Word_resource")
                    .font(.headline)
                Spacer()
                Button("Import") {
                    showImporter = true
                }
                Button("New File") {
                    newFileName = ""
                    showNewFileAlert = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            if state.wordFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No CSV files in Word_resource yet.")
                        .foregroundStyle(.secondary)
                    Text("Tap New File to create one, or Import to copy an existing CSV.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(state.wordFiles, id: \.name) { file in
                    Button {
                        state.openWordFile(file.name)
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                Text("\(file.entries) entries")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .alert("New File Name", isPresented: $showNewFileAlert) {
            TextField("my_words.csv", text: $newFileName)
            Button("Create", role: .destructive) {
                state.startNewWordFile(rawName: newFileName)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The file will be created in Word_resource when you save it.")
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText, .item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                state.importWordFile(at: url)
            }
        }
    }
}
