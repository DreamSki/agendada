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
    public var blockJSON: Data
    public var plainTextPreview: String
    public var previewHTML: String?
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
        blockJSON: Data? = nil,
        plainTextPreview: String? = nil,
        previewHTML: String? = nil,
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
        self.blockJSON = blockJSON ?? Note.blockJSONData(fromLegacyHTML: body)
        self.plainTextPreview = plainTextPreview ?? htmlToPlainText(body)
        self.previewHTML = previewHTML
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

    /// Plain text extracted from HTML body (for search & preview).
    public var bodyPlainText: String {
        let preview = plainTextPreview.trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? htmlToPlainText(body) : preview
    }

    public var blockJSONString: String {
        String(data: blockJSON, encoding: .utf8) ?? Note.emptyBlockJSONString
    }

    public static let emptyBlockJSONString = #"[{"type":"paragraph","content":""}]"#

    public static var emptyBlockJSONData: Data {
        Data(emptyBlockJSONString.utf8)
    }

    public static func blockJSONData(fromLegacyHTML html: String) -> Data {
        let blocks = legacyBlocks(fromHTML: html)
        guard let data = try? JSONEncoder().encode(blocks), !blocks.isEmpty else {
            return emptyBlockJSONData
        }
        return data
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case projectID
        case title
        case body
        case blockJSON
        case plainTextPreview
        case previewHTML
        case scheduledDate
        case tags
        case people
        case status
        case isFocused
        case isStarred
        case isCollapsed
        case noteColor
        case pinState
        case createdAt
        case editedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectID = try container.decode(Project.ID.self, forKey: .projectID)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        blockJSON = try container.decodeIfPresent(Data.self, forKey: .blockJSON)
            ?? Note.blockJSONData(fromLegacyHTML: body)
        plainTextPreview = try container.decodeIfPresent(String.self, forKey: .plainTextPreview)
            ?? htmlToPlainText(body)
        previewHTML = try container.decodeIfPresent(String.self, forKey: .previewHTML)
        scheduledDate = try container.decodeIfPresent(Date.self, forKey: .scheduledDate)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        people = try container.decodeIfPresent([String].self, forKey: .people) ?? []
        status = try container.decodeIfPresent(NoteStatus.self, forKey: .status) ?? .open
        isFocused = try container.decodeIfPresent(Bool.self, forKey: .isFocused) ?? false
        isStarred = try container.decodeIfPresent(Bool.self, forKey: .isStarred) ?? false
        isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        noteColor = try container.decodeIfPresent(NoteColor.self, forKey: .noteColor)
        pinState = try container.decodeIfPresent(PinState.self, forKey: .pinState) ?? .none
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        editedAt = try container.decodeIfPresent(Date.self, forKey: .editedAt) ?? createdAt
    }
}

public extension Note {
    var checklistSummary: ChecklistSummary {
        ChecklistSummary(html: body)
    }
}

public struct ChecklistSummary: Hashable {
    public let openCount: Int
    public let completedCount: Int

    public init(openCount: Int, completedCount: Int) {
        self.openCount = openCount
        self.completedCount = completedCount
    }

    public init(html: String) {
        var openCount = 0
        var completedCount = 0

        // Count task items by finding all data-checked occurrences
        let checkedRegex = try! NSRegularExpression(pattern: #"data-checked="true""#)
        let taskItemRegex = try! NSRegularExpression(pattern: #"data-type="taskItem""#)
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        completedCount = checkedRegex.numberOfMatches(in: html, range: range)
        let totalTaskItems = taskItemRegex.numberOfMatches(in: html, range: range)
        openCount = totalTaskItems - completedCount

        // Also handle legacy markdown in plain text
        for line in html.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("* [ ]") {
                openCount += 1
            } else if trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("* [x]") {
                completedCount += 1
            }
        }
        self.openCount = openCount
        self.completedCount = completedCount
    }

    public var totalCount: Int { openCount + completedCount }
    public var hasOpenItems: Bool { openCount > 0 }
    public var title: String { "\(completedCount)/\(totalCount) 已完成" }
}

// MARK: - Enums

public enum NoteColor: String, CaseIterable, Codable, Hashable {
    case accent, red, green, blue, yellow, brown, pink, purple, gray
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
    case none, pinnedTop, pinnedBottom
    public var title: String {
        switch self {
        case .none: "未置顶"
        case .pinnedTop: "置顶"
        case .pinnedBottom: "置底"
        }
    }
}

public enum NoteStatus: String, CaseIterable, Codable, Hashable {
    case open, completed, closed, trashed
    public var title: String {
        switch self {
        case .open: "进行中"
        case .completed: "已完成"
        case .closed: "已归档"
        case .trashed: "废纸篓"
        }
    }
}

public enum Overview: String, CaseIterable, Codable, Identifiable {
    case today, tasks, upcoming, focused, starred, all, trash
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .today: "今天"
        case .tasks: "待办事项"
        case .upcoming: "即将到来"
        case .focused: "当前关注"
        case .starred: "已标星"
        case .all: "全部笔记"
        case .trash: "废纸篓"
        }
    }
}

public struct SmartOverview: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var query: String
    public init(id: UUID = UUID(), name: String, query: String) {
        self.id = id; self.name = name; self.query = query
    }
}

public struct TimelineCounts: Hashable {
    public let today, tomorrow, yesterday, overdue, thisWeek: Int
    public init(today: Int, tomorrow: Int, yesterday: Int, overdue: Int, thisWeek: Int) {
        self.today = today; self.tomorrow = tomorrow; self.yesterday = yesterday
        self.overdue = overdue; self.thisWeek = thisWeek
    }
}

