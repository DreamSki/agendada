import AgendadaCore
import SwiftUI

// MARK: - Scroll Position Tracking

private struct TimelineRowPositionsKey: PreferenceKey {
    static let defaultValue: [Date: CGFloat] = [:]
    static func reduce(value: inout [Date: CGFloat], nextValue: () -> [Date: CGFloat]) {
        value.merge(nextValue()) { min($0, $1) }
    }
}

// MARK: - Main View

struct RelatedPanelContentView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @Environment(CalendarStore.self) private var calendarStore

    @State private var timelineExpanded = true
    @State private var recentExpanded = true
    @State private var relatedExpanded = true
    @State private var needsInitialScroll = true
    @State private var rowPositions: [Date: CGFloat] = [:]
    @State private var scrollTarget: Date?
    @State private var focusedMonthDate = Date()
    @State private var todayHovered = false
    @State private var timelineViewHeight: CGFloat = 300
    @State private var initialScrollDone = false
    @State private var savedFocusedDate: Date?
    @State private var showFilterPopover = false

    private var focusedMonth: String {
        CalendarStore.formatMonth(focusedMonthDate)
    }

    private var isTodayFocused: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        guard let todayY = rowPositions[today] else { return false }
        return todayY >= -10 && todayY < timelineViewHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 时间轴
            CollapsibleSection(
                icon: "calendar",
                title: "时间轴",
                summary: timelineSummary,
                isExpanded: $timelineExpanded,
                onIconTap: { /* TODO: open calendar picker popover */ },
                expandedLabel: { timelineExpandedLabel }
            ) {
                timelineContent
            }
            .layoutPriority(timelineExpanded ? 1 : 0)

            // MARK: - 最近编辑
            CollapsibleSection(
                icon: "clock",
                title: "最近编辑",
                summary: recentSummary,
                isExpanded: $recentExpanded
            ) {
                recentContent
            }

            // MARK: - 相关笔记
            CollapsibleSection(
                icon: "link",
                title: "相关笔记",
                summary: relatedSummary,
                isExpanded: $relatedExpanded
            ) {
                relatedContent
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 28)
        .padding(.bottom, 20)
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
        .onChange(of: scheduledNotesHash) { _, _ in
            calendarStore.mergeScheduledNotes(store.filteredNotes())
        }
        .onChange(of: timelineExpanded) { _, expanded in
            if expanded {
                needsInitialScroll = true
                initialScrollDone = false
            } else {
                savedFocusedDate = focusedMonthDate
            }
        }
        .background(AgendaColor.panelBg)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AgendaColor.divider)
                .frame(width: 1)
        }
    }

    // MARK: - Summaries

    private var timelineSummary: String? {
        guard let today = todaySchedule, !today.isEmpty else { return nil }
        let count = today.allDayEvents.count + today.timedEvents.count + today.reminders.count
        return count > 0 ? "今天 · \(count)件事" : nil
    }

    private var recentSummary: String? {
        let recent = recentNotes
        return recent.isEmpty ? nil : "\(recent.count)条更新"
    }

    private var relatedSummary: String? {
        guard store.selectedNoteID != nil else { return nil }
        let related = relatedNotes
        return related.isEmpty ? "无关联" : "\(related.count)条相关"
    }

    // MARK: - Data

    private var scheduledNotesHash: Int {
        var hasher = Hasher()
        for note in store.filteredNotes() {
            hasher.combine(note.id)
            hasher.combine(note.scheduledDate)
        }
        return hasher.finalize()
    }

    private var todaySchedule: DaySchedule? {
        let today = Calendar.current.startOfDay(for: Date())
        return calendarStore.daySchedules.first {
            Calendar.current.isDate($0.date, inSameDayAs: today) && !$0.isEmpty
        }
    }

    private var displayDays: [DaySchedule] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let nonEmpty = calendarStore.daySchedules.filter { !$0.isEmpty }

        var result = nonEmpty
        if !result.contains(where: { cal.isDate($0.date, inSameDayAs: today) }) {
            let todaySchedule = DaySchedule(date: today)
            if let insertIndex = result.firstIndex(where: { $0.date > today }) {
                result.insert(todaySchedule, at: insertIndex)
            } else {
                result.append(todaySchedule)
            }
        }
        return result
    }

    private var recentNotes: [AgendadaCore.Note] {
        Array(store.filteredNotes()
            .sorted { $0.editedAt > $1.editedAt }
            .prefix(3))
    }

    private var relatedNotes: [RelatedNote] {
        guard let selectedNoteID = store.selectedNoteID else { return [] }
        return Array(store.relatedNotes(for: selectedNoteID).prefix(3))
    }

    // MARK: - Timeline Content

    @ViewBuilder
    private var timelineContent: some View {
        if calendarStore.hasAnyPermission {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(displayDays) { day in
                                dayGroup(day)
                                    .id(day.date)
                                    .background(GeometryReader { geo in
                                        Color.clear
                                            .preference(
                                                key: TimelineRowPositionsKey.self,
                                                value: [day.date: geo.frame(in: .named("timeline")).minY]
                                            )
                                    })
                            }
                        }
                        .padding(.horizontal, AgendaSpacing.panelPaddingH)
                        .padding(.bottom, 12)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(AgendaColor.panelSpine)
                                .frame(width: 1)
                                .padding(.leading, AgendaSpacing.panelSpineLeading)
                        }
                    }
                    .frame(minHeight: 200)
                    .background(GeometryReader { geo in
                        Color.clear.onAppear { timelineViewHeight = geo.size.height }
                            .onChange(of: geo.size.height) { _, new in timelineViewHeight = new }
                    })
                    .coordinateSpace(name: "timeline")
                    .onPreferenceChange(TimelineRowPositionsKey.self) { positions in
                        rowPositions = positions
                        guard initialScrollDone else { return }
                        if let topDate = positions.min(by: { abs($0.value) < abs($1.value) })?.key {
                            focusedMonthDate = topDate
                            Task {
                                await calendarStore.extendRangeIfNeeded(
                                    visibleStart: topDate,
                                    visibleEnd: topDate
                                )
                            }
                        }
                    }
                    .onAppear {
                        needsInitialScroll = true
                        initialScrollDone = false
                        if !calendarStore.daySchedules.isEmpty {
                            performInitialScroll()
                        }
                    }
                    .onChange(of: calendarStore.daySchedules.count) { _, _ in
                        if needsInitialScroll && !calendarStore.daySchedules.isEmpty {
                            performInitialScroll()
                        }
                    }
                    .onChange(of: store.selectedNoteID) { _, newID in
                        guard let noteID = newID,
                              let note = store.note(withID: noteID),
                              let scheduledDate = note.scheduledDate else { return }
                        let targetDay = Calendar.current.startOfDay(for: scheduledDate)
                        focusedMonthDate = targetDay
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(targetDay, anchor: .top)
                        }
                    }
                    .onChange(of: scrollTarget) { _, target in
                        guard let target else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                        DispatchQueue.main.async { scrollTarget = nil }
                    }
                }
            }
            .padding(.top, 4)
        } else if calendarStore.eventPermission == .denied && calendarStore.reminderPermission == .denied {
            deniedView
                .padding(.horizontal, AgendaSpacing.panelPaddingH)
                .padding(.top, 6)
                .padding(.bottom, 12)
        } else {
            permissionCard
                .padding(.horizontal, AgendaSpacing.panelPaddingH)
                .padding(.top, 6)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Timeline Expanded Label

    private var timelineExpandedLabel: some View {
        HStack(spacing: 10) {
            Text(focusedMonth)
                .font(AgendaFont.panelHeader)
                .foregroundStyle(AgendaColor.panelHeading)

            Button {
                showFilterPopover = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(calendarStore.showAllSources ? AgendaColor.panelSub : AgendaColor.amber)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showFilterPopover, arrowEdge: .bottom) {
                filterPopover
            }

            Spacer()

            HStack(spacing: 2) {
                Button {
                    scrollToToday()
                } label: {
                    Image(systemName: (isTodayFocused || todayHovered) ? "circle.fill" : "circle")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(isTodayFocused ? AgendaColor.amber : AgendaColor.panelHint)
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .contentShape(Circle())
                .onHover { todayHovered = $0 }
                .help("回到今天")

                Button {
                    scrollEarlier()
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AgendaColor.panelSub)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.gray.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("向前 — 查看更早的日期")

                Button {
                    scrollLater()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AgendaColor.panelSub)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.gray.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("向后 — 查看更晚的日期")
            }
        }
    }

    // MARK: - Scroll Actions

    private func performInitialScroll() {
        needsInitialScroll = false
        initialScrollDone = false
        let target = expandScrollTarget()
        focusedMonthDate = target
        scrollTarget = target
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            initialScrollDone = true
        }
    }

    private func expandScrollTarget() -> Date {
        if let noteID = store.selectedNoteID,
           let note = store.note(withID: noteID),
           let scheduledDate = note.scheduledDate {
            return Calendar.current.startOfDay(for: scheduledDate)
        }
        if let saved = savedFocusedDate {
            return saved
        }
        return Calendar.current.startOfDay(for: Date())
    }

    private func scrollToToday() {
        let today = Calendar.current.startOfDay(for: Date())
        focusedMonthDate = today
        scrollTarget = today
    }

    private func scrollEarlier() {
        guard !rowPositions.isEmpty else { return }

        let currentTopY = rowPositions.min(by: { abs($0.value) < abs($1.value) })?.value ?? 0
        let targetY = currentTopY - timelineViewHeight

        guard let closest = rowPositions.min(by: { abs($0.value - targetY) < abs($1.value - targetY) }) else { return }

        focusedMonthDate = closest.key
        Task {
            await calendarStore.extendRangeIfNeeded(visibleStart: closest.key, visibleEnd: closest.key)
        }
        scrollTarget = closest.key
    }

    private func scrollLater() {
        guard !rowPositions.isEmpty else { return }

        let currentTopY = rowPositions.min(by: { abs($0.value) < abs($1.value) })?.value ?? 0
        let targetY = currentTopY + timelineViewHeight

        guard let closest = rowPositions.min(by: { abs($0.value - targetY) < abs($1.value - targetY) }) else { return }

        focusedMonthDate = closest.key
        Task {
            await calendarStore.extendRangeIfNeeded(visibleStart: closest.key, visibleEnd: closest.key)
        }
        scrollTarget = closest.key
    }

    // MARK: - Day Group

    @ViewBuilder
    private func dayGroup(_ day: DaySchedule) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            TimelineDateRow(
                date: day.date,
                hasItems: !day.isEmpty,
                notes: day.notes,
                onNewNote: { createNoteOnDate(day.date) },
                onNewEvent: { calendarStore.openCalendarAtDate(day.date) },
                onSelectNote: { noteID in store.selectNote(noteID) }
            )

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
        .padding(.top, Calendar.current.isDateInToday(day.date) ? AgendaSpacing.timelineTodayTopSpacing : 6)
    }

    // MARK: - Recent Content

    @ViewBuilder
    private var recentContent: some View {
        VStack(spacing: 0) {
            if recentNotes.isEmpty {
                PanelEmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "暂无最近编辑",
                    subtitle: "编辑过的笔记会显示在这里"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentNotes.enumerated()), id: \.element.id) { index, note in
                        recentNoteRow(note)

                        if index < recentNotes.count - 1 {
                            Rectangle()
                                .fill(AgendaColor.panelWarmDivider)
                                .frame(height: 1)
                                .padding(.leading, 32)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.02), radius: 4, y: 2)
                )
                .padding(.horizontal, AgendaSpacing.panelPaddingH)
                .padding(.bottom, 12)
            }
        }
    }

    private func recentNoteRow(_ note: AgendadaCore.Note) -> some View {
        let isSelected = store.selectedNoteID == note.id

        return Button {
            store.selectNote(note.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(AgendaColor.amber)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(AgendaFont.panelBodyMedium)
                        .foregroundStyle(note.status == .open ? AgendaColor.panelHeading : AgendaColor.panelSub)
                        .lineLimit(1)

                    HStack(spacing: 3) {
                        if let project = store.project(withID: note.projectID) {
                            Text(project.name)
                            Text("·")
                        }
                        Text(relativeTime(note.editedAt))
                    }
                    .font(AgendaFont.panelCaption)
                    .foregroundStyle(AgendaColor.panelSub)
                    .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? AgendaColor.panelHover : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Related Content

    @ViewBuilder
    private var relatedContent: some View {
        VStack(spacing: 0) {
            if store.selectedNoteID == nil {
                PanelEmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "选择笔记查看关联",
                    subtitle: "点击左侧笔记查看相关内容"
                )
            } else if relatedNotes.isEmpty {
                PanelEmptyStateView(
                    icon: "link.circle",
                    title: "暂无相关笔记",
                    subtitle: relatedEmptySubtitle
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(relatedNotes.enumerated()), id: \.element.noteID) { index, relatedNote in
                        Button {
                            store.selectNote(relatedNote.noteID)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(AgendaColor.amber)
                                    .frame(width: 4, height: 4)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(relatedNote.title)
                                        .font(AgendaFont.panelBodyMedium)
                                        .foregroundStyle(AgendaColor.panelHeading)
                                        .lineLimit(1)

                                    Text(relatedNote.reasons.joined(separator: " / "))
                                        .font(AgendaFont.panelCaption)
                                        .foregroundStyle(AgendaColor.panelSub)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < relatedNotes.count - 1 {
                            Rectangle()
                                .fill(AgendaColor.panelWarmDivider)
                                .frame(height: 1)
                                .padding(.leading, 22)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.02), radius: 4, y: 2)
                )
                .padding(.horizontal, AgendaSpacing.panelPaddingH)
                .padding(.bottom, 12)
            }
        }
    }

    private var relatedEmptySubtitle: String? {
        guard let selectedNoteID = store.selectedNoteID,
              let note = store.note(withID: selectedNoteID) else { return nil }
        return "与「\(note.title)」相关的笔记会显示在这里"
    }

    // MARK: - Filter Popover

    private var filterPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                calendarStore.toggleAllSources()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: calendarStore.isAllSourcesEnabled ? "checkmark.square" : "square")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    Text("全部显示")
                        .font(AgendaFont.panelBody)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Divider().padding(.horizontal, 8)

            let eventSources = calendarStore.calendarSources.filter { $0.type == .event }
            if !eventSources.isEmpty {
                Text("日历")
                    .font(AgendaFont.panelMicro)
                    .foregroundStyle(AgendaColor.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                ForEach(eventSources) { source in
                    sourceToggle(source)
                }
                Divider().padding(.horizontal, 8)
            }

            let reminderSources = calendarStore.calendarSources.filter { $0.type == .reminder }
            if !reminderSources.isEmpty {
                Text("提醒事项")
                    .font(AgendaFont.panelMicro)
                    .foregroundStyle(AgendaColor.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                ForEach(reminderSources) { source in
                    sourceToggle(source)
                }
            }
        }
        .frame(width: 200)
        .padding(.vertical, 4)
    }

    private func sourceToggle(_ source: CalendarSource) -> some View {
        let isEnabled = calendarStore.showAllSources || calendarStore.enabledSourceIDs.contains(source.id)
        return Button {
            calendarStore.toggleSource(source.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isEnabled ? "checkmark.square" : "square")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                Circle()
                    .fill(Color(
                        red: source.color.red,
                        green: source.color.green,
                        blue: source.color.blue,
                        opacity: source.color.alpha
                    ))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(source.title)
                        .font(AgendaFont.panelBody)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(source.accountTitle)
                        .font(AgendaFont.panelMicro)
                        .foregroundStyle(AgendaColor.textMuted)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Permission / Denied

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Agenda + 日历 + 提醒事项")
                .font(AgendaFont.panelBodyMedium)
                .foregroundStyle(.primary)
                .padding(.bottom, 6)

            Text("Agendada 可以读取您的日历事件和提醒事项，在右侧面板中按日期展示。开放访问权限以享受完整功能。")
                .font(AgendaFont.panelCaption)
                .foregroundStyle(AgendaColor.textMuted)
                .lineSpacing(3)
                .padding(.bottom, 10)

            HStack(spacing: 0) {
                Text("了解更多")
                    .font(AgendaFont.panelCaption)
                    .foregroundStyle(AgendaColor.textMuted)
                Spacer()
                Button("连接") {
                    Task { await calendarStore.requestAccess() }
                }
                .buttonStyle(.plain)
                .font(AgendaFont.panelCaption)
                .foregroundStyle(AgendaColor.amber)
            }
        }
        .padding(12)
        .background(AgendaColor.canvasGray, in: RoundedRectangle(cornerRadius: 8))
    }

    private var deniedView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("日历访问被拒绝")
                .font(AgendaFont.panelBodyMedium)
                .foregroundStyle(.primary)

            Text("您可以在系统设置中重新开启 Agendada 对日历和提醒事项的访问权限。")
                .font(AgendaFont.panelCaption)
                .foregroundStyle(AgendaColor.textMuted)
                .lineSpacing(3)

            Button("打开系统设置") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.plain)
            .font(AgendaFont.panelCaption)
            .foregroundStyle(AgendaColor.amber)
        }
        .padding(12)
        .background(AgendaColor.canvasGray, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private func createNoteOnDate(_ date: Date) {
        let noteID = store.addNoteReturningID()
        store.scheduleDate(date, noteID: noteID)
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600))小时前" }
        if interval < 172800 { return "昨天" }
        if interval < 604800 { return "\(Int(interval / 86400))天前" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
