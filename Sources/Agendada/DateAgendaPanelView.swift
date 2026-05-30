import SwiftUI
import AgendadaCore

/// 日期选择 + 日程面板，popover 内呈现
struct DateAgendaPanelView: View {
    @Environment(ObservableLibraryStore.self) private var store

    let noteID: Note.ID
    let onDismiss: () -> Void

    @State private var selectedDate: Date?
    @State private var hasSelection = false
    @State private var calendarMonth: Date

    private let calendar: Calendar = {
        var c = Calendar.current
        c.locale = Locale(identifier: "zh_CN")
        return c
    }()

    private let cellHeight: CGFloat = 38
    private let panelHPadding: CGFloat = 18
    private let leftPanelWidth: CGFloat = 310
    private let rightPanelWidth: CGFloat = 270

    init(noteID: Note.ID, onDismiss: @escaping () -> Void) {
        self.noteID = noteID
        self.onDismiss = onDismiss
        _calendarMonth = State(initialValue: Date())
    }

    private var note: Note? { store.note(withID: noteID) }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Left: Calendar
            VStack(spacing: 0) {
                monthHeaderView
                weekdayHeaderView
                calendarGridView
                Spacer(minLength: 0)
            }
            .frame(width: leftPanelWidth)
            .frame(maxHeight: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 44)

            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(width: 1)

            // Right: Agenda
            VStack(alignment: .leading, spacing: 0) {
                Text("日历日程")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, panelHPadding)
                    .padding(.bottom, 14)

