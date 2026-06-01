import CoreImage
import EventKit
import Foundation

public final class CalendarRepository: @unchecked Sendable {
    private let eventStore = EKEventStore()

    // MARK: - Permission Queries

    public var eventPermissionStatus: CalendarPermissionStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess: return .granted
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }

    public var reminderPermissionStatus: CalendarPermissionStatus {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .authorized, .fullAccess: return .granted
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }

    public init() {}

    // MARK: - Permission Requests

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

    public func fetchEvents(from startDate: Date, to endDate: Date, calendarIDs: Set<String>? = nil) throws -> [CalendarEvent] {
        let calendars = calendarIDs.map { ids -> [EKCalendar]? in
            let all = eventStore.calendars(for: .event)
            let filtered = all.filter { ids.contains($0.calendarIdentifier) }
            return filtered.isEmpty ? nil : filtered
        } ?? nil
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
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

    public func fetchReminders(from startDate: Date, to endDate: Date, calendarIDs: Set<String>? = nil) async -> [CalendarReminder] {
        // Convert calendar IDs to EKCalendar objects for filtering
        let calendars = calendarIDs.map { ids -> [EKCalendar]? in
            let all = eventStore.calendars(for: .reminder)
            let filtered = all.filter { ids.contains($0.calendarIdentifier) }
            return filtered.isEmpty ? nil : filtered
        } ?? nil
        let predicate = eventStore.predicateForReminders(in: calendars)

        // EKReminder fetch is callback-based — map to our Sendable type immediately
        let reminderData: [CalendarReminder] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let mapped = (reminders ?? []).map { ek in
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
                continuation.resume(returning: mapped)
            }
        }

        let cal = Calendar.current
        let startDay = cal.startOfDay(for: startDate)
        let endDay = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: endDate) ?? endDate)

        return reminderData.filter { reminder in
            guard let due = reminder.dueDate else { return false }
            let dueDay = cal.startOfDay(for: due)
            return dueDay >= startDay && dueDay < endDay
        }
    }

    // MARK: - Toggle Reminder

    @MainActor
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

    public func eventCalendars(for sourceIDs: Set<String>) -> [EKCalendar]? {
        guard !sourceIDs.isEmpty else { return nil }
        let all = eventStore.calendars(for: .event)
        let filtered = all.filter { sourceIDs.contains($0.calendarIdentifier) }
        return filtered.isEmpty ? nil : filtered
    }

    public func reminderCalendars(for sourceIDs: Set<String>) -> [EKCalendar]? {
        guard !sourceIDs.isEmpty else { return nil }
        let all = eventStore.calendars(for: .reminder)
        let filtered = all.filter { sourceIDs.contains($0.calendarIdentifier) }
        return filtered.isEmpty ? nil : filtered
    }

    // MARK: - Helpers

    private static func colorInfo(from calendar: EKCalendar?) -> CalendarColorInfo {
        guard let cgColor = calendar?.cgColor else {
            return CalendarColorInfo(red: 0.557, green: 0.557, blue: 0.576) // muted gray default
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
