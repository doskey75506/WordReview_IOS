import SwiftUI
import WordReviewKit

/// The review quiz question (Python `ReviewMixin._build_review_question`).
///
/// `.id(state.reviewPos)` rebuilds per question, resetting focus/answer and
/// re-triggering the dictation auto-play.
struct ReviewQuestionView: View {
    @Bindable var state: AppState
    @FocusState private var answerFocused: Bool

    private var entry: WrongEntry {
        state.currentReviewEntry
    }

    private var mode: PracticeMode {
        state.currentReviewMode
    }

    private var view: QuestionView {
        mode.view(
            primaryLanguage: entry.primaryLanguage,
            secondaryLanguage: entry.secondaryLanguage,
            primaryText: entry.primaryText,
            listenHint: false
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wrong Answer Review")
                .font(.system(size: 20, weight: .bold))
            Text("Question \(state.reviewPos + 1) of \(state.reviewQueue.count)")
                .padding(.bottom, 8)

            Text(view.prompt)
            if !view.display.isEmpty {
                Text(view.display)
                    .font(.system(size: 18))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 6)
            }
            Text("Your previous answer: \(entry.given.isEmpty ? "(blank)" : entry.given)")
                .padding(.bottom, 6)

            if mode.autoPlay {
                Button("▶ Play Audio") {
                    state.speakCurrentReview()
                }
                .padding(.bottom, 4)
            }

            Text(view.instruction)

            TextField("Answer", text: $state.answer)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 16))
                .focused($answerFocused)
                .onSubmit {
                    state.reviewSubmit()
                }

            HStack {
                Button("Back to Review List") {
                    state.screen = .reviewList
                }
                Spacer()
                Button("Submit Answer") {
                    state.reviewSubmit()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: 640, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // .task must be applied INSIDE .id, or auto-play never re-runs after
        // the first question (same bug as PracticeQuestionView).
        .task {
            answerFocused = true
            if mode.autoPlay {
                try? await Task.sleep(nanoseconds: 250_000_000)
                state.speakCurrentReview()
            }
        }
        .id(state.reviewPos)
    }
}
