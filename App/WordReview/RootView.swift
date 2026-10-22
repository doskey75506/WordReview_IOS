import SwiftUI

struct RootView: View {
    @Bindable var state: AppState

    var body: some View {
        Group {
            switch state.screen {
            case .home:
                HomeView(state: state)
            case .question:
                PracticeQuestionView(state: state)
            case .reviewList:
                ReviewListView(state: state)
            case .reviewQuestion:
                ReviewQuestionView(state: state)
            case .wordList:
                WordListView(state: state)
            case .wordEditor:
                WordEditorView(state: state)
            }
        }
        .tint(.blue)
        .alert(
            state.alert?.title ?? "",
            isPresented: Binding(
                get: { state.alert != nil },
                set: { presented in
                    if !presented {
                        state.alert = nil
                    }
                }
            )
        ) {
            if let cancelTitle = state.alert?.cancelTitle {
                Button(cancelTitle, role: .cancel) {
                    state.alert = nil
                }
            }
            Button(state.alert?.okTitle ?? "OK", role: state.alert?.cancelTitle == nil ? nil : .destructive) {
                let callback = state.alert?.onOK
                state.alert = nil
                // Run on the next turn so a follow-up alert (e.g. the
                // "Complete" dialog after "Answer Recorded") presents cleanly.
                DispatchQueue.main.async {
                    callback?()
                }
            }
        } message: {
            Text(state.alert?.message ?? "")
        }
    }
}
