import AgendadaCore
import SwiftUI

struct RelatedPanelContentView: View {
    @Environment(ObservableLibraryStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    timelineSection
                        .padding(.top, 16)

                    if store.selectedNote != nil {
                        quickActionsSection
                    }

                    calendarEventsSection

                    remindersSection

                    recentSection

                    relatedSection
                }
                .padding(.horizontal, AgendaSpacing.panelPaddingH)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .background(AgendaColor.panelBg)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AgendaColor.divider)
                .frame(width: 1)
        }
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.primary)
                    Text("时间轴")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Image(systemName: "mountain.2")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.25))
            }

            let counts = store.timelineCounts()

            timelineStat("今天", count: counts.today, icon: "sun.max", color: AgendaColor.amber)
            timelineStat("明天", count: counts.tomorrow, icon: "sunrise", color: .orange)
            timelineStat("昨天", count: counts.yesterday, icon: "sunset", color: AgendaColor.textMuted)

            if counts.overdue > 0 {
                timelineStat("已逾期", count: counts.overdue, icon: "exclamationmark.triangle",
                             color: Color(red: 0.95, green: 0.35, blue: 0.35))
            }

            if counts.thisWeek > 0 {
                timelineStat("本周待办", count: counts.thisWeek, icon: "calendar.badge.clock",
                             color: Color(red: 0.26, green: 0.56, blue: 0.95))
            }

            if counts.today == 0 && counts.tomorrow == 0 && counts.yesterday == 0
                && counts.overdue == 0 && counts.thisWeek == 0 {
                HStack(spacing: 6) {
                    Image(systemName: "tray")
                        .font(.system(size: 11))
                        .foregroundStyle(AgendaColor.textMuted)
                    Text("没有指定日期的笔记")
                        .font(.system(size: 12))
                        .foregroundStyle(AgendaColor.textMuted)
                }
                .padding(.leading, 4)
                .padding(.top, 2)
            }

            // Selected note date info
            if let note = store.selectedNote {
                Divider()
                    .padding(.vertical, 4)

                if let date = note.scheduledDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundStyle(AgendaColor.amber)
                        Text(dateLabel(for: date))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AgendaColor.amber)
                    }
                } else {
                    Text("当前笔记未指定日期")
                        .font(.system(size: 12))
                        .foregroundStyle(AgendaColor.textMuted)
                }

                if note.checklistSummary.totalCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checklist")
                            .font(.system(size: 10))
                        Text(note.checklistSummary.title)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(AgendaColor.textMuted)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func timelineStat(_ label: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.primary)

            Spacer()

            Text("\(count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(count > 0 ? color : AgendaColor.textMuted)
        }
        .padding(.horizontal, 4)
    }

    private func dateLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInTomorrow(date) { return "明天" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        let fm = DateFormatter()
        fm.locale = Locale(identifier: "zh_CN")
        fm.dateFormat = "M月d日 EEEE"
        return fm.string(from: date)
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelSectionHeader(title: "快捷日期", systemImage: "forward.fill")

            VStack(spacing: 0) {
                quickActionButton("今晚", systemImage: "moon.stars") {
                    scheduleForEvening()
                }

                Divider().padding(.leading, 28)

                quickActionButton("明天", systemImage: "sunrise") {
                    scheduleForTomorrow()
                }

                Divider().padding(.leading, 28)

                quickActionButton("本周末", systemImage: "calendar.badge.clock") {
                    scheduleForWeekend()
                }

                Divider().padding(.leading, 28)

                quickActionButton("下周", systemImage: "calendar") {
                    scheduleForNextWeek()
                }
            }
            .background(AgendaColor.canvasGray, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func quickActionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .foregroundStyle(AgendaColor.amber)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func scheduleForEvening() {
        guard let noteID = store.selectedNoteID else { return }
        let cal = Calendar.current
        let evening = cal.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
        store.scheduleDate(evening, noteID: noteID)
    }

    private func scheduleForTomorrow() {
        guard let noteID = store.selectedNoteID else { return }
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        store.scheduleDate(tomorrow, noteID: noteID)
    }

    private func scheduleForWeekend() {
        guard let noteID = store.selectedNoteID else { return }
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date())
        let daysUntilSaturday = (7 - weekday + 7) % 7
        let saturday = cal.date(byAdding: .day, value: max(1, daysUntilSaturday),
                                 to: cal.startOfDay(for: Date()))!
        store.scheduleDate(saturday, noteID: noteID)
    }

    private func scheduleForNextWeek() {
        guard let noteID = store.selectedNoteID else { return }
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date())
        let daysUntilNextMonday = (9 - weekday) % 7
        let nextMonday = cal.date(byAdding: .day, value: daysUntilNextMonday == 0 ? 7 : daysUntilNextMonday,
                                   to: cal.startOfDay(for: Date()))!
        store.scheduleDate(nextMonday, noteID: noteID)
    }

    // MARK: - Calendar Events Section

    private var calendarEventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelSectionHeader(title: "日历事件", systemImage: "calendar.badge.plus")

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 11))
                        .foregroundStyle(AgendaColor.textMuted)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("连接系统日历")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)

                        Text("查看和管理日历事件")
                            .font(.system(size: 11))
                            .foregroundStyle(AgendaColor.textMuted)
                    }

                    Spacer()

                    Button("连接") {
                        requestCalendarAccess()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AgendaColor.amber)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(AgendaColor.amber.opacity(0.4), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(AgendaColor.canvasGray, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func requestCalendarAccess() {
        // Placeholder — EventKit integration in P2
    }

    // MARK: - Reminders Section

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelSectionHeader(title: "提醒事项", systemImage: "checklist.checked")

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 11))
                        .foregroundStyle(AgendaColor.textMuted)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("连接提醒事项")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)

                        Text("查看和管理提醒事项")
                            .font(.system(size: 11))
                            .foregroundStyle(AgendaColor.textMuted)
                    }

                    Spacer()

                    Button("连接") {
                        requestRemindersAccess()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AgendaColor.amber)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(AgendaColor.amber.opacity(0.4), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(AgendaColor.canvasGray, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func requestRemindersAccess() {
        // Placeholder — Reminders integration in P2
    }

    // MARK: - Recent Edits

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelSectionHeader(title: "最近编辑", systemImage: "paintbrush.pointed")

            let recentNotes = store.filteredNotes()
                .sorted { $0.editedAt > $1.editedAt }
                .prefix(4)

            if recentNotes.isEmpty {
                emptyPanelText("无近期编辑记录")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(recentNotes)) { note in
                        Button {
                            store.selectNote(note.id)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                noteColorDot(note.noteColor)
                                    .padding(.top, 5)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.title)
                                        .lineLimit(1)
                                        .font(AgendaFont.panelTitle)
                                        .foregroundStyle(note.status == .open ? .primary : .secondary)

                                    if let project = store.project(withID: note.projectID) {
                                        Text(project.name)
                                            .font(AgendaFont.panelSubtitle)
                                            .foregroundStyle(AgendaColor.textMuted)
                                    }
                                }

                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Related Notes

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelSectionHeader(title: "相关笔记", systemImage: "link")

            if let selectedNoteID = store.selectedNoteID {
                let relatedNotes = store.relatedNotes(for: selectedNoteID)

                if relatedNotes.isEmpty {
                    emptyPanelText("无相关笔记")
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(relatedNotes) { relatedNote in
                            Button {
                                store.selectNote(relatedNote.noteID)
                            } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(.secondary.opacity(0.2))
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 5)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(relatedNote.title)
                                            .lineLimit(1)
                                            .font(AgendaFont.panelTitle)
                                            .foregroundStyle(.primary.opacity(0.85))

                                        Text(relatedNote.reasons.joined(separator: " / "))
                                            .font(AgendaFont.panelSubtitle)
                                            .foregroundStyle(AgendaColor.textMuted)
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 0)

                                    Text("@")
                                        .font(.system(size: 13, weight: .light))
                                        .foregroundStyle(.secondary.opacity(0.22))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                emptyPanelText("选择一条笔记查看关联")
            }
        }
    }

    // MARK: - Helpers

    private func noteColorDot(_ color: NoteColor?) -> some View {
        Circle()
            .fill(color.map { noteColorValue($0) } ?? AgendaColor.amber)
            .frame(width: 6, height: 6)
    }

    private func noteColorValue(_ color: NoteColor) -> Color {
        switch color {
        case .accent: AgendaColor.amber
        case .red: Color(red: 0.95, green: 0.35, blue: 0.35)
        case .green: Color(red: 0.28, green: 0.68, blue: 0.45)
        case .blue: Color(red: 0.26, green: 0.56, blue: 0.95)
        case .yellow: Color(red: 0.95, green: 0.80, blue: 0.15)
        case .brown: Color(red: 0.65, green: 0.45, blue: 0.30)
        case .pink: Color(red: 0.93, green: 0.36, blue: 0.62)
        case .purple: Color(red: 0.62, green: 0.35, blue: 0.85)
        case .gray: Color(red: 0.55, green: 0.55, blue: 0.60)
        }
    }

    private func panelSectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AgendaColor.textMuted)
                .frame(width: 18)

            Text(title)
                .font(AgendaFont.panelSectionHeader)
                .foregroundStyle(AgendaColor.textMuted)
        }
    }

    private func emptyPanelText(_ text: String) -> some View {
        Text(text)
            .font(AgendaFont.panelBody)
            .foregroundStyle(AgendaColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)
    }
}
