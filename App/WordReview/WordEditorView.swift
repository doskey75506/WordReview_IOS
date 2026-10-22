import SwiftUI

/// Two-column CSV editor for one word list: header language names plus rows.
/// Save round-trips through the kit's loader so a written file always loads.
struct WordEditorView: View {
    @Bindable var state: AppState

    /// Cells bind through `editorDirty` instead of `.onChange`, so programmatic
    /// resets after loading/saving do not leave the unsaved-changes flag stuck.
    private func cellBinding(_ row: Int, _ col: Int) -> Binding<String> {
        Binding(
            get: { state.editorRows[row][col] },
            set: { newValue in
                state.editorRows[row][col] = newValue
                state.editorDirty = true
            }
        )
    }

    private func langBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { index == 0 ? state.editorLang1 : state.editorLang2 },
            set: { newValue in
                if index == 0 {
                    state.editorLang1 = newValue
                } else {
                    state.editorLang2 = newValue
                }
                state.editorDirty = true
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Back") {
                    state.leaveEditor()
                }
                Spacer()
                Text(state.editorFileName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button("Save") {
                    state.saveWordFile()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            GroupBox("Languages (header row)") {
                HStack(spacing: 12) {
                    TextField("First column", text: langBinding(0))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                    TextField("Second column", text: langBinding(1))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
            .padding(.horizontal)

            HStack {
                Text(state.editorStatus)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Button {
                    state.addEditorRow()
                } label: {
                    Label("Add Row", systemImage: "plus")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if state.editorRows.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "table.rows")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No entries yet — tap Add Row.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(state.editorRows.enumerated()), id: \.offset) { pair in
                        HStack(spacing: 8) {
                            Text("\(pair.offset + 1)")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(width: 36, alignment: .trailing)
                            TextField("", text: cellBinding(pair.offset, 0), axis: .vertical)
                                .lineLimit(1...3)
                            TextField("", text: cellBinding(pair.offset, 1), axis: .vertical)
                                .lineLimit(1...3)
                            Button(role: .destructive) {
                                state.deleteEditorRows(at: IndexSet(integer: pair.offset))
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(.bottom)
    }
}
