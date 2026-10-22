import SwiftUI
import WordReviewKit

/// The practice question screen (Python `PracticeMixin._build_question`).
///
/// `.id(state.current)` rebuilds the screen for every question, which resets
/// focus and the answer field and re-triggers the dictation auto-play.
struct PracticeQuestionView: View {
    @Bindable var state: AppState
    @FocusState private var answerFocused: Bool

    private var item: Exercise {
        state.session[state.current]
    }

    private var mode: PracticeMode {
        state.currentMode
    }

    private var view: QuestionView {
        mode.view(
            primaryLanguage: state.primaryLanguage(),
            secondaryLanguage: state.secondaryLanguage(),
            primaryText: state.primaryText(item),
            listenHint: true
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mode.name)
                .font(.system(size: 20, weight: .bold))
            Text("Question \(state.current + 1) of \(state.session.count)")
                .padding(.bottom, 10)

            Text(view.prompt)
            if !view.display.isEmpty {
                Text(view.display)
                    .font(.system(size: 18))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 8)
            }
            if mode.autoPlay {
                Button("▶ Play Text to Write") {
                    state.speakCurrentQuestion()
                }
                .padding(.bottom, 4)
            }

            Text(view.instruction)

            TextField("Answer", text: $state.answer)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 16))
                .focused($answerFocused)
                .onSubmit {
                    state.submit()
                }

            HStack {
                Button("Back to Home") {
                    state.goHome()
                }
                Spacer()
                Button("Submit Answer") {
                    state.submit()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: 640, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // .task must be applied INSIDE .id: with .task outside, its view
        // identity is stable across questions and the auto-play never re-runs.
        .task {
            answerFocused = true
            if mode.autoPlay {
                // Python auto-plays 250 ms after the question appears.
                try? await Task.sleep(nanoseconds: 250_000_000)
                state.speakCurrentQuestion()
            }
        }
        .id(state.current)
    }
}
