import SwiftUI
import WordReviewKit

/// Calendar-picked date input (Python `DateField`): the button shows the bound
/// YYYY-MM-DD value or "Not set"; `✕` clears. No manual text entry, matching
/// the Tkinter widget.
struct DateFieldButton: View {
    @Binding var value: String
    /// Called after the value changes (Python `on_change`).
    var onChange: () -> Void

    @State private var showingCalendar = false

    var body: some View {
        HStack(spacing: 4) {
            Button(value.isEmpty ? "Not set" : value) {
                showingCalendar = true
            }
            .buttonStyle(.bordered)
            Button {
                commit("")
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Clear date")
        }
        .popover(isPresented: $showingCalendar) {
            CalendarPopupView(initial: value) { picked in
                commit(picked)
            }
        }
    }

    private func commit(_ newValue: String) {
        showingCalendar = false
        value = newValue
        onChange()
    }
}

/// Month calendar writing an ISO date (Python `CalendarPopup`): « Y / « M /
/// month label / M » / Y », a Monday-first day grid, plus Today / Clear / Close.
struct CalendarPopupView: View {
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentMonth: Date

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    init(initial: String, onPick: @escaping (String) -> Void) {
        self.onPick = onPick
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        if let parsed = formatter.date(from: initial) {
            let components = Self.calendar.dateComponents([.year, .month], from: parsed)
            _currentMonth = State(
                initialValue: Self.calendar.date(from: components) ?? Date()
            )
        } else {
            _currentMonth = State(initialValue: Date())
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button("« Y") { shift(years: -1) }
                Button("« M") { shift(months: -1) }
                    .padding(.horizontal, 2)
                Spacer()
                Text(monthTitle)
                    .frame(minWidth: 130)
                Spacer()
                Button("M »") { shift(months: 1) }
                    .padding(.horizontal, 2)
                Button("Y »") { shift(years: 1) }
            }
            .buttonStyle(.borderless)
            .font(.callout)

            let weekdayTitles = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 2), count: 7), spacing: 2) {
                ForEach(weekdayTitles, id: \.self) { title in
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .frame(width: 36, height: 28)
                }
                let days = daysInMonth
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(width: 36, height: 32)
                }
                ForEach(1...days, id: \.self) { day in
                    Button("\(day)") {
                        pick(day)
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 36, height: 32)
                }
            }

            HStack {
                Button("Today") {
                    onPick(Self.isoString(Date()))
                    dismiss()
                }
                Button("Clear") {
                    onPick("")
                    dismiss()
                }
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
        .padding(12)
    }

    private var leadingBlanks: Int {
        let weekday = Self.calendar.component(.weekday, from: currentMonth) // 1 = Sunday
        return (weekday + 6) % 7 // Monday-first offset
    }

    private var daysInMonth: Int {
        Self.calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 30
    }

    private func shift(months: Int = 0, years: Int = 0) {
        var components = DateComponents()
        components.month = months
        components.year = years
        if let shifted = Self.calendar.date(byAdding: components, to: currentMonth) {
            currentMonth = Self.calendar.date(
                from: Self.calendar.dateComponents([.year, .month], from: shifted)
            ) ?? shifted
        }
    }

    private func pick(_ day: Int) {
        var components = Self.calendar.dateComponents([.year, .month], from: currentMonth)
        components.day = day
        if let date = Self.calendar.date(from: components) {
            onPick(Self.isoString(date))
            dismiss()
        }
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// The wrong-answer list with filters (Python `ReviewMixin._build_review`).
struct ReviewListView: View {
    @Bindable var state: AppState

    private static let columns: [(title: String, width: CGFloat)] = [
        ("Time", 140),
        ("Practice", 80),
        ("Language", 140),
        ("Question", 150),
        ("Correct answer", 150),
        ("Your answer", 120),
    ]

    private var visibleIndices: [Int] {
        state.filteredIndicesUnchecked()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wrong Answer Review")
                .font(.system(size: 20, weight: .bold))

            GroupBox("Filter mistakes") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Language:")
                        Picker("Language", selection: $state.reviewLanguage) {
                            ForEach(state.languageOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 230)

                        Text("From date:")
                        DateFieldButton(value: $state.reviewFrom) {
                            state.filterChanged()
                        }

                        Text("To date:")
                        DateFieldButton(value: $state.reviewTo) {
                            state.filterChanged()
                        }
                    }
                    Text("Pick dates from the calendar; leave them unset for no bound.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(4)
            }
            .onChange(of: state.reviewLanguage) {
                state.filterChanged()
            }

            table

            HStack {
                Button("Start Review") {
                    state.startReview()
                }
                .buttonStyle(.borderedProminent)
                Button("Delete Selected") {
                    state.deleteSelected()
                }
                .padding(.leading, 10)
                Spacer()
                Button("Back to Home") {
                    state.goHome()
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            state.normalizeReviewLanguage()
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(Self.columns.indices), id: \.self) { index in
                    Text(Self.columns[index].title)
                        .font(.callout.weight(.semibold))
                        .frame(width: Self.columns[index].width, alignment: .leading)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(Color.secondary.opacity(0.15))

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(visibleIndices, id: \.self) { index in
                        row(for: index)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }

    private func row(for index: Int) -> some View {
        let entry = state.allWrongEntries[index]
        let time = entry.when.map(WrongStore.timestamp) ?? "unknown"
        let cells = [
            time,
            entry.kind,
            languageLabel(entry),
            entry.primaryText,
            entry.expected,
            entry.given,
        ]
        return HStack(spacing: 0) {
            ForEach(Array(Self.columns.indices), id: \.self) { position in
                Text(cells[position])
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: Self.columns[position].width, alignment: .leading)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(
            state.selectedRows.contains(index)
                ? Color.accentColor.opacity(0.25)
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture {
            state.toggleRow(index)
        }
    }
}
