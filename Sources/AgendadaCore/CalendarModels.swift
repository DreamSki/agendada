import Foundation

// MARK: - Permission

public enum CalendarPermissionStatus: Sendable, Equatable {
    case notDetermined
    case granted
    case denied
}

// MARK: - Calendar Color

public struct CalendarColorInfo: Hashable, Sendable {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let alpha: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

// MARK: - Calendar Event

public struct CalendarEvent: Identifiable, Hashable, Sendable {
    public let id: String           // EKEvent.eventIdentifier
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let calendarColor: CalendarColorInfo
    public let calendarTitle: String

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendarColor: CalendarColorInfo,
        calendarTitle: String
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarColor = calendarColor
        self.calendarTitle = calendarTitle
    }
}

// MARK: - Calendar Reminder

public struct CalendarReminder: Identifiable, Hashable, Sendable {
    public let id: String           // EKReminder.calendarItemIdentifier
    public let title: String
    public let dueDate: Date?
    public let isCompleted: Bool
    public let completionDate: Date?
    public let calendarColor: CalendarColorInfo
    public let calendarTitle: String
    public let priority: Int

    public init(
        id: String,
        title: String,
        dueDate: Date?,
        isCompleted: Bool,
        completionDate: Date?,
        calendarColor: CalendarColorInfo,
        calendarTitle: String,
        priority: Int
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.completionDate = completionDate
        self.calendarColor = calendarColor
        self.calendarTitle = calendarTitle
        self.priority = priority
    }
}

// MARK: - Calendar Source (for filtering)

public struct CalendarSource: Identifiable, Hashable, Sendable {
    public let id: String           // EKCalendar.calendarIdentifier
    public let title: String
    public let color: CalendarColorInfo
    public let type: SourceType

    public enum SourceType: Sendable, Hashable {
        case event      // Calendar
        case reminder   // Reminders list
    }

    public init(id: String, title: String, color: CalendarColorInfo, type: SourceType) {
        self.id = id
        self.title = title
        self.color = color
        self.type = type
    }
}

// MARK: - Scheduled Note Info (lightweight reference)

public struct ScheduledNoteInfo: Identifiable, Hashable, Sendable {
    public let id: UUID             // Note.ID
    public let title: String
    public let projectID: UUID

    public init(id: UUID, title: String, projectID: UUID) {
        self.id = id
        self.title = title
        self.projectID = projectID
    }
}

// MARK: - Day Schedule

public struct DaySchedule: Identifiable, Hashable, Sendable {
    public let date: Date   // start of day
    public var id: Date { date }

    public var allDayEvents: [CalendarEvent]
    public var timedEvents: [CalendarEvent]    // sorted by startDate
    public var reminders: [CalendarReminder]   // due on this date
    public var notes: [ScheduledNoteInfo]      // notes scheduled on this date

    public init(
        date: Date,
        allDayEvents: [CalendarEvent] = [],
        timedEvents: [CalendarEvent] = [],
        reminders: [CalendarReminder] = [],
        notes: [ScheduledNoteInfo] = []
    ) {
        self.date = date
        self.allDayEvents = allDayEvents
        self.timedEvents = timedEvents
        self.reminders = reminders
        self.notes = notes
    }

    public var isEmpty: Bool {
        allDayEvents.isEmpty && timedEvents.isEmpty && reminders.isEmpty && notes.isEmpty
    }
}
