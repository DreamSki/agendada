import AgendadaCore
import SwiftUI

struct RelatedPanelContentView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @Environment(CalendarStore.self) private var calendarStore

    @State private var currentAnchorIndex: Int = 0
    @State private var hasScrolledToToday = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header (pinned)
            TimelineHeaderView(
                onScrollUp: { /* page up handled via ScrollViewProxy */ },
                onScrollDown: { /* page down handled via ScrollViewProxy */ }
            )
            .padding(.horizontal, 16)
            .padding(.top, 30) // Align with NoteStreamView capsule buttons
            .padding(.bottom, 8)

            // MARK: - Three scrollable sections
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // Timeline — 2/5 of height
                    timelineSection(height: geo.size.height * 0.4)
                        .frame(height: geo.size.height * 0.4)

                    Divider().padding(.horizontal, 16)

                    // Recent edits — 3/10 of height
                    recentSection
                        .frame(height: geo.size.height * 0.3)

                    Divider().padding(.horizontal, 16)

                    // Related notes — 3/10 of height
                    relatedSection
                        .frame(height: geo.size.height * 0.3)
                }
            }
        }
        .task {
            if calendarStore.hasAnyPermission {
                calendarStore.loadSources()
                await calendarStore.loadInitialData()
                calendarStore.mergeScheduledNotes(store.filteredNotes())
            }
        }
        .onChange(of: calendarStore.daySchedules.count) { _, _ in
            calendarStore.mergeScheduledNotes(store.filteredNotes())
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

    @ViewBuilder
    private func timelineSection(height: CGFloat) -> some View {
        if calendarStore.hasAnyPermission {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(calendarStore.daySchedules.filter { !$0.isEmpty }) { day in
                            TimelineDateRow(
                                date: day.date,
                                hasItems: !day.isEmpty,
                                notes: day.notes,
                                onNewNote: { createNoteOnDate(day.date) },
                                onNewEvent: { calendarStore.openCalendarAtDate(day.date) },
                                onSelectNote: { noteID in store.selectNote(noteID) }
                            )
                            .id(day.date)
                            .onAppear {
                                // Auto-extend range when scrolling near edges
                                Task {
                                    await calendarStore.extendRangeIfNeeded(
                                        visibleStart: day.date,
                                        visibleEnd: day.date
                                    )
                                }
                                // Update month label based on visible dates
                                calendarStore.visibleMonth = CalendarStore.formatMonth(day.date)
                            }

                            ForEach(day.allDayEvents) { event in
                                TimelineEventRow(event: event) {
                                    calendarStore.openEventInCalendar(event.id)
                                }
                            }

                            ForEach(day.timedEvents) { event in
                                TimelineEventRow(event: event) {
                                    calendarStore.openEventInCalendar(event.id)
                                }
                            }

                            ForEach(day.reminders) { reminder in
                                TimelineReminderRow(reminder: reminder)
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
                .onChange(of: calendarStore.daySchedules.count) { _, _ in
                    if !hasScrolledToToday {
                        scrollToToday(proxy: proxy)
                    }
                }
                .onChange(of: store.selectedNoteID) { _, newID in
                    guard let noteID = newID,
                          let note = store.note(withID: noteID),
                          let scheduledDate = note.scheduledDate else { return }
                    scrollToDate(scheduledDate, proxy: proxy)
                }
            }
        } else if calendarStore.eventPermission == .denied && calendarStore.reminderPermission == .denied {
            ScrollView {
                deniedView
            }
        } else {
            ScrollView {
                permissionCard
            }
        }
    }

    // MARK: - Scroll Helpers

    private func scrollToToday(proxy: ScrollViewProxy) {
        let today = Calendar.current.startOfDay(for: Date())
        scrollToDate(today, proxy: proxy)
        hasScrolledToToday = true
    }

    private func scrollToDate(_ date: Date, proxy: ScrollViewProxy) {
        let targetDay = Calendar.current.startOfDay(for: date)
        // Find the closest non-empty date to the target
        let nonEmpty = calendarStore.daySchedules.filter { !$0.isEmpty }
        if let closest = nonEmpty.min(by: {
            abs($0.date.timeIntervalSince(targetDay)) < abs($1.date.timeIntervalSince(targetDay))
        }) {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(closest.date, anchor: .top)
            }
            currentAnchorIndex = calendarStore.daySchedules.firstIndex(where: { $0.date == closest.date }) ?? 0
            calendarStore.visibleMonth = CalendarStore.formatMonth(closest.date)
        }
    }

    // MARK: - Permission Card

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Agenda + 日历 + 提醒事项")
                .font(.custom("Avenir Next Demi Bold", size: 13))
                .foregroundStyle(.primary)
                .padding(.bottom, 8)

            Text("Agendada 可以读取您的日历事件和提醒事项，在右侧面板中按日期展示。开放访问权限以享受完整功能。")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(AgendaColor.textMuted)
                .lineSpacing(4)
                .padding(.bottom, 12)

            HStack(spacing: 0) {
                Text("了解更多")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(AgendaColor.textMuted)

                Spacer()

                Button("连接") {
                    Task {
                        await calendarStore.requestAccess()
                    }
                }
                .buttonStyle(.plain)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(AgendaColor.amber)
            }
        }
        .padding(14)
        .background(AgendaColor.canvasGray, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Denied View

    private var deniedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日历访问被拒绝")
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.primary)

            Text("您可以在系统设置中重新开启 Agendada 对日历和提醒事项的访问权限。")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(AgendaColor.textMuted)
                .lineSpacing(4)

            Button("打开系统设置") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.plain)
            .font(.custom("Avenir Next Medium", size: 12))
            .foregroundStyle(AgendaColor.amber)
        }
        .padding(14)
        .background(AgendaColor.canvasGray, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func createNoteOnDate(_ date: Date) {
        let noteID = store.addNoteReturningID()
        store.scheduleDate(date, noteID: noteID)
    }

    // MARK: - Recent Edits

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelSectionHeader(title: "最近编辑", systemImage: "clock")

            ScrollView {
                let recentNotes = store.filteredNotes()
                    .sorted { $0.editedAt > $1.editedAt }
                    .prefix(8)

                if recentNotes.isEmpty {
                    emptyPanelText("无近期编辑记录")
                } else {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(recentNotes)) { note in
                            let isSelected = store.selectedNoteID == note.id
                            Button {
                                store.selectNote(note.id)
                            } label: {
                                HStack(spacing: 0) {
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(isSelected ? AgendaColor.amber : Color.clear)
                                        .frame(width: 3, height: 24)
                                        .padding(.trailing, 8)

                                    Text(note.title)
                                        .lineLimit(1)
                                        .font(.custom("Avenir Next Medium", size: 13))
                                        .foregroundStyle(note.status == .open ? Color(red: 0.20, green: 0.20, blue: 0.20) : .secondary)

                                    Spacer(minLength: 0)

                                    if let project = store.project(withID: note.projectID) {
                                        Text(project.name)
                                            .font(.custom("Avenir Next", size: 11))
                                            .foregroundStyle(AgendaColor.textMuted)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.vertical, 5)
                                .padding(.horizontal, 8)
                                .background(
                                    isSelected ? AgendaColor.amber.opacity(0.08) : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Related Notes

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelSectionHeader(title: "相关笔记", systemImage: "link")

            ScrollView {
                if let selectedNoteID = store.selectedNoteID {
                    let relatedNotes = store.relatedNotes(for: selectedNoteID)

                    if relatedNotes.isEmpty {
                        emptyPanelText("无相关笔记")
                    } else {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(relatedNotes) { relatedNote in
                                Button {
                                    store.selectNote(relatedNote.noteID)
                                } label: {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(.secondary.opacity(0.2))
                                            .frame(width: 5, height: 5)

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(relatedNote.title)
                                                .lineLimit(1)
                                                .font(.custom("Avenir Next Medium", size: 13))
                                                .foregroundStyle(Color(red: 0.25, green: 0.25, blue: 0.25))

                                            Text(relatedNote.reasons.joined(separator: " / "))
                                                .font(.custom("Avenir Next", size: 11))
                                                .foregroundStyle(AgendaColor.textMuted)
                                                .lineLimit(1)
                                        }

                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                } else {
                    emptyPanelText("选择一条笔记查看关联")
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Shared Helpers

    private func panelSectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AgendaColor.textMuted)
                .frame(width: 16)

            Text(title)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(AgendaColor.textMuted)
        }
        .padding(.horizontal, 16)
    }

    private func emptyPanelText(_ text: String) -> some View {
        Text(text)
            .font(.custom("Avenir Next", size: 12))
            .foregroundStyle(AgendaColor.textMuted.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)
    }
}
