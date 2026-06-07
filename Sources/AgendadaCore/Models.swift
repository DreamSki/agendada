import Foundation

public struct ProjectCategory: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var color: CategoryColor
    public var parentID: ProjectCategory.ID?
    public var projectIDs: [Project.ID]

    public init(
        id: UUID = UUID(),
        name: String,
        color: CategoryColor = .orange,
        parentID: ProjectCategory.ID? = nil,
        projectIDs: [Project.ID] = []
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.parentID = parentID
        self.projectIDs = projectIDs
    }

    // MARK: - Codable backward compatibility

    private enum CodingKeys: String, CodingKey {
        case id, name, color, parentID, projectIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decodeIfPresent(CategoryColor.self, forKey: .color) ?? .orange
        parentID = try container.decodeIfPresent(ProjectCategory.ID.self, forKey: .parentID)
        projectIDs = try container.decodeIfPresent([Project.ID].self, forKey: .projectIDs) ?? []
    }
}

public enum CategoryColor: String, CaseIterable, Codable, Hashable, Sendable {
    case orange, tan, purple, green, pink, gray, red, blue, olive, gold, teal, indigo, burgundy

    public var title: String {
        switch self {
        case .orange: "橙色"; case .tan: "浅棕"; case .purple: "紫色"
        case .green: "绿色"; case .pink: "粉色"; case .gray: "灰色"
        case .red: "红色"; case .blue: "蓝色"; case .olive: "橄榄绿"
        case .gold: "金色"; case .teal: "青色"; case .indigo: "靛灰"
        case .burgundy: "深红"
        }
    }
}

public struct Project: Identifiable, Hashable, Codable, Sendable {
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

public enum ProjectColor: String, CaseIterable, Codable, Hashable, Sendable {
    case blue
    case green
    case orange
    case pink
    case gray
}

public struct Note: Identifiable, Hashable, Codable, Sendable {
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
    public var isBrief: Bool
    public var position: Int64?
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
        isBrief: Bool = false,
        position: Int64? = nil,
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
        self.isBrief = isBrief
        self.position = position
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
        case isBrief
        case position
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
        isBrief = try container.decodeIfPresent(Bool.self, forKey: .isBrief) ?? false
        // Decode from either Int64 (current), Double (legacy), or Int (legacy)
        if let i64 = try? container.decodeIfPresent(Int64.self, forKey: .position) {
            position = i64
        } else if let d = try? container.decodeIfPresent(Double.self, forKey: .position) {
            position = Int64((d * 1024).rounded())
        } else if let i = try? container.decodeIfPresent(Int.self, forKey: .position) {
            position = Int64(i) * 1024
        } else {
            position = nil
        }
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        editedAt = try container.decodeIfPresent(Date.self, forKey: .editedAt) ?? createdAt
    }
}

public extension Note {
    var checklistSummary: ChecklistSummary {
        ChecklistSummary(html: body)
    }
}

public struct ChecklistSummary: Hashable, Sendable {
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
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        completedCount = Self.checkedRegex.numberOfMatches(in: html, range: range)
        let totalTaskItems = Self.taskItemRegex.numberOfMatches(in: html, range: range)
        openCount = totalTaskItems - completedCount

        // Handle legacy markdown only when no HTML task items were found
        // to avoid double-counting items that appear in both forms.
        if completedCount == 0, openCount == 0 {
            for line in html.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("* [ ]") {
                    openCount += 1
                } else if trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("* [x]") {
                    completedCount += 1
                }
            }
        }
        self.openCount = openCount
        self.completedCount = completedCount
    }

    private static let checkedRegex = try! NSRegularExpression(pattern: #"data-checked="true""#)
    private static let taskItemRegex = try! NSRegularExpression(pattern: #"data-type="taskItem""#)

    public var totalCount: Int { openCount + completedCount }
    public var hasOpenItems: Bool { openCount > 0 }
    public var title: String { "\(completedCount)/\(totalCount) 已完成" }
}

// MARK: - Enums

public enum NoteColor: String, CaseIterable, Codable, Hashable, Sendable {
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

public enum PinState: String, CaseIterable, Codable, Hashable, Sendable {
    case none, pinnedTop, pinnedBottom
    public var title: String {
        switch self {
        case .none: "未置顶"
        case .pinnedTop: "置顶"
        case .pinnedBottom: "置底"
        }
    }
}

public enum NoteStatus: String, CaseIterable, Codable, Hashable, Sendable {
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

public enum Overview: String, CaseIterable, Codable, Identifiable, Sendable {
    case today, tasks, upcoming, focused, starred, brief, all, trash
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .today: "今天"
        case .tasks: "待办事项"
        case .upcoming: "即将到来"
        case .focused: "当前关注"
        case .starred: "已标星"
        case .brief: "简达"
        case .all: "全部笔记"
        case .trash: "废纸篓"
        }
    }
}

public struct SmartOverview: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var query: String
    public init(id: UUID = UUID(), name: String, query: String) {
        self.id = id; self.name = name; self.query = query
    }
}

