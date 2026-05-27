import Foundation

public struct ProjectCategory: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var projectIDs: [Project.ID]

    public init(id: UUID = UUID(), name: String, projectIDs: [Project.ID] = []) {
        self.id = id
        self.name = name
        self.projectIDs = projectIDs
    }
}

public struct Project: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var categoryID: ProjectCategory.ID?
    public var color: ProjectColor
    public var isArchived: Bool
    public var isLocked: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        categoryID: ProjectCategory.ID? = nil,
        color: ProjectColor = .blue,
        isArchived: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.categoryID = categoryID
        self.color = color
        self.isArchived = isArchived
        self.isLocked = isLocked
    }
}

public enum ProjectColor: String, CaseIterable, Codable, Hashable {
    case blue
    case green
    case orange
    case pink
    case gray
}

public struct Note: Identifiable, Hashable, Codable {
    public let id: UUID
    public var projectID: Project.ID
    public var title: String
    public var body: String
    public var scheduledDate: Date?
    public var tags: [String]
    public var people: [String]
    public var status: NoteStatus
    public var isFocused: Bool
    public var isStarred: Bool
    public var isCollapsed: Bool
    public var noteColor: NoteColor?
    public var pinState: PinState
    public var createdAt: Date
    public var editedAt: Date

    public init(
        id: UUID = UUID(),
        projectID: Project.ID,
        title: String,
        body: String = "",
        scheduledDate: Date? = nil,
        tags: [String] = [],
        people: [String] = [],
        status: NoteStatus = .open,
        isFocused: Bool = false,
        isStarred: Bool = false,
        isCollapsed: Bool = false,
        noteColor: NoteColor? = nil,
        pinState: PinState = .none,
        createdAt: Date = Date(),
        editedAt: Date = Date()
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.body = body
        self.scheduledDate = scheduledDate
        self.tags = tags
        self.people = people
        self.status = status
        self.isFocused = isFocused
        self.isStarred = isStarred
        self.isCollapsed = isCollapsed
        self.noteColor = noteColor
        self.pinState = pinState
        self.createdAt = createdAt
        self.editedAt = editedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, projectID, title, body, scheduledDate, tags, people
        case status, isFocused, isStarred, isCollapsed, noteColor, pinState
        case createdAt, editedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        projectID = try c.decode(Project.ID.self, forKey: .projectID)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decode(String.self, forKey: .body)
        scheduledDate = try c.decodeIfPresent(Date.self, forKey: .scheduledDate)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        people = try c.decodeIfPresent([String].self, forKey: .people) ?? []
        status = try c.decodeIfPresent(NoteStatus.self, forKey: .status) ?? .open
        isFocused = try c.decodeIfPresent(Bool.self, forKey: .isFocused) ?? false
        isStarred = try c.decodeIfPresent(Bool.self, forKey: .isStarred) ?? false
        isCollapsed = try c.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        noteColor = try c.decodeIfPresent(NoteColor.self, forKey: .noteColor)
        pinState = try c.decodeIfPresent(PinState.self, forKey: .pinState) ?? .none
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        editedAt = try c.decodeIfPresent(Date.self, forKey: .editedAt) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(projectID, forKey: .projectID)
        try c.encode(title, forKey: .title)
        try c.encode(body, forKey: .body)
        try c.encodeIfPresent(scheduledDate, forKey: .scheduledDate)
        try c.encode(tags, forKey: .tags)
        try c.encode(people, forKey: .people)
        try c.encode(status, forKey: .status)
        try c.encode(isFocused, forKey: .isFocused)
        try c.encode(isStarred, forKey: .isStarred)
        try c.encode(isCollapsed, forKey: .isCollapsed)
        try c.encodeIfPresent(noteColor, forKey: .noteColor)
        try c.encode(pinState, forKey: .pinState)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(editedAt, forKey: .editedAt)
    }
}

public extension Note {
    var checklistSummary: ChecklistSummary {
        ChecklistSummary(body: body)
    }
}

public struct ChecklistSummary: Hashable {
    public let openCount: Int
    public let completedCount: Int

    public init(openCount: Int, completedCount: Int) {
        self.openCount = openCount
        self.completedCount = completedCount
    }

    public init(body: String) {
        var openCount = 0
        var completedCount = 0

        for line in body.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmedLine.hasPrefix("- [ ]") || trimmedLine.hasPrefix("* [ ]") {
                openCount += 1
            } else if trimmedLine.hasPrefix("- [x]") || trimmedLine.hasPrefix("* [x]") {
                completedCount += 1
            }
        }