                agendaContent
                Spacer(minLength: 0)
            }
            .frame(width: rightPanelWidth)
            .frame(maxHeight: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 44)
        }
        .frame(width: leftPanelWidth + 1 + rightPanelWidth, height: 420)
        .overlay(alignment: .bottom) {
            bottomBar
        }
        .onAppear {
            if let sd = note?.scheduledDate {
                selectedDate = calendar.startOfDay(for: sd)
                hasSelection = true
                calendarMonth = sd
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1)
            HStack(spacing: 0) {
                if hasSelection, let sd = selectedDate {
                    Text(formattedDate(sd))
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if note?.scheduledDate != nil {
                    Button("清除日期") {
                        store.clearScheduledDate(noteID: noteID)
                        onDismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 12)
                }
                Button("指定日期") {
                    if hasSelection, let sd = selectedDate {
                        store.scheduleDate(sd, noteID: noteID)
                    }
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(hasSelection ? .white : AgendaColor.amber.opacity(0.5))
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hasSelection ? AgendaColor.amber : AgendaColor.amber.opacity(0.10))
                )
            }
            .padding(.horizontal, panelHPadding).padding(.vertical, 10)
        }
    }

    // MARK: - Left subviews

    private var monthHeaderView: some View {
        HStack(spacing: 10) {
            Text(monthYearString(calendarMonth))
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            Button("今天") {
                calendarMonth = calendar.startOfDay(for: Date())
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AgendaColor.amber)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 4).fill(AgendaColor.amber.opacity(0.08)))
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.horizontal, panelHPadding).padding(.bottom, 12)
    }

    private var weekdayHeaderView: some View {
        HStack(spacing: 0) {
            ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { d in
                Text(d)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, panelHPadding).padding(.bottom, 6)
    }

    private var calendarGridView: some View {
        let today = calendar.startOfDay(for: Date())
        let days = daysInMonth(calendarMonth)
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: calendarMonth))!
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingEmpties = (firstWeekday - calendar.firstWeekday + 7) % 7
        let totalCells = leadingEmpties + days
        let rows = Int(ceil(Double(totalCells) / 7.0))
        let notesOnDates = scheduledNoteDates(in: startOfMonth, days: days)

        return VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let cellIndex = row * 7 + col
                        let isEmpty = cellIndex < leadingEmpties || cellIndex >= totalCells

                        if isEmpty {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: cellHeight, maxHeight: cellHeight)
                        } else {
                            let day = cellIndex - leadingEmpties + 1
                            let cellDate = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)!
                            let isSelected = hasSelection && calendar.isDate(cellDate, inSameDayAs: selectedDate ?? Date())
                            let isTodayCell = calendar.isDate(cellDate, inSameDayAs: today)
                            let hasNotes = notesOnDates.contains(day)

                            Button {
                                if isSelected {
                                    hasSelection = false
                                    selectedDate = nil
                                } else {
                                    hasSelection = true
                                    selectedDate = calendar.startOfDay(for: cellDate)
                                }
                            } label: {
                                ZStack {
                                    if isSelected {
                                        Circle()
                                            .fill(AgendaColor.amber)
                                            .frame(width: 29, height: 29)
                                    }
                                    Text("\(day)")
                                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(
                                            isSelected ? .white
                                                : isTodayCell ? AgendaColor.amber
                                                : .primary
                                        )
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .overlay(alignment: .bottom) {
                                    if hasNotes && !isSelected {
                                        Circle()
                                            .fill(AgendaColor.amber.opacity(0.7))
                                            .frame(width: 5, height: 5)
                                            .padding(.bottom, 4)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, minHeight: cellHeight, maxHeight: cellHeight)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, panelHPadding)
    }

    // MARK: - Right: Agenda

    private var agendaContent: some View {
        let notes: [Note] = {
            if hasSelection, let sd = selectedDate {
                return scheduledNotesForDate(sd)
            }
            if let sd = note?.scheduledDate {
                return scheduledNotesForDate(sd)
            }
            return []
        }()

        if notes.isEmpty {
            return AnyView(
                Text("当日暂无排期")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            )
        }
        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                Text("已排期笔记")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, panelHPadding).padding(.bottom, 8)
                ForEach(notes) { n in
                    HStack(spacing: 8) {
                        Circle().fill(noteColor(n.noteColor)).frame(width: 8, height: 8)
                        Text(n.title.isEmpty ? "无标题" : n.title)
                            .font(.system(size: 14))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, panelHPadding).padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture { store.selectNote(n.id); onDismiss() }
                }
            }
        )
    }

    // MARK: - Helpers

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: calendarMonth) {
            calendarMonth = d
        }
    }

    private func scheduledNotesForDate(_ date: Date) -> [Note] {
        store.filteredNotes().filter { n in
            guard let d = n.scheduledDate, n.id != noteID else { return false }
            return calendar.isDate(d, inSameDayAs: date)
        }
    }

    private func scheduledNoteDates(in startOfMonth: Date, days: Int) -> Set<Int> {
        var result = Set<Int>()
        for day in 1...days {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) else { continue }
            if store.filteredNotes().contains(where: { n in
                guard let d = n.scheduledDate else { return false }
                return calendar.isDate(d, inSameDayAs: date)
            }) { result.insert(day) }
        }
        return result
    }

    private func daysInMonth(_ date: Date) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private func monthYearString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.setLocalizedDateFormatFromTemplate("M月d日 EEEE")
        return "日期：\(f.string(from: date))"
    }

    private func noteColor(_ c: NoteColor?) -> Color {
        guard let c else { return AgendaColor.amber }
        return switch c {
        case .accent: AgendaColor.amber
        case .red:    Color(red: 0.95, green: 0.35, blue: 0.35)
        case .green:  Color(red: 0.28, green: 0.68, blue: 0.45)
        case .blue:   Color(red: 0.26, green: 0.56, blue: 0.95)
        case .yellow: Color(red: 0.95, green: 0.80, blue: 0.15)
        case .brown:  Color(red: 0.65, green: 0.45, blue: 0.30)
        case .pink:   Color(red: 0.93, green: 0.36, blue: 0.62)
        case .purple: Color(red: 0.62, green: 0.35, blue: 0.85)
        case .gray:   Color(red: 0.55, green: 0.55, blue: 0.60)
        }
    }
}

#Preview {
    DateAgendaPanelView(noteID: UUID(), onDismiss: {})
        .environment(ObservableLibraryStore(seed: .sample()))
}
