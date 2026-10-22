import SwiftUI
import UniformTypeIdentifiers

/// Checkbox style for the "Practice options" group (iOS switches would not
/// match the Tkinter home screen).
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .imageScale(.large)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

struct HomeView: View {
    @Bindable var state: AppState
    @State private var showImporter = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Dictation and Spelling Practice")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.top, 10)

                Text("1. Choose a CSV file\n2. Set the range\n3. Select Dictation or Spelling to start exercise")
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 6)

                Button("Choose CSV File") {
                    showImporter = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text(state.status)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 540)
                    .padding(.vertical, 6)

                GroupBox("Practice options") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Random question order", isOn: $state.randomOrder)
                        Toggle("Reverse exercise", isOn: $state.secondColumnPrimary)
                        Text("Type the answer based on the displayed text or spoken prompt.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    .frame(maxWidth: 460, alignment: .leading)
                    .padding(4)
                }

                GroupBox("Exam range (loaded row numbers)") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("Start row:")
                            TextField("", text: $state.rangeStart)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("End row:")
                            TextField("", text: $state.rangeEnd)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        Text(state.rangeHint)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 460, alignment: .leading)
                    .padding(4)
                }

                HStack(spacing: 16) {
                    Button("Dictation") {
                        state.start("dictation")
                    }
                    Button("Spelling") {
                        state.start("spelling")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!state.canStart)

                Button("Review Wrong Answers") {
                    state.openReview()
                }
                .controlSize(.large)

                Button("Edit Word Lists") {
                    state.openWordLists()
                }
                .controlSize(.large)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(36)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText, .item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                state.loadExerciseFile(at: url)
            }
        }
    }
}