        self.openCount = openCount
        self.completedCount = completedCount
    }

    public var totalCount: Int {
        openCount + completedCount
    }

    public var hasOpenItems: Bool {
        openCount > 0
    }

    public var title: String {
        "\(completedCount)/\(totalCount) 已完成"
    }
}

public enum NoteColor: String, CaseIterable, Codable, Hashable {
    case accent
    case red
    case green
    case blue
    case yellow
    case brown
    case pink
    case purple
    case gray

    public var title: String {
        switch self {
        case .accent: "强调色"
        case .red: "红色"
        case .green: "绿色"
        case .blue: "蓝色"
        case .yellow: "黄色"
        case .brown: "棕色"
        case .pink: "粉色"
        case .purple: "紫色"
        case .gray: "灰色"
        }
    }
}

public enum PinState: String, CaseIterable, Codable, Hashable {
    case none
    case pinnedTop
    case pinnedBottom

    public var title: String {
        switch self {
        case .none: "未置顶"
        case .pinnedTop: "置顶"
        case .pinnedBottom: "置底"
        }
    }
}

public enum NoteStatus: String, CaseIterable, Codable, Hashable {
    case open
    case completed
    case closed

    public var title: String {
        switch self {
        case .open:
            "进行中"
        case .completed:
            "已完成"
        case .closed:
            "已归档"
        }
    }
}

public enum Overview: String, CaseIterable, Codable, Identifiable {
    case today
    case tasks
    case upcoming
    case focused
    case starred
    case all

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .today:
            "今天"
        case .tasks:
            "待办事项"
        case .upcoming:
            "即将到来"
        case .focused:
            "当前关注"
        case .starred:
            "已标星"
        case .all:
            "全部笔记"
        }
    }
}

public struct SmartOverview: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var query: String

    public init(id: UUID = UUID(), name: String, query: String) {
        self.id = id
        self.name = name
        self.query = query
    }
}

public struct TimelineCounts: Hashable {
    public let today: Int
    public let tomorrow: Int
    public let yesterday: Int
    public let overdue: Int
    public let thisWeek: Int

    public init(today: Int, tomorrow: Int, yesterday: Int, overdue: Int, thisWeek: Int) {
        self.today = today
        self.tomorrow = tomorrow
        self.yesterday = yesterday
        self.overdue = overdue
        self.thisWeek = thisWeek
    }
}

public struct RelatedNote: Identifiable, Hashable {
    public let noteID: Note.ID
    public let title: String
    public let reasons: [String]

    public var id: Note.ID { noteID }

    public init(noteID: Note.ID, title: String, reasons: [String]) {
        self.noteID = noteID
        self.title = title
        self.reasons = reasons
    }
}

public enum NoteTemplate: String, CaseIterable, Codable, Identifiable {
    case blank
    case meeting
    case weeklyReview
    case projectReview
    case research

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .blank:
            "空白笔记"
        case .meeting:
            "会议纪要"
        case .weeklyReview:
            "周回顾"
        case .projectReview:
            "项目复盘"
        case .research:
            "调研记录"
        }
    }

    public var defaultNoteTitle: String {
        switch self {
        case .blank:
            "新笔记"
        case .meeting:
            "会议纪要"
        case .weeklyReview:
            "周回顾"
        case .projectReview:
            "项目复盘"
        case .research:
            "调研记录"
        }
    }

    public var defaultTags: [String] {
        switch self {
        case .blank:
            []
        case .meeting:
            ["会议"]
        case .weeklyReview:
            ["回顾"]
        case .projectReview:
            ["复盘"]
        case .research:
            ["调研"]
        }
    }

    public var body: String {
        switch self {
        case .blank:
            ""
        case .meeting:
            """
            ## 议题

            ## 结论

            ## 待办
            - [ ] 

            ## 备注
            """
        case .weeklyReview:
            """
            ## 本周完成

            ## 仍在推进

            ## 风险与阻塞

            ## 下周计划
            - [ ] 
            """
        case .projectReview:
            """
            ## 背景

            ## 发生了什么

            ## 有效做法

            ## 需要调整

            ## 后续行动
            - [ ] 
            """
        case .research:
            """
            ## 观察

            ## 证据

            ## 判断

            ## 下一步
            - [ ] 
            """
        }
    }
}
