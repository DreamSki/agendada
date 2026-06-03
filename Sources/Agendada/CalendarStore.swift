import AgendadaCore
import AppKit
import Observation
import OSLog
import SwiftUI

private let log = Logger(subsystem: "com.agendada", category: "CalendarStore")

@Observable
@MainActor
final class CalendarStore {
    // MARK: - Dependencies

    private let repository: CalendarRepository

    // MARK: - Published State

    var eventPermission: CalendarPermissionStatus = .notDetermined
    var reminderPermission: CalendarPermissionStatus = .notDetermined
    var daySchedules: [DaySchedule] = []
    var visibleMonth: String = ""

    // Source filtering
    var calendarSources: [CalendarSource] = []
    var showAllSources: Bool = true
    var enabledSourceIDs: Set<String> = []

    /// True while a full sync is in progress — drive a spinner in the header.
    var isSyncing = false

    /// Bumped every time daySchedules is replaced or merged so caches stay fresh.
    var daySchedulesVersion: Int = 0

    // MARK: - Display Days Cache

    /// Cached displayDays (non-empty only, today always present).
    /// Updated by `updateDisplayDaysIfNeeded()` — call from `onChange` not from
    /// inside a View `body` / computed property.
    private(set) var displayDays: [DaySchedule] = []
    private var displayDaysSourceHash: Int = 0

    // MARK: - Private State

    @ObservationIgnored private var loadedStartDate: Date?
    @ObservationIgnored private var loadedEndDate: Date?
    @ObservationIgnored private var initialLoadDone = false
    @ObservationIgnored private var isExtending = false
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    /// Incremented on each refresh() call.  Only the Task that observes the
    /// latest generation is allowed to clear `isSyncing`.
    @ObservationIgnored private var refreshGeneration: Int = 0
    /// Notes snapshot provided by the most recent merge — reused during sync
    /// so we don't have to recalc from the store.
    @ObservationIgnored private var lastMergedNotes: [AgendadaCore.Note] = []

    // MARK: - Init

    init(repository: CalendarRepository = CalendarRepository()) {
        self.repository = repository
        let now = Date()
        visibleMonth = Self.formatMonth(now)
        refreshPermissions()
    }

    // MARK: - Permissions

    private func refreshPermissions() {
        eventPermission = repository.eventPermissionStatus
        reminderPermission = repository.reminderPermissionStatus
    }

    var hasAnyPermission: Bool {
        eventPermission == .granted || reminderPermission == .granted
    }

    var allGranted: Bool {
        eventPermission == .granted && reminderPermission == .granted
    }

    func requestAccess() async {
        let eventOK = await repository.requestEventAccess()
        let reminderOK = await repository.requestReminderAccess()
        refreshPermissions()

        if eventOK || reminderOK {
            await loadSources()
            await loadInitialData()
        }
    }

    // MARK: - Sources

    func loadSources() async {
        var sources: [CalendarSource] = []
        if eventPermission == .granted {
            sources.append(contentsOf: await repository.fetchEventSources())
        }
        if reminderPermission == .granted {
            sources.append(contentsOf: await repository.fetchReminderSources())
        }
        calendarSources = sources
    }

    func toggleSource(_ sourceID: String) {
        if showAllSources {
            showAllSources = false
            enabledSourceIDs = Set(calendarSources.map { $0.id }.filter { $0 != sourceID })
        } else {
            if enabledSourceIDs.contains(sourceID) {
                enabledSourceIDs.remove(sourceID)
                if enabledSourceIDs.count == calendarSources.count {
                    showAllSources = true
                    enabledSourceIDs.removeAll()
                }
            } else {
                enabledSourceIDs.insert(sourceID)
                if enabledSourceIDs.count == calendarSources.count {
                    showAllSources = true
                    enabledSourceIDs.removeAll()
                }
            }
        }
        Task { await refresh() }
    }

    var isAllSourcesEnabled: Bool { showAllSources }

    func toggleAllSources() {
        if showAllSources {
            showAllSources = false
            enabledSourceIDs.removeAll()
        } else {
            showAllSources = true
            enabledSourceIDs.removeAll()
        }
        Task { await refresh() }
    }

    // MARK: - Data Loading