public struct RelatedNote: Identifiable, Hashable {
    public let noteID: Note.ID
    public let title: String
    public let reasons: [String]
    public var id: Note.ID { noteID }
    public init(noteID: Note.ID, title: String, reasons: [String]) {
        self.noteID = noteID; self.title = title; self.reasons = reasons
    }
}

// MARK: - NoteTemplate

public enum NoteTemplate: String, CaseIterable, Codable, Identifiable {
    case blank, meeting, weeklyReview, projectReview, research
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .blank: "空白笔记"
        case .meeting: "会议纪要"
        case .weeklyReview: "周回顾"
        case .projectReview: "项目复盘"
        case .research: "调研记录"
        }
    }
    public var defaultNoteTitle: String {
        switch self {
        case .blank: "新笔记"
        case .meeting: "会议纪要"
        case .weeklyReview: "周回顾"
        case .projectReview: "项目复盘"
        case .research: "调研记录"
        }
    }
    public var defaultTags: [String] {
        switch self {
        case .blank: []
        case .meeting: ["会议"]
        case .weeklyReview: ["回顾"]
        case .projectReview: ["复盘"]
        case .research: ["调研"]
        }
    }
    public var body: String {
        switch self {
        case .blank: ""
        case .meeting: "<h2>议题</h2><p></p><h2>结论</h2><p></p><h2>待办</h2><ul data-type=\"taskList\"><li data-type=\"taskItem\" data-checked=\"false\"><label><input type=\"checkbox\"></label><div><p></p></div></li></ul><h2>备注</h2><p></p>"
        case .weeklyReview: "<h2>本周完成</h2><p></p><h2>仍在推进</h2><p></p><h2>风险与阻塞</h2><p></p><h2>下周计划</h2><ul data-type=\"taskList\"><li data-type=\"taskItem\" data-checked=\"false\"><label><input type=\"checkbox\"></label><div><p></p></div></li></ul>"
        case .projectReview: "<h2>背景</h2><p></p><h2>发生了什么</h2><p></p><h2>有效做法</h2><p></p><h2>需要调整</h2><p></p><h2>后续行动</h2><ul data-type=\"taskList\"><li data-type=\"taskItem\" data-checked=\"false\"><label><input type=\"checkbox\"></label><div><p></p></div></li></ul>"
        case .research: "<h2>观察</h2><p></p><h2>证据</h2><p></p><h2>判断</h2><p></p><h2>下一步</h2><ul data-type=\"taskList\"><li data-type=\"taskItem\" data-checked=\"false\"><label><input type=\"checkbox\"></label><div><p></p></div></li></ul>"
        }
    }
}

// MARK: - HTML to plain text helper (used by Core, defined here to avoid AppKit dependency)

private struct LegacyBlockNoteBlock: Codable, Hashable {
    var type: String
    var content: String
    var children: [LegacyBlockNoteBlock]

    init(type: String = "paragraph", content: String = "", children: [LegacyBlockNoteBlock] = []) {
        self.type = type
        self.content = content
        self.children = children
    }
}

private func legacyBlocks(fromHTML html: String) -> [LegacyBlockNoteBlock] {
    let plainText = htmlToPlainText(html)
    guard !plainText.isEmpty else {
        return [LegacyBlockNoteBlock()]
    }

    let tokenPattern = #"<(h[1-3]|p)[^>]*>(.*?)</\1>|<li[^>]*data-type="taskItem"[^>]*data-checked="(true|false)"[^>]*>.*?<p>(.*?)</p>.*?</li>"#
    guard let regex = try? NSRegularExpression(pattern: tokenPattern, options: [.dotMatchesLineSeparators]) else {
        return plainTextBlocks(plainText)
    }

    let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
    let matches = regex.matches(in: html, range: nsRange)
    var blocks: [LegacyBlockNoteBlock] = []

    for match in matches {
        if let tagRange = Range(match.range(at: 1), in: html),
           let contentRange = Range(match.range(at: 2), in: html) {
            let tag = String(html[tagRange])
            let content = htmlToPlainText(String(html[contentRange]))
            guard !content.isEmpty else { continue }
            blocks.append(LegacyBlockNoteBlock(type: tag == "p" ? "paragraph" : "heading", content: content))
        } else if let checkedRange = Range(match.range(at: 3), in: html),
                  let taskRange = Range(match.range(at: 4), in: html) {
            let checkedPrefix = String(html[checkedRange]) == "true" ? "[x] " : "[ ] "
            let content = htmlToPlainText(String(html[taskRange]))
            blocks.append(LegacyBlockNoteBlock(type: "checkListItem", content: checkedPrefix + content))
        }
    }

    return blocks.isEmpty ? plainTextBlocks(plainText) : blocks
}

private func plainTextBlocks(_ text: String) -> [LegacyBlockNoteBlock] {
    let lines = text
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    if lines.isEmpty {
        return [LegacyBlockNoteBlock()]
    }

    return lines.map { line in
        if line.hasPrefix("- [ ]") || line.hasPrefix("* [ ]") || line.hasPrefix("- [x]") || line.hasPrefix("* [x]") {
            return LegacyBlockNoteBlock(type: "checkListItem", content: line)
        }
        return LegacyBlockNoteBlock(content: line)
    }
}

private func htmlToPlainText(_ html: String) -> String {
    guard !html.isEmpty else { return "" }
    // Strip HTML tags
    var text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    // Decode common entities
    text = text.replacingOccurrences(of: "&amp;", with: "&")
    text = text.replacingOccurrences(of: "&lt;", with: "<")
    text = text.replacingOccurrences(of: "&gt;", with: ">")
    text = text.replacingOccurrences(of: "&quot;", with: "\"")
    text = text.replacingOccurrences(of: "&#39;", with: "'")
    text = text.replacingOccurrences(of: "&nbsp;", with: " ")
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}
