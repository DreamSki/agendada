import CoreImage
@preconcurrency import EventKit
import Foundation

/// Actor-isolated repository for all EventKit access.
///
/// All `EKEventStore` operations are serialized on the actor's executor,
/// keeping synchronous EventKit calls (`events(matching:)`, calendar enumeration,
/// etc.) off the main thread.  Only permission-request methods are `@MainActor`
/// because the system authorization dialog must present from the main thread.
public actor CalendarRepository {
    private let eventStore = EKEventStore()

    // MARK: - Permission Queries (nonisolated — uses static API)

    public nonisolated var eventPermissionStatus: CalendarPermissionStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess: return .granted
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }

    public nonisolated var reminderPermissionStatus: CalendarPermissionStatus {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .authorized, .fullAccess: return .granted
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }

    public init() {}

    // MARK: - Permission Requests (must be @MainActor for system dialog)

    @MainActor
    public func requestEventAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    @MainActor
    public func requestReminderAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToReminders()
        } catch {
            return false
        }
    }

    // MARK: - Fetch Events

    /// Fetch calendar events in the given date range, optionally filtered by calendar IDs.
    /// - Parameter calendarIDs: The set of calendar identifiers to include.
    ///   An **empty** set means "no calendars selected" → returns an empty array.
    ///   `nil` means "no filter" → returns events from all calendars.
    ///   A non-empty set that matches zero actual calendars (e.g. a deleted source)
    ///   falls back to all calendars so the timeline doesn't silently go blank.
    public func fetchEvents(
        from startDate: Date,
        to endDate: Date,
        calendarIDs: Set<String>? = nil
    ) throws -> [CalendarEvent] {
        // Explicitly empty set → user chose no sources → return nothing.
        if let ids = calendarIDs, ids.isEmpty {
            return []
        }

        let calendars: [EKCalendar]? = calendarIDs.flatMap { ids in
            let filtered = eventStore.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
            // If no calendars match the requested IDs (e.g. source deleted from
            // System Settings), fall back to all calendars instead of returning
            // zero events with no explanation.
            return filtered.isEmpty ? nil : filtered
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate, end: endDate, calendars: calendars
        )
        let ekEvents = eventStore.events(matching: predicate)

        return ekEvents.map { ek in
            CalendarEvent(
                id: ek.eventIdentifier,
                title: ek.title ?? "",
                startDate: ek.startDate,
                endDate: ek.endDate,
                isAllDay: ek.isAllDay,
                calendarColor: Self.colorInfo(from: ek.calendar),
                calendarTitle: ek.calendar?.title ?? "",
                accountTitle: ek.calendar?.source?.title ?? "未知账户"
            )
        }
    }

    // MARK: - Fetch Reminders

    /// Fetch reminders in the given date range, optionally filtered by calendar IDs.
    /// - Parameter calendarIDs: The set of calendar identifiers to include.
    ///   An **empty** set means "no calendars selected" → returns an empty array.
    ///   `nil` means "no filter" → returns reminders from all calendars.
    public func fetchReminders(
        from startDate: Date,
        to endDate: Date,
        calendarIDs: Set<String>? = nil
    ) async -> [CalendarReminder] {
        // Fix: empty set → return empty (previously returned nil → EventKit showed ALL)
        if let ids = calendarIDs, ids.isEmpty {
            return []
        }

        let cal = Calendar.current
        let startDay = cal.startOfDay(for: startDate)
        let endDay = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: endDate) ?? endDate)

        // Two-phase fetch to avoid pulling every reminder in existence:
        // 1. Incomplete reminders with due dates in range (date-bounded predicate)
        // 2. Recently completed reminders (limited window to bound cost)
        //
        // Each method resolves calendars from IDs internally so we don't send
        // non-Sendable EKCalendar arrays across async boundaries.
        let incomplete = await fetchIncompleteReminders(
            from: startDay, to: endDay, calendarIDs: calendarIDs
        )
        let completed = await fetchRecentlyCompletedReminders(
            calendarIDs: calendarIDs, startDay: startDay, endDay: endDay, cal: cal
        )

        // Deduplicate by ID (a reminder can't be both, but guard anyway)
        var seen = Set<String>()
        var all: [CalendarReminder] = []
        for r in incomplete where seen.insert(r.id).inserted { all.append(r) }
        for r in completed where seen.insert(r.id).inserted { all.append(r) }
        return all
    }

    /// Fetch incomplete reminders whose due date falls within `startDay..<endDay`.
    private func fetchIncompleteReminders(
        from startDay: Date,
        to endDay: Date,
        calendarIDs: Set<String>?
    ) async -> [CalendarReminder] {
        let calendars: [EKCalendar]? = calendarIDs.flatMap { ids in
            let filtered = eventStore.calendars(for: .reminder).filter { ids.contains($0.calendarIdentifier) }
            // Fall back to all calendars when no actual calendars match the
            // requested IDs (e.g. source was deleted from System Settings).
            return filtered.isEmpty ? nil : filtered
        }
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: startDay,
            ending: endDay,
            calendars: calendars
        )
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let mapped = (reminders ?? []).map { ek in Self.mapReminder(ek) }
                continuation.resume(returning: mapped)
            }
        }
    }

    /// Fetch recently completed reminders and filter to those whose *due date*
    /// falls within the visible range.  We look back 30 days for completions
    /// because EventKitʼs completed-reminder predicate filters by completion
    /// date, not due date — a reminder due 6 months ago but ticked off today
    /// should still appear on todayʼs timeline row.
    private func fetchRecentlyCompletedReminders(
        calendarIDs: Set<String>?,
        startDay: Date,
        endDay: Date,
        cal: Calendar
    ) async -> [CalendarReminder] {
        let calendars: [EKCalendar]? = calendarIDs.flatMap { ids in
            let filtered = eventStore.calendars(for: .reminder).filter { ids.contains($0.calendarIdentifier) }
            // Fall back to all calendars when no actual calendars match.
            return filtered.isEmpty ? nil : filtered
        }
        let lookback = cal.date(byAdding: .day, value: -30, to: startDay) ?? startDay
        let predicate = eventStore.predicateForCompletedReminders(
            withCompletionDateStarting: lookback,
            ending: endDay,
            calendars: calendars
        )
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let mapped = (reminders ?? []).compactMap { ek -> CalendarReminder? in
                    guard let dueDate = ek.dueDateComponents.flatMap({ cal.date(from: $0) }) else {
                        return nil
                    }
                    let dueDay = cal.startOfDay(for: dueDate)
                    guard dueDay >= startDay, dueDay < endDay else { return nil }
                    return Self.mapReminder(ek)
                }
                continuation.resume(returning: mapped)
            }
        }
    }

    // MARK: - Toggle Reminder

    public func toggleReminderCompletion(_ reminderID: String) throws {
        guard let ekReminder = eventStore.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            return
        }
        ekReminder.isCompleted.toggle()
        if ekReminder.isCompleted {
            ekReminder.completionDate = Date()
        } else {
            ekReminder.completionDate = nil
        }
        try eventStore.save(ekReminder, commit: true)
    }

    // MARK: - Calendar Sources (for filtering)

    public func fetchEventSources() -> [CalendarSource] {
        eventStore.calendars(for: .event).map { cal in
            CalendarSource(
                id: cal.calendarIdentifier,
                title: cal.title,
                accountTitle: cal.source?.title ?? "未知账户",
                color: Self.colorInfo(from: cal),
                type: .event
            )
        }
    }

    public func fetchReminderSources() -> [CalendarSource] {
        eventStore.calendars(for: .reminder).map { cal in
            CalendarSource(
                id: cal.calendarIdentifier,
                title: cal.title,
                accountTitle: cal.source?.title ?? "未知账户",
                color: Self.colorInfo(from: cal),
                type: .reminder
            )
        }
    }

    // MARK: - Helpers

    private static func mapReminder(_ ek: EKReminder) -> CalendarReminder {
        CalendarReminder(
            id: ek.calendarItemIdentifier,
            title: ek.title ?? "",
            dueDate: {
                guard let comps = ek.dueDateComponents else { return nil }
                return Calendar.current.date(from: comps)
            }(),
            isCompleted: ek.isCompleted,
            completionDate: ek.completionDate,
            calendarColor: Self.colorInfo(from: ek.calendar),
            calendarTitle: ek.calendar?.title ?? "",
            accountTitle: ek.calendar?.source?.title ?? "未知账户",
            priority: ek.priority
        )
    }

    private static func colorInfo(from calendar: EKCalendar?) -> CalendarColorInfo {
        guard let cgColor = calendar?.cgColor else {
            return CalendarColorInfo(red: 0.557, green: 0.557, blue: 0.576)
        }
        let ciColor = CIColor(cgColor: cgColor)
        return CalendarColorInfo(
            red: ciColor.red,
            green: ciColor.green,
            blue: ciColor.blue,
            alpha: ciColor.alpha
        )
    }
}