    /// Call once from the View after permissions are granted to kick off the
    /// initial load.  Safe to call multiple times — skips if already loaded.
    func loadIfNeeded(withNotes notes: [AgendadaCore.Note] = []) async {
        guard !initialLoadDone else {
            // Still merge notes even if schedules are already loaded
            if !notes.isEmpty { mergeScheduledNotes(notes) }
            return
        }
        loadTask?.cancel()
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard hasAnyPermission else { return }
            await loadSources()
            await loadInitialData()
            let notes = notes.isEmpty ? lastMergedNotes : notes
            mergeScheduledNotes(notes)
        }
        _ = await loadTask?.value
    }

    /// Full sync: reload calendar sources from EventKit, then re-fetch the
    /// entire loaded range.  Drives `isSyncing` so the UI can show a spinner.
    func syncAll(notes: [AgendadaCore.Note] = []) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        // Cancel in-flight work
        refreshTask?.cancel()
        refreshTask = nil

        // 1. Refresh permission status
        refreshPermissions()

        // 2. Reload sources (user may have added/removed calendars in System Settings).
        //    Don't touch the filter — the user's selection is authoritative.
        await loadSources()

        // 4. Reload the loaded range (or initial range if nothing loaded yet)
        let start: Date
        let end: Date
        if let ls = loadedStartDate, let le = loadedEndDate {
            start = ls
            end = le
        } else {
            let today = Calendar.current.startOfDay(for: Date())
            start = Calendar.current.date(byAdding: .day, value: -30, to: today)!
            end = Calendar.current.date(byAdding: .day, value: 60, to: today)!
        }

        let t0 = CFAbsoluteTimeGetCurrent()
        let schedules = await fetchSchedules(from: start, to: end)
        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        if elapsed > 0.1 {
            log.debug("syncAll fetch \(start.formatted(.iso8601))…\(end.formatted(.iso8601)) took \(String(format: "%.3f", elapsed))s (\(schedules.count) days)")
        }
        mergeSchedules(schedules, updateRange: true, replaceOverlap: true)

        // 5. Re-merge notes
        let notesToMerge = notes.isEmpty ? lastMergedNotes : notes
        mergeScheduledNotes(notesToMerge)
    }

    func mergeScheduledNotes(_ notes: [AgendadaCore.Note]) {
        lastMergedNotes = notes
        let cal = Calendar.current
        var noteMap: [Date: [ScheduledNoteInfo]] = [:]
        for note in notes {
            guard let scheduled = note.scheduledDate else { continue }
            let day = cal.startOfDay(for: scheduled)
            noteMap[day, default: []].append(
                ScheduledNoteInfo(id: note.id, title: note.title, projectID: note.projectID)
            )
        }
        for i in daySchedules.indices {
            let day = daySchedules[i].date
            daySchedules[i].notes = noteMap[day] ?? []
        }
        // Notes-only mutations don't bump daySchedulesVersion, so the hash
        // guard in updateDisplayDaysIfNeeded won't trigger.  Rebuild directly.
        rebuildDisplayDays()
    }

    func loadInitialData() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // -30/+60 days (~90 day window).  Scrolling to edges triggers on-demand extension.
        let start = cal.date(byAdding: .day, value: -30, to: today)!
        let end = cal.date(byAdding: .day, value: 60, to: today)!

        await loadSchedule(from: start, to: end)
        initialLoadDone = true
    }

    func loadSchedule(from startDate: Date, to endDate: Date) async {
        let t0 = CFAbsoluteTimeGetCurrent()
        let schedules = await fetchSchedules(from: startDate, to: endDate)
        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        if elapsed > 0.1 {
            log.debug("loadSchedule \(startDate.formatted(.iso8601))…\(endDate.formatted(.iso8601)) took \(String(format: "%.3f", elapsed))s (\(schedules.count) days)")
        }
        mergeSchedules(schedules, updateRange: true)
    }

    /// Fetch events and reminders for a date range → `[DaySchedule]`.
    /// Heavy EventKit calls run on the `CalendarRepository` actor (off main thread).
    private func fetchSchedules(from startDate: Date, to endDate: Date) async -> [DaySchedule] {
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: startDate)
        let endDay = cal.startOfDay(for: endDate)

        let eventCalendarIDs = showAllSources ? nil : enabledSourceIDs
        let reminderCalendarIDs = showAllSources ? nil : enabledSourceIDs

        var events: [CalendarEvent] = []
        if eventPermission == .granted {
            let t0 = CFAbsoluteTimeGetCurrent()
            events = (try? await repository.fetchEvents(
                from: startDay,
                to: cal.date(byAdding: .day, value: 1, to: endDay)!,
                calendarIDs: eventCalendarIDs
            )) ?? []
            let elapsed = CFAbsoluteTimeGetCurrent() - t0
            if elapsed > 0.05 {
                log.debug("fetchEvents took \(String(format: "%.3f", elapsed))s → \(events.count) events")
            }
        }

        var reminders: [CalendarReminder] = []
        if reminderPermission == .granted {
            let t0 = CFAbsoluteTimeGetCurrent()
            reminders = await repository.fetchReminders(
                from: startDay, to: endDay, calendarIDs: reminderCalendarIDs
            )
            let elapsed = CFAbsoluteTimeGetCurrent() - t0
            if elapsed > 0.05 {
                log.debug("fetchReminders took \(String(format: "%.3f", elapsed))s → \(reminders.count) reminders")
            }
        }

        var dayMap: [Date: DaySchedule] = [:]
        var currentDay = startDay
        while currentDay <= endDay {
            dayMap[currentDay] = DaySchedule(date: currentDay)
            currentDay = cal.date(byAdding: .day, value: 1, to: currentDay)!
        }

        for event in events {
            let eventStartDay = cal.startOfDay(for: event.startDate)
            let eventEndDay = cal.startOfDay(for: event.endDate)

            if event.isAllDay {
                // EventKit all-day events have two conventions depending on source:
                // - Multi-day:  endDate is exclusive (start of next day) → use `<`
                // - Single-day: endDate == startDate (same midnight)   → need `<=`
                // We handle both by ensuring at least one day is always added,
                // treating same-day start/end as a 1-day span.
                var day = eventStartDay
                let effectiveEnd = max(eventEndDay, cal.date(byAdding: .day, value: 1, to: eventStartDay)!)
                while day < effectiveEnd, day <= endDay {
                    dayMap[day]?.allDayEvents.append(event)
                    day = cal.date(byAdding: .day, value: 1, to: day)!
                }
            } else {
                dayMap[eventStartDay]?.timedEvents.append(event)
            }
        }

        for reminder in reminders {
            if let due = reminder.dueDate {
                let dueDay = cal.startOfDay(for: due)
                dayMap[dueDay]?.reminders.append(reminder)
            }
        }

        for key in dayMap.keys {
            dayMap[key]?.timedEvents.sort { $0.startDate < $1.startDate }
            dayMap[key]?.reminders.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }

        return dayMap.values.sorted { $0.date < $1.date }
    }

    /// Merge fetched schedules into `daySchedules`.
    ///
    /// - Parameters:
    ///   - newSchedules: Freshly fetched day schedules.
    ///   - updateRange: If true, expand `loadedStartDate` / `loadedEndDate`.
    ///   - replaceOverlap: If true, overlapping dates use the new data verbatim
    ///     (old events/reminders are discarded).  Use for sync & source filtering.
    ///     If false, old events/reminders not present in the new fetch are kept
    ///     (prevents data loss during range extension / incremental loads).
    private func mergeSchedules(_ newSchedules: [DaySchedule], updateRange: Bool, replaceOverlap: Bool = false) {
        let t0 = CFAbsoluteTimeGetCurrent()
        daySchedulesVersion &+= 1

        let newDates = Set(newSchedules.map { $0.date })

        // Existing schedules for dates that overlap with the new fetch
        let existingOverlap: [Date: DaySchedule] = Dictionary(
            uniqueKeysWithValues: daySchedules
                .filter { newDates.contains($0.date) }
                .map { ($0.date, $0) }
        )

        // Non-overlapping old entries (outside the fetched range) stay untouched
        let keptOld = daySchedules.filter { !newDates.contains($0.date) }

        // Merge each new day with existing data for the same date.
        var merged: [DaySchedule] = []
        for var newDay in newSchedules {
            guard let oldDay = existingOverlap[newDay.date] else {
                merged.append(newDay)
                continue
            }

            if replaceOverlap {
                // Use new data verbatim — old events/reminders are discarded.
                // Notes are always preserved from existing data.
                newDay.notes = oldDay.notes
            } else {
                // --- All-day events: keep old items that are not in the new fetch ---
                let newAllDayIDs = Set(newDay.allDayEvents.map(\.id))
                var didAppendAllDay = false
                var allDay = newDay.allDayEvents
                for old in oldDay.allDayEvents where !newAllDayIDs.contains(old.id) {
                    allDay.append(old)
                    didAppendAllDay = true
                }
                newDay.allDayEvents = didAppendAllDay
                    ? allDay.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                    : allDay

                // --- Timed events: same merge strategy ---
                let newTimedIDs = Set(newDay.timedEvents.map(\.id))
                var didAppendTimed = false
                var timed = newDay.timedEvents
                for old in oldDay.timedEvents where !newTimedIDs.contains(old.id) {
                    timed.append(old)
                    didAppendTimed = true
                }
                newDay.timedEvents = didAppendTimed
                    ? timed.sorted { $0.startDate < $1.startDate }
                    : timed

                // --- Reminders: same merge strategy ---
                let newReminderIDs = Set(newDay.reminders.map(\.id))
                var didAppendReminder = false
                var reminders = newDay.reminders
                for old in oldDay.reminders where !newReminderIDs.contains(old.id) {
                    reminders.append(old)
                    didAppendReminder = true
                }
                newDay.reminders = didAppendReminder
                    ? reminders.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                    : reminders

                // --- Notes: always preserve existing notes ---
                newDay.notes = oldDay.notes
            }

            merged.append(newDay)
        }

        daySchedules = (keptOld + merged).sorted { $0.date < $1.date }

        if updateRange {
            if let first = newSchedules.first?.date {
                if loadedStartDate == nil || first < loadedStartDate! {
                    loadedStartDate = first
                }
            }
            if let last = newSchedules.last?.date {
                if loadedEndDate == nil || last > loadedEndDate! {
                    loadedEndDate = last
                }
            }
        }

        // Rebuild displayDays directly instead of setting to empty first.
        // This avoids a frame where displayDays is empty during a sync.
        rebuildDisplayDays()

        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        if elapsed > 0.05 {
            log.debug("mergeSchedules took \(String(format: "%.3f", elapsed))s")
        }
    }

    /// Extend the loaded range when the user scrolls near an edge.
    /// Only fetches the NEW chunk.  Extension: 90 days (reduced from 365).
    func extendRangeIfNeeded(visibleStart: Date, visibleEnd: Date) async {
        guard !isExtending,
              let loadedStart = loadedStartDate,
              let loadedEnd = loadedEndDate else { return }

        let cal = Calendar.current
        let day = cal.startOfDay(for: visibleStart)

        let daysFromStart = cal.dateComponents([.day], from: loadedStart, to: day).day ?? 0
        if daysFromStart <= 30 {
            isExtending = true
            let newStart = cal.date(byAdding: .day, value: -90, to: loadedStart)!
            let chunkEnd = cal.date(byAdding: .day, value: -1, to: loadedStart)!
            loadedStartDate = newStart
            let schedules = await fetchSchedules(from: newStart, to: chunkEnd)
            mergeSchedules(schedules, updateRange: false)
            isExtending = false
            return
        }

        let daysFromEnd = cal.dateComponents([.day], from: day, to: loadedEnd).day ?? 0
        if daysFromEnd <= 30 {
            isExtending = true
            let newEnd = cal.date(byAdding: .day, value: 90, to: loadedEnd)!
            let chunkStart = cal.date(byAdding: .day, value: 1, to: loadedEnd)!
            loadedEndDate = newEnd
            let schedules = await fetchSchedules(from: chunkStart, to: newEnd)
            mergeSchedules(schedules, updateRange: false)
            isExtending = false
        }
    }

    /// Rebuild `displayDays` when the source data has changed.
    /// Call from `onChange(of: daySchedulesVersion)` — NOT from inside a View body.
    func updateDisplayDaysIfNeeded() {
        var h = Hasher()
        h.combine(daySchedules.count)
        if let first = daySchedules.first?.date { h.combine(first) }
        if let last = daySchedules.last?.date { h.combine(last) }
        h.combine(daySchedulesVersion)
        let currentHash = h.finalize()

        guard currentHash != displayDaysSourceHash || displayDays.isEmpty else { return }
        rebuildDisplayDays(currentHash: currentHash)
    }

    /// Directly rebuild displayDays (bypasses the hash guard).
    /// Used by `mergeSchedules` so we never leave displayDays empty mid-sync.
    private func rebuildDisplayDays(currentHash: Int? = nil) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let nonEmpty = daySchedules.filter { !$0.isEmpty }

        var result = nonEmpty
        if !result.contains(where: { cal.isDate($0.date, inSameDayAs: today) }) {
            let todaySchedule = DaySchedule(date: today)
            if let insertIndex = result.firstIndex(where: { $0.date > today }) {
                result.insert(todaySchedule, at: insertIndex)
            } else {
                result.append(todaySchedule)
            }
        }

        displayDays = result
        displayDaysSourceHash = currentHash ?? {
            var h = Hasher()
            h.combine(daySchedules.count)
            if let first = daySchedules.first?.date { h.combine(first) }
            if let last = daySchedules.last?.date { h.combine(last) }
            h.combine(daySchedulesVersion)
            return h.finalize()
        }()
    }

    func refresh() async {
        refreshTask?.cancel()

        guard let start = loadedStartDate, let end = loadedEndDate else {
            await loadInitialData()
            return
        }

        // Suppress position-driven extendRangeIfNeeded while the filtered data
        // swaps in, preventing a feedback loop of re-render → callback → extend.
        isSyncing = true
        refreshGeneration &+= 1
        let myGeneration = refreshGeneration

        let capturedStart = start
        let capturedEnd = end

        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let cal = Calendar.current
            var chunkStart = capturedStart
            var allSchedules: [DaySchedule] = []
            while chunkStart < capturedEnd, !Task.isCancelled {
                let chunkEnd = min(cal.date(byAdding: .year, value: 3, to: chunkStart)!, capturedEnd)
                let chunk = await self.fetchSchedules(from: chunkStart, to: chunkEnd)
                allSchedules.append(contentsOf: chunk)
                chunkStart = cal.date(byAdding: .day, value: 1, to: chunkEnd)!
            }
            guard !Task.isCancelled, self.refreshGeneration == myGeneration else {
                // Only clear isSyncing if this is still the latest generation.
                // A cancelled or superseded Task must not touch state owned by a
                // newer refresh.
                if self.refreshGeneration == myGeneration { self.isSyncing = false }
                return
            }
            self.mergeSchedules(allSchedules, updateRange: false, replaceOverlap: true)
            if self.refreshGeneration == myGeneration { self.isSyncing = false }
        }
    }

    // MARK: - Mutations

    func toggleReminder(_ reminderID: String) async {
        let originalSchedules = daySchedules

        for i in daySchedules.indices {
            for j in daySchedules[i].reminders.indices {
                if daySchedules[i].reminders[j].id == reminderID {
                    let old = daySchedules[i].reminders[j]
                    daySchedules[i].reminders[j] = CalendarReminder(
                        id: old.id,
                        title: old.title,
                        dueDate: old.dueDate,
                        isCompleted: !old.isCompleted,
                        completionDate: old.isCompleted ? nil : Date(),
                        calendarColor: old.calendarColor,
                        calendarTitle: old.calendarTitle,
                        accountTitle: old.accountTitle,
                        priority: old.priority
                    )
                }
            }
        }

        do {
            try await repository.toggleReminderCompletion(reminderID)
            rebuildDisplayDays()
        } catch {
            daySchedules = originalSchedules
        }
    }

    // MARK: - Open in System Apps

    func openEventInCalendar(_ eventID: String) {
        if let url = URL(string: "x-apple-calevent://\(eventID)") {
            NSWorkspace.shared.open(url)
        }
    }

    func openReminderInReminders(_ reminderID: String) {
        if let url = URL(string: "x-apple-reminder://\(reminderID)") {
            NSWorkspace.shared.open(url)
        }
    }

    func openCalendarAtDate(_ date: Date) {
        NSWorkspace.shared.open(URL(string: "x-apple-calendar://")!)
    }

    // MARK: - Formatting

    static func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }
}