public struct TimelineCounts: Hashable, Sendable {
    public let today, tomorrow, yesterday, overdue, thisWeek: Int
    public init(today: Int, tomorrow: Int, yesterday: Int, overdue: Int, thisWeek: Int) {
        self.today = today; self.tomorrow = tomorrow; self.yesterday = yesterday
        self.overdue = overdue; self.thisWeek = thisWeek
    }
}

public struct RelatedNote: Identifiable, Hashable, Sendable {
    public let noteID: Note.ID
    public let title: String
    public let reasons: [String]
    public var id: Note.ID { noteID }
    public init(noteID: Note.ID, title: String, reasons: [String]) {
        self.noteID = noteID; self.title = title; self.reasons = reasons
    }
}

// MARK: - Search Occurrence

/// 搜索范围：在当前视图范围内过滤，或搜索全部笔记
public enum SearchScope: String, Codable, Sendable, CaseIterable {
    case currentScope = "current"
    case all = "all"
}

/// 匹配字段类型
public enum SearchField: String, Sendable, Codable {
    case title
    case body
}

/// 表示搜索结果中的一个具体文本命中位置
public struct SearchOccurrence: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let noteID: Note.ID
    public let noteTitle: String
    public let globalIndex: Int           // 在所有命中位置中的全局索引（0-based）
    public let occurrenceIndexInNote: Int // 在当前笔记中的索引（0-based）
    public let bodyIndexInNote: Int       // 当前笔记中 body 的序号（0-based），title 固定为 -1
    public let field: SearchField         // 匹配发生在 title 还是 body
    public let matchPosition: Int         // 匹配在 field 文本中的 UTF-16 偏移
    public let matchLength: Int           // 匹配文本的长度
    public let excerpt: String            // 匹配上下文片段

    public init(
        noteID: Note.ID,
        noteTitle: String,
        globalIndex: Int,
        occurrenceIndexInNote: Int,
        bodyIndexInNote: Int,
        field: SearchField,
        matchPosition: Int,
        matchLength: Int,
        excerpt: String
    ) {
        self.noteID = noteID
        self.noteTitle = noteTitle
        self.globalIndex = globalIndex
        self.occurrenceIndexInNote = occurrenceIndexInNote
        self.bodyIndexInNote = bodyIndexInNote
        self.field = field
        self.matchPosition = matchPosition
        self.matchLength = matchLength
        self.excerpt = excerpt
    }
}

/// Find in Note 匹配摘要
public struct FindInNoteSummary: Sendable, Equatable {
    public let totalOccurrences: Int
    public let currentIndex: Int

    public init(totalOccurrences: Int, currentIndex: Int) {
        self.totalOccurrences = totalOccurrences
        self.currentIndex = currentIndex
    }

    public static let empty = FindInNoteSummary(totalOccurrences: 0, currentIndex: 0)
}

/// 搜索匹配摘要信息
public struct SearchSummary: Sendable, Equatable {
    public let totalOccurrences: Int      // 总命中位置数
    public let totalMatchedNotes: Int     // 匹配到的笔记数
    public let currentOccurrenceIndex: Int // 当前命中位置的全局索引（0-based）
    public let currentNoteIndex: Int       // 当前所在的笔记索引（1-based）

    public init(totalOccurrences: Int, totalMatchedNotes: Int, currentOccurrenceIndex: Int, currentNoteIndex: Int) {
        self.totalOccurrences = totalOccurrences
        self.totalMatchedNotes = totalMatchedNotes
        self.currentOccurrenceIndex = currentOccurrenceIndex
        self.currentNoteIndex = currentNoteIndex
    }

