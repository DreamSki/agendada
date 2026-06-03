import AgendadaCore
import AppKit
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
    let navigateToNote: (Note.ID) -> Void

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
    /// The selectedNoteID at the moment the timeline was collapsed.
    /// Used on expand to decide whether to honour a newly selected note's date.
    @State private var savedSelectedNoteID: UUID?
    @State private var showFilterPopover = false
    @State private var filterMenuPresenter = AgendadaFloatingMenuPresenter()
    @State private var filterMenuDismissedAt = Date.distantPast
    @State private var lastScrollProcessTime: Date = .distantPast
    @State private var pendingScrollWorkItem: DispatchWorkItem?

    // Cache computed data to avoid calling store.filteredNotes() during body rendering
    @State private var cachedRecentNotes: [AgendadaCore.Note] = []
    @State private var cachedRelatedNotes: [RelatedNote] = []
    /// True when expanding after collapse — skip animation on scroll restore.
    @State private var isRestoringOnExpand = false
    /// Non-zero while a programmatic scroll is in flight.  Incremented on each
    /// new scroll; `applyTimelinePositions` no-ops while non-zero.  Cleared to
    /// 0 after the animation settles (~0.8 s).  Replaces the old timer-per-date
    /// lock with a generation counter so superseded scrolls can't unlock early.
    @State private var programmaticScrollGeneration: Int = 0

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
            refreshCachedNotes()
            await calendarStore.loadIfNeeded(withNotes: store.filteredNotes())
        }
        .onChange(of: calendarStore.hasAnyPermission) { _, hasPermission in
            if hasPermission {
                Task {
                    await calendarStore.loadIfNeeded(withNotes: store.filteredNotes())
                }
            }
        }
        .onChange(of: calendarStore.daySchedulesVersion) { _, _ in
            calendarStore.updateDisplayDaysIfNeeded()
            calendarStore.mergeScheduledNotes(store.filteredNotes())
            refreshCachedNotes()
        }
        .onChange(of: store.scheduledNotesHash) { _, _ in
            calendarStore.mergeScheduledNotes(store.filteredNotes())
            refreshCachedNotes()
        }
        .onChange(of: store.selectedNoteID) { _, _ in
            refreshCachedNotes()
        }
        .onChange(of: timelineExpanded) { _, expanded in
            if expanded {
                // Determine the right scroll target for expand (see expandScrollTarget).
                isRestoringOnExpand = true
                needsInitialScroll = true
                initialScrollDone = false
            } else {
                savedFocusedDate = focusedMonthDate
                savedSelectedNoteID = store.selectedNoteID
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
        let count = today.allDayEvents.count + today.timedEvents.count + today.reminders.count + today.notes.count
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

    private var todaySchedule: DaySchedule? {
        let today = Calendar.current.startOfDay(for: Date())
        return calendarStore.daySchedules.first {
            Calendar.current.isDate($0.date, inSameDayAs: today) && !$0.isEmpty
        }
    }

    /// Displayed day schedules — reads the cache maintained by CalendarStore.
    /// The cache is rebuilt by `onChange(of: daySchedulesVersion)` above,
    /// NOT inside this computed property.  No side effects during body eval.
    private var displayDays: [DaySchedule] {
        calendarStore.displayDays
    }

    // Cached to avoid calling store.filteredNotes() during body rendering
    // (which triggers observeRevision → AttributeGraph dependency → cycle risk)
    private var recentNotes: [AgendadaCore.Note] { cachedRecentNotes }
    private var relatedNotes: [RelatedNote] { cachedRelatedNotes }

    private func refreshCachedNotes() {
        cachedRecentNotes = Array(store.filteredNotes()
            .sorted { $0.editedAt > $1.editedAt }
            .prefix(3))
        if let sid = store.selectedNoteID {
            cachedRelatedNotes = Array(store.relatedNotes(for: sid).prefix(3))
        } else {
            cachedRelatedNotes = []
        }
    }

    // MARK: - Timeline Content

    @ViewBuilder
    private var timelineContent: some View {
        if calendarStore.hasAnyPermission {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
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
                        Color.clear
                            .onAppear { timelineViewHeight = geo.size.height }
                            .onChange(of: geo.size.height) { _, new in
                                if abs(timelineViewHeight - new) > 1 {
                                    timelineViewHeight = new
                                }
                            }
                    })
                    .coordinateSpace(name: "timeline")
                    .onPreferenceChange(TimelineRowPositionsKey.self) { positions in
                        processTimelinePositions(positions)
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
                            // Preserve scroll position tracking — the user was
                            // already scrolling when range extension triggered.
                            performInitialScroll(preserveTracking: true)
                        }
                    }
                    .onChange(of: scrollTarget) { _, target in
                        guard let target else { return }
                        if isRestoringOnExpand {
                            // No animation when restoring after collapse→expand.
                            proxy.scrollTo(target, anchor: .top)
                            isRestoringOnExpand = false
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(target, anchor: .top)
                            }
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

            // 筛选按钮
            Button {
                toggleFilterMenu()
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(calendarStore.showAllSources ? AgendaColor.panelSub : AgendaColor.amber)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showFilterPopover, arrowEdge: .bottom) {
                AgendadaFloatingMenuView(sections: filterMenuSections(), presenter: filterMenuPresenter, width: 220)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                showFilterPopover = false
            }
            .onChange(of: showFilterPopover) { _, isPresented in
                if !isPresented {
                    filterMenuDismissedAt = Date()
                }
            }

            // 同步按钮
            Button {
                Task {
                    // Lock timeline position during sync to prevent scrolling.
                    let savedDate = focusedMonthDate
                    programmaticScrollGeneration &+= 1
                    await calendarStore.syncAll(notes: store.filteredNotes())
                    // Restore to same date the user was looking at.
                    needsInitialScroll = false
                    initialScrollDone = true
                    focusedMonthDate = savedDate
                    scrollTarget = savedDate
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        programmaticScrollGeneration = 0
                    }
                }
            } label: {
                if calendarStore.isSyncing {
                    ProgressView()
                        .scaleEffect(0.65)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AgendaColor.panelSub)
                }
            }
            .buttonStyle(.plain)
            .disabled(calendarStore.isSyncing)
            .help("同步日历与提醒事项")

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

    private func performInitialScroll(preserveTracking: Bool = false) {
        needsInitialScroll = false
        if !preserveTracking {
            initialScrollDone = false
        }
        let target = expandScrollTarget()
        focusedMonthDate = target
        scrollTarget = target
        if !preserveTracking {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                initialScrollDone = true
            }
        }
    }

    private func expandScrollTarget() -> Date {
        // Only honour the currently selected note if it was *changed* while
        // the timeline was collapsed AND it has a scheduled date.
        if let currentID = store.selectedNoteID,
           currentID != savedSelectedNoteID,
           let note = store.note(withID: currentID),
           let scheduledDate = note.scheduledDate {
            return Calendar.current.startOfDay(for: scheduledDate)
        }
        // Otherwise restore the position from before the collapse.
        if let saved = savedFocusedDate {
            return saved
        }
        return Calendar.current.startOfDay(for: Date())
    }

    private func processTimelinePositions(_ positions: [Date: CGFloat]) {
        guard !positions.isEmpty else { return }

        if !initialScrollDone {
            if rowPositions.isEmpty || shouldUpdateRowPositions(positions) {
                rowPositions = positions
            }
            return
        }

        let now = Date()
        if now.timeIntervalSince(lastScrollProcessTime) > 0.15 {
            pendingScrollWorkItem?.cancel()
            pendingScrollWorkItem = nil
            applyTimelinePositions(positions)
        } else {
            pendingScrollWorkItem?.cancel()
            let work = DispatchWorkItem {
                applyTimelinePositions(positions)
                pendingScrollWorkItem = nil
            }
            pendingScrollWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        }
    }

    private func applyTimelinePositions(_ positions: [Date: CGFloat]) {
        // While a programmatic scroll or data refresh is in flight, do nothing.
        // Updating rowPositions, focusedMonthDate, or calling extendRangeIfNeeded
        // can feed back into a scroll/data-load cycle.
        guard programmaticScrollGeneration == 0 else { return }
        guard !calendarStore.isSyncing else { return }

        lastScrollProcessTime = Date()
        if shouldUpdateRowPositions(positions) {
            rowPositions = positions
        }

        guard let topDate = positions.min(by: { abs($0.value) < abs($1.value) })?.key else { return }
        let calendar = Calendar.current

        guard !calendar.isDate(topDate, inSameDayAs: focusedMonthDate) else { return }

        focusedMonthDate = topDate
        Task {
            await calendarStore.extendRangeIfNeeded(
                visibleStart: topDate,
                visibleEnd: topDate
            )
        }
    }

    private func shouldUpdateRowPositions(_ positions: [Date: CGFloat]) -> Bool {
        if positions.count != rowPositions.count { return true }
        for (date, y) in positions {
            guard let oldY = rowPositions[date] else { return true }
            if abs(oldY - y) > 1 { return true }
        }
        return false
    }

    private func scrollToToday() {
        needsInitialScroll = false
        initialScrollDone = true
        let today = Calendar.current.startOfDay(for: Date())
        programmaticScrollGeneration &+= 1
        let myGen = programmaticScrollGeneration
        focusedMonthDate = today
        scrollTarget = today
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if programmaticScrollGeneration == myGen { programmaticScrollGeneration = 0 }
        }
    }

    /// Number of `displayDays` entries that roughly fill one viewport.
    /// Derived from visible row positions when available, otherwise estimated.
    /// Capped to avoid overshooting on sparse data or unmeasured heights.
    private var entriesPerPage: Int {
        let visibleCount = rowPositions.values.filter { y in
            y >= -10 && y < timelineViewHeight + 10
        }.count
        if visibleCount >= 3 { return min(visibleCount, 8) }
        // Fallback: estimate from timeline height.  A day group with a few
        // events is typically 150–220 pt, so use 180 as the divisor.
        let estimatedRowHeight: CGFloat = 180
        guard timelineViewHeight > 0 else { return 4 }
        return max(2, min(8, Int(timelineViewHeight / estimatedRowHeight)))
    }

    /// Move the scroll target by `offset` entries in `displayDays` relative to
    /// the date closest to the top of the viewport.
    private func scrollByDisplayEntries(_ offset: Int) {
        // Prevent performInitialScroll() from hijacking the scroll when
        // extendRangeIfNeeded causes daySchedules.count to change.
        needsInitialScroll = false
        initialScrollDone = true

        let cal = Calendar.current
        let days = calendarStore.displayDays
        guard !days.isEmpty else { return }

        // Anchor on focusedMonthDate (which tracks the month label).
        // rowPositions is only used as a refinement when available.
        let anchorDay = cal.startOfDay(for: focusedMonthDate)

        // Find the closest entry in displayDays (exact, then first ≥ anchor,
        // then first ≤ anchor, then just pick the nearest).
        let anchorIndex: Int
        if let exact = days.firstIndex(where: { cal.isDate($0.date, inSameDayAs: anchorDay) }) {
            anchorIndex = exact
        } else if let after = days.firstIndex(where: { $0.date >= anchorDay }) {
            anchorIndex = after
        } else if let before = days.lastIndex(where: { $0.date <= anchorDay }) {
            anchorIndex = before
        } else {
            anchorIndex = 0
        }

        let targetIndex = max(0, min(days.count - 1, anchorIndex + offset))
        let targetDate = days[targetIndex].date

        // Lock everything during the scroll animation — prevent position
        // callbacks from triggering extendRangeIfNeeded and starting a
        // feedback loop that accelerates scrolling.
        pendingScrollWorkItem?.cancel()
        pendingScrollWorkItem = nil
        programmaticScrollGeneration &+= 1
        let myGen = programmaticScrollGeneration
        focusedMonthDate = cal.startOfDay(for: targetDate)
        // Release the lock after the animation + data load settle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if programmaticScrollGeneration == myGen { programmaticScrollGeneration = 0 }
        }
        Task {
            await calendarStore.extendRangeIfNeeded(visibleStart: targetDate, visibleEnd: targetDate)
        }
        scrollTarget = targetDate
    }

    private func scrollEarlier() {
        scrollByDisplayEntries(-entriesPerPage)
    }

    private func scrollLater() {
        scrollByDisplayEntries(+entriesPerPage)
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
                onSelectNote: { noteID in navigateToNote(noteID) }
            )

            ForEach(day.allDayEvents) { event in
                TimelineEventRow(event: event, onNavigateToNote: navigateToNote) {
                    calendarStore.openEventInCalendar(event.id)
                }
            }

            ForEach(day.timedEvents) { event in
                TimelineEventRow(event: event, onNavigateToNote: navigateToNote) {
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
            navigateToNote(note.id)
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
                            navigateToNote(relatedNote.noteID)
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

    private func toggleFilterMenu() {
        if showFilterPopover {
            showFilterPopover = false
            return
        }
        guard Date().timeIntervalSince(filterMenuDismissedAt) > 0.18 else { return }

        filterMenuPresenter.configure(
            dismiss: { showFilterPopover = false },
            showSubmenu: { _ in }
        )
        showFilterPopover = true
    }

    private func filterMenuSections() -> [AgendadaFloatingMenuSection] {
        let allSection = AgendadaFloatingMenuSection(items: [
            AgendadaFloatingMenuItem(
                iconSystemName: calendarStore.isAllSourcesEnabled ? "checkmark.square" : "square",
                title: "全部显示",
                dismissesAfterAction: false
            ) { _ in
                programmaticScrollGeneration &+= 1
                calendarStore.toggleAllSources()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    programmaticScrollGeneration = 0
                }
            }
        ])

        let eventSources = calendarStore.calendarSources.filter { $0.type == .event }
        let reminderSources = calendarStore.calendarSources.filter { $0.type == .reminder }
        var sections = [allSection]

        if !eventSources.isEmpty {
            sections.append(AgendadaFloatingMenuSection(items: eventSources.map { source in
                sourceMenuItem(source, fallbackIcon: "calendar")
            }))
        }

        if !reminderSources.isEmpty {
            sections.append(AgendadaFloatingMenuSection(items: reminderSources.map { source in
                sourceMenuItem(source, fallbackIcon: "list.bullet.rectangle")
            }))
        }

        return sections
    }

    private func sourceMenuItem(_ source: CalendarSource, fallbackIcon _: String) -> AgendadaFloatingMenuItem {
        let isEnabled = calendarStore.showAllSources || calendarStore.enabledSourceIDs.contains(source.id)
        let sourceColor = Color(
            red: source.color.red,
            green: source.color.green,
            blue: source.color.blue,
            opacity: source.color.alpha
        )
        return AgendadaFloatingMenuItem(
            iconColor: isEnabled ? sourceColor : Color.gray.opacity(0.35),
            title: source.title,
            subtitle: source.accountTitle,
            dismissesAfterAction: false
        ) { _ in
            programmaticScrollGeneration &+= 1
            calendarStore.toggleSource(source.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                programmaticScrollGeneration = 0
            }
        }
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
