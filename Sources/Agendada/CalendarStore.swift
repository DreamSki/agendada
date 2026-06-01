import AgendadaCore
import AppKit
import Observation
import SwiftUI

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

    // MARK: - Private State

    @ObservationIgnored private var loadedStartDate: Date?
    @ObservationIgnored private var loadedEndDate: Date?
    @ObservationIgnored private var initialLoadDone = false

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
            loadSources()
            await loadInitialData()
        }
    }

    // MARK: - Sources

    func loadSources() {
        var sources: [CalendarSource] = []
        if eventPermission == .granted {
            sources.append(contentsOf: repository.fetchEventSources())
        }
        if reminderPermission == .granted {
            sources.append(contentsOf: repository.fetchReminderSources())
        }
        calendarSources = sources
    }

    func toggleSource(_ sourceID: String) {
        if showAllSources {
            // Currently showing all: clicking a source means "exclude this one"
            showAllSources = false
            enabledSourceIDs = Set(calendarSources.map { $0.id }.filter { $0 != sourceID })
        } else {
            // In filter mode: toggle this source
            if enabledSourceIDs.contains(sourceID) {
                enabledSourceIDs.remove(sourceID)
                // If all sources are now selected, switch back to show all mode
                if enabledSourceIDs.count == calendarSources.count {
                    showAllSources = true
                    enabledSourceIDs.removeAll()
                }
            } else {
                enabledSourceIDs.insert(sourceID)
                // If all sources are now selected, switch back to show all mode
                if enabledSourceIDs.count == calendarSources.count {
                    showAllSources = true
                    enabledSourceIDs.removeAll()
                }
            }
        }
        Task { await refresh() }
    }

    var isAllSourcesEnabled: Bool {
        showAllSources
    }

    func enableAllSources() {
        // Toggle: if showing all, deselect all; otherwise select all
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

    /// Merge scheduled notes from the note store into day schedules
    func mergeScheduledNotes(_ notes: [AgendadaCore.Note]) {
        let cal = Calendar.current
        // Build a map of date -> notes
        var noteMap: [Date: [ScheduledNoteInfo]] = [:]
        for note in notes {
            guard let scheduled = note.scheduledDate else { continue }
            let day = cal.startOfDay(for: scheduled)
            noteMap[day, default: []].append(
                ScheduledNoteInfo(id: note.id, title: note.title, projectID: note.projectID)
            )
        }
        // Merge into daySchedules
        for i in daySchedules.indices {
            let day = daySchedules[i].date
            if let notesForDay = noteMap[day] {
                daySchedules[i].notes = notesForDay
            } else {
                daySchedules[i].notes = []
            }
        }
    }

    func loadInitialData() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -60, to: today)!
        let end = cal.date(byAdding: .day, value: 180, to: today)!

        await loadSchedule(from: start, to: end)
        initialLoadDone = true
    }

    func loadSchedule(from startDate: Date, to endDate: Date) async {
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: startDate)
        let endDay = cal.startOfDay(for: endDate)

        // Track loaded range
        loadedStartDate = startDay
        loadedEndDate = endDay

        // Determine which calendars to fetch based on filter
        let eventCalendarIDs = showAllSources ? nil : enabledSourceIDs
        let reminderCalendarIDs = showAllSources ? nil : enabledSourceIDs

        // Fetch events
        var events: [CalendarEvent] = []
        if eventPermission == .granted {
            events = (try? repository.fetchEvents(
                from: startDay,
                to: cal.date(byAdding: .day, value: 1, to: endDay)!,
                calendarIDs: eventCalendarIDs
            )) ?? []
        }

        // Fetch reminders
        var reminders: [CalendarReminder] = []
        if reminderPermission == .granted {
            reminders = await repository.fetchReminders(from: startDay, to: endDay, calendarIDs: reminderCalendarIDs)
        }

        // Group by day
        var dayMap: [Date: DaySchedule] = [:]
        var currentDay = startDay
        while currentDay <= endDay {
            dayMap[currentDay] = DaySchedule(date: currentDay)
            currentDay = cal.date(byAdding: .day, value: 1, to: currentDay)!
        }

        // Assign events to days
        for event in events {
            let eventDay = cal.startOfDay(for: event.startDate)
            if event.isAllDay {
                dayMap[eventDay]?.allDayEvents.append(event)
            } else {
                dayMap[eventDay]?.timedEvents.append(event)
            }
        }

        // Assign reminders to days by due date
        for reminder in reminders {
            if let due = reminder.dueDate {
                let dueDay = cal.startOfDay(for: due)
                dayMap[dueDay]?.reminders.append(reminder)
            }
        }

        // Sort within each day
        for key in dayMap.keys {
            dayMap[key]?.timedEvents.sort { $0.startDate < $1.startDate }
            dayMap[key]?.reminders.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }

        // Build sorted array — merge with existing data, preserving notes
        var newSchedules = dayMap.values.sorted { $0.date < $1.date }
        let newDates = Set(newSchedules.map { $0.date })

        // Preserve notes from existing schedules for dates in the new range
        let existingNotesMap: [Date: [ScheduledNoteInfo]] = Dictionary(
            uniqueKeysWithValues: daySchedules
                .filter { newDates.contains($0.date) }
                .map { ($0.date, $0.notes) }
        )

        // Merge notes into new schedules
        for i in newSchedules.indices {
            let date = newSchedules[i].date
            if let existingNotes = existingNotesMap[date] {
                newSchedules[i].notes = existingNotes
            }
        }

        // Keep old dates outside the new range
        let keptOld = daySchedules.filter { !newDates.contains($0.date) }
        daySchedules = (keptOld + newSchedules).sorted { $0.date < $1.date }
    }

    /// Extend the loaded range when user scrolls near the edge.
    func extendRangeIfNeeded(visibleStart: Date, visibleEnd: Date) async {
        guard let loadedStart = loadedStartDate, let loadedEnd = loadedEndDate else { return }

        let cal = Calendar.current
        let day = cal.startOfDay(for: visibleStart)

        let daysFromStart = cal.dateComponents([.day], from: loadedStart, to: day).day ?? 0
        if daysFromStart <= 10 {
            let newStart = cal.date(byAdding: .day, value: -60, to: loadedStart)!
            loadedStartDate = newStart
            await loadSchedule(from: newStart, to: loadedEnd)
        }

        let daysFromEnd = cal.dateComponents([.day], from: day, to: loadedEnd).day ?? 0
        if daysFromEnd <= 10 {
            let newEnd = cal.date(byAdding: .day, value: 60, to: loadedEnd)!
            loadedEndDate = newEnd
            await loadSchedule(from: loadedStart, to: newEnd)
        }
    }

    func refresh() async {
        guard let start = loadedStartDate, let end = loadedEndDate else {
            await loadInitialData()
            return
        }
        await loadSchedule(from: start, to: end)
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
            try repository.toggleReminderCompletion(reminderID)
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