    public static let empty = SearchSummary(totalOccurrences: 0, totalMatchedNotes: 0, currentOccurrenceIndex: 0, currentNoteIndex: 0)
}

/// Represents how the middle content area should present search state.
public enum SearchPresentationMode: Equatable, Sendable {
    /// No search active — normal note stream.
    case normal
    /// User is typing in popover but hasn't committed yet — note stream unchanged.
    case preview
    /// Committed search with matching results — show grouped snippets.
    case results
    /// Committed search with no results — show empty state.
    case noResults
}

/// A single search-match snippet within a grouped result.
public struct SearchResultSnippet: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let occurrence: SearchOccurrence

    public init(occurrence: SearchOccurrence) {
        self.id = occurrence.id
        self.occurrence = occurrence
    }
}

/// Groups search occurrences by note for compact search-result display.
public struct SearchResultGroup: Identifiable, Hashable, Sendable {
    public let note: Note
    public let occurrences: [SearchOccurrence]
    public let snippets: [SearchResultSnippet]

    public var id: Note.ID { note.id }

    public init(note: Note, occurrences: [SearchOccurrence]) {
        self.note = note
        self.occurrences = occurrences
        self.snippets = occurrences.map { SearchResultSnippet(occurrence: $0) }
    }
}

// MARK: - Sort Mode

public enum SortMode: String, CaseIterable, Codable, Sendable {
    case manual
    case scheduledDate
    case editedAt
    case createdAt

    public var title: String {
        switch self {
        case .manual: "手动排序"
        case .scheduledDate: "按日期"
        case .editedAt: "按编辑时间"
        case .createdAt: "按创建时间"
        }
    }
}

public enum PositionMove: Sendable {
    case beforePrevious
    case afterNext
    case toFirst
    case toLast
}

/// Detected boundary crossing during drag-and-drop reordering.
public enum PinBoundaryCrossing: Sendable {
    case none
    /// A non-pinned note is being dropped onto a pinned-top note.
    case intoPinnedTop
    /// A pinned-top note is being dropped onto a non-pinned note.
    case outOfPinnedTop
}

// MARK: - NoteTemplate

public enum NoteSortOrder: String, CaseIterable, Codable, Sendable {
    case scheduledDateDesc
    case scheduledDateAsc
    case editedAtDesc
    case createdAtDesc

    public var title: String {
        switch self {
        case .scheduledDateDesc: "日期（新→旧）"
        case .scheduledDateAsc: "日期（旧→新）"
        case .editedAtDesc: "最近编辑"
        case .createdAtDesc: "最近创建"
        }
    }
}

public enum NoteTemplate: String, CaseIterable, Codable, Identifiable, Sendable {
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

// MARK: - Custom Note Template

public struct CustomNoteTemplate: Identifiable, Hashable, Codable, Sendable {
	public let id: UUID
	public var name: String
	public var title: String
	public var body: String
	public var tags: [String]

	public init(id: UUID = UUID(), name: String, title: String, body: String, tags: [String] = []) {
		self.id = id
		self.name = name
		self.title = title
		self.body = body
		self.tags = tags
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

// MARK: - Find in Note Notification

public extension Notification.Name {
    /// Posted when Cmd+F is pressed while the editor WebView has focus.
    /// The UI layer observes this to show the Find in Note bar.
    static let findInNoteRequested = Notification.Name("com.agendada.findInNote")
}

// MARK: - Calendar Safe Arithmetic

public extension Calendar {
    /// Safe wrapper around `date(byAdding:to:)` that never returns nil.
    /// Falls back to a TimeInterval-based estimate on exotic calendars where
    /// date arithmetic could theoretically fail.
    func safeDate(byAdding component: Calendar.Component, value: Int, to date: Date) -> Date {
        guard let result = self.date(byAdding: component, value: value, to: date) else {
            print("⚠️ [Agendada] Calendar.date(byAdding: \(component), value: \(value)) returned nil — falling back")
            if component == .day { return date.addingTimeInterval(TimeInterval(value) * 86400) }
            return date
        }
        return result
    }
}
