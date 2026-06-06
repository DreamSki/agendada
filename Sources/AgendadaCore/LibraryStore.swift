import Foundation

public final class LibraryStore {
    public private(set) var categories: [ProjectCategory]
    public private(set) var projects: [Project]
    public private(set) var notes: [Note]
    public private(set) var smartOverviews: [SmartOverview]
    public private(set) var customNoteTemplates: [CustomNoteTemplate] = []
    public private(set) var selectedProjectID: Project.ID?
    public private(set) var selectedOverview: Overview?
    public private(set) var selectedSmartOverviewID: SmartOverview.ID?
    public private(set) var selectedNoteID: Note.ID?
    public var batchSelectedNoteIDs: Set<Note.ID> = []
    public private(set) var searchText: String
    public private(set) var searchScope: SearchScope = .currentScope
    public var sortOrder: NoteSortOrder = .scheduledDateDesc
    public var sortMode: SortMode = .scheduledDate

    // MARK: - Search State

    public private(set) var searchOccurrences: [SearchOccurrence] = []
    public private(set) var currentOccurrenceIndex: Int? = nil

    // MARK: - Find in Note State

    public private(set) var findInNoteText: String = ""
    private var findInNoteNavigation: (noteID: Note.ID, query: String, bodyIndex: Int)?
    public private(set) var findInNoteOccurrences: [SearchOccurrence] = []
    public private(set) var currentFindInNoteIndex: Int? = nil

    public init(
        categories: [ProjectCategory] = [],
        projects: [Project] = [],
        notes: [Note] = [],
        smartOverviews: [SmartOverview] = [],
        selectedProjectID: Project.ID? = nil,
        selectedOverview: Overview? = .today,
        selectedSmartOverviewID: SmartOverview.ID? = nil,
        selectedNoteID: Note.ID? = nil,
        searchText: String = "",
        searchScope: SearchScope = .currentScope,
        sortOrder: NoteSortOrder = .scheduledDateDesc,
        sortMode: SortMode = .scheduledDate,
        customNoteTemplates: [CustomNoteTemplate] = []
    ) {
        self.categories = categories
        self.projects = projects
        self.notes = notes
        self.smartOverviews = smartOverviews
        self.selectedProjectID = selectedProjectID
        self.selectedOverview = selectedOverview
        self.selectedSmartOverviewID = selectedSmartOverviewID
        self.selectedNoteID = selectedNoteID
        self.searchText = searchText
        self.searchScope = searchScope
        self.sortOrder = sortOrder
        self.sortMode = sortMode
        self.customNoteTemplates = customNoteTemplates
    }

    public convenience init(snapshot: LibrarySnapshot) {
        self.init(
            categories: snapshot.categories,
            projects: snapshot.projects,
            notes: snapshot.notes,
            smartOverviews: snapshot.smartOverviews,
            selectedProjectID: snapshot.selectedProjectID,
            selectedOverview: snapshot.selectedOverview,
            selectedSmartOverviewID: snapshot.selectedSmartOverviewID,
            selectedNoteID: snapshot.selectedNoteID,
            searchText: snapshot.searchText,
            searchScope: snapshot.searchScope,
            sortOrder: snapshot.sortOrder,
            sortMode: snapshot.sortMode,
            customNoteTemplates: snapshot.customNoteTemplates
        )
    }

    public static func sample(today: Date = Date()) -> LibraryStore {
        let work = ProjectCategory(name: "工作", color: .teal)
        let personal = ProjectCategory(name: "个人", color: .orange)
        let launch = Project(name: "Agendada MVP", categoryID: work.id, color: .blue)
        let research = Project(name: "产品调研", categoryID: work.id, color: .green)
        let life = Project(name: "生活安排", categoryID: personal.id, color: .orange)

        var workCategory = work
        workCategory.projectIDs = [launch.id, research.id]
        var personalCategory = personal
        personalCategory.projectIDs = [life.id]

        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        let notes = [
            Note(
                projectID: launch.id,
                title: "第一版范围",
                body: "<p>三栏布局、本地数据模型、今天视图、当前关注、标签和基础搜索。</p><ul data-type=\"taskList\"><li data-type=\"taskItem\" data-checked=\"true\"><label><input type=\"checkbox\"></label><div><p>搭好数据模型</p></div></li><li data-type=\"taskItem\" data-checked=\"false\"><label><input type=\"checkbox\"></label><div><p>补齐时间线工作流</p></div></li></ul>",
                scheduledDate: today,
                tags: ["MVP", "范围"],
                people: ["产品"],
                isFocused: true,
                isStarred: true
            ),
            Note(
                projectID: launch.id,
                title: "编辑器取舍",
                body: "<p>第一版先用纯文本编辑区承载内容，保留后续替换为富文本编辑器的边界。</p>",
                scheduledDate: tomorrow,
                tags: ["编辑器"],
                people: ["工程"]
            ),
            Note(
                projectID: research.id,
                title: "竞品观察",
                body: "<p>记录 Apple Notes、Things、Notion、Obsidian 在项目笔记场景里的差异。</p>",
                tags: ["调研"],
                people: ["产品"],
                status: .open
            ),
            Note(
                projectID: life.id,
                title: "本周待办",
                body: "<p>把个人事务也放入同一时间线，验证工作与生活项目共存的体验。</p>",
                scheduledDate: today,
                tags: ["个人"],
                isFocused: false
            )
        ]

        return LibraryStore(
            categories: [workCategory, personalCategory],
            projects: [launch, research, life],
            notes: notes,
            selectedProjectID: nil,
            selectedOverview: .today,
            selectedNoteID: nil
        )
    }

    public var selectedNote: Note? {
        guard let selectedNoteID else { return nil }
        return notes.first { $0.id == selectedNoteID && $0.status != .trashed }
    }

    public var allTags: [String] {
        uniqueSorted(notes.flatMap(\.tags))
    }

    public var allPeople: [String] {
        uniqueSorted(notes.flatMap(\.people))
    }

    public var tagCounts: [(name: String, count: Int)] {
        let all = notes.flatMap(\.tags)
        let grouped = Dictionary(grouping: all, by: { $0 })
        return uniqueSorted(all).map { tag in
            (name: tag, count: grouped[tag]?.count ?? 0)
        }
    }

    public func renameTag(_ oldName: String, to newName: String) {
        let normalizedNew = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedNew.isEmpty, oldName != normalizedNew else { return }
        for index in notes.indices {
            if let tagIndex = notes[index].tags.firstIndex(of: oldName) {
                notes[index].tags[tagIndex] = normalizedNew
                notes[index].editedAt = Date()
            }
        }
    }

    public func deleteTag(_ name: String) {
        for index in notes.indices {
            notes[index].tags.removeAll { $0 == name }
            notes[index].editedAt = Date()
        }
    }

    public func mergeTag(_ source: String, into target: String) {
        guard source != target else { return }
        for index in notes.indices {
            var tags = notes[index].tags
            let hadSource = tags.contains(source)
            let hasTarget = tags.contains(target)
            if hadSource {
                tags.removeAll { $0 == source }
                if !hasTarget {
                    tags.append(target)
                }
                notes[index].tags = tags
                notes[index].editedAt = Date()
            }
        }
    }

    public var activeTitle: String {
        if let selectedSmartOverviewID,
           let smartOverview = smartOverview(withID: selectedSmartOverviewID) {
            return smartOverview.name
        }

        if let selectedOverview {
            return selectedOverview.title
        }

        if let selectedProjectID, let project = project(withID: selectedProjectID) {
            return project.name
        }

        return "未选择"
    }

    public func project(withID id: Project.ID) -> Project? {
        projects.first { $0.id == id }
    }

    public func category(withID id: ProjectCategory.ID) -> ProjectCategory? {
        categories.first { $0.id == id }
    }

    public func projects(in categoryID: ProjectCategory.ID) -> [Project] {
        projects.filter { $0.categoryID == categoryID && !$0.isArchived }
    }

    public func smartOverview(withID id: SmartOverview.ID) -> SmartOverview? {
        smartOverviews.first { $0.id == id }
    }

    public func selectOverview(_ overview: Overview) {
        selectedOverview = overview
        selectedProjectID = nil
        selectedSmartOverviewID = nil
        selectedNoteID = nil
        batchSelectedNoteIDs.removeAll()
    }

    public func selectProject(_ projectID: Project.ID) {
        selectedProjectID = projectID
        selectedOverview = nil
        selectedSmartOverviewID = nil
        selectedNoteID = nil
        batchSelectedNoteIDs.removeAll()
    }

    public func selectSmartOverview(_ smartOverviewID: SmartOverview.ID) {
        guard smartOverview(withID: smartOverviewID) != nil else { return }
        selectedSmartOverviewID = smartOverviewID
        selectedOverview = nil
        selectedProjectID = nil
        selectedNoteID = nil
        batchSelectedNoteIDs.removeAll()
    }

    public func selectNote(_ noteID: Note.ID) {
        guard let note = notes.first(where: { $0.id == noteID && $0.status != .trashed }) else { return }

        let noteChanged = selectedNoteID != noteID
        selectedNoteID = noteID

        // If the note is not visible in the current view, switch to its project
        if !filteredNotes().contains(where: { $0.id == noteID }) {
            selectedProjectID = note.projectID
            selectedOverview = nil
            selectedSmartOverviewID = nil
            searchText = ""
        }

        // 切换笔记时重新计算 Find in Note（如果查找文本非空）
        if noteChanged && !findInNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            calculateFindInNoteOccurrences()
        }
    }

    // MARK: - Batch Selection

    public func selectAllFilteredNotes(now: Date = Date()) {
        batchSelectedNoteIDs = Set(filteredNotes(now: now).map(\.id))
        selectedNoteID = nil
    }

    public func deselectAllNotes() {
        batchSelectedNoteIDs.removeAll()
    }

    public func toggleBatchSelection(noteID: Note.ID) {
        if batchSelectedNoteIDs.contains(noteID) {
            batchSelectedNoteIDs.remove(noteID)
        } else {
            if batchSelectedNoteIDs.isEmpty {
                selectedNoteID = nil
            }
            batchSelectedNoteIDs.insert(noteID)
        }
    }

    public func invertBatchSelection(now: Date = Date()) {
        let filteredIDs = Set(filteredNotes(now: now).map(\.id))
        batchSelectedNoteIDs = filteredIDs.subtracting(batchSelectedNoteIDs)
    }

    public func note(withID noteID: Note.ID) -> Note? {
        notes.first { $0.id == noteID }
    }

    public func relatedNotes(for noteID: Note.ID, limit: Int = 6) -> [RelatedNote] {
        guard let note = notes.first(where: { $0.id == noteID }) else { return [] }

        // Pre-build lookup map to avoid O(n) searches during sort
        let notesByID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })

        return notes
            .lazy
            .filter { $0.id != noteID && $0.status != .trashed }
            .compactMap { candidate -> (RelatedNote, Int)? in
                let reasons = self.relatedReasons(between: note, and: candidate)
                guard !reasons.isEmpty else { return nil }
                return (
                    RelatedNote(noteID: candidate.id, title: candidate.title, reasons: reasons),
                    reasons.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                }
                let lhsEditedAt = notesByID[lhs.0.noteID]?.editedAt ?? .distantPast
                let rhsEditedAt = notesByID[rhs.0.noteID]?.editedAt ?? .distantPast
                return lhsEditedAt > rhsEditedAt
            }
            .prefix(limit)
            .map(\.0)
    }

    public func summaryForFilteredNotes(now: Date = Date()) -> String {
        summaryText(for: filteredNotes(now: now), now: now)
    }

    public func summary(for noteID: Note.ID, now: Date = Date()) -> String? {
        guard let note = notes.first(where: { $0.id == noteID }) else { return nil }
        return summaryText(for: [note], now: now)
    }

    @discardableResult
    public func addNote(title: String? = nil, date: Date? = Date(), template: NoteTemplate = .blank) -> Note {
        let targetProjectID = selectedProjectID ?? projects.first?.id ?? addProject(name: "默认项目").id
        let normalizedTitle = normalizedName(title ?? template.defaultNoteTitle, fallback: template.defaultNoteTitle)
        let note = Note(
            projectID: targetProjectID,
            title: normalizedTitle,
            body: template.body,
            scheduledDate: date,
            tags: template.defaultTags,
            isBrief: true  // 新创建的笔记默认是简达
        )
        notes.insert(note, at: 0)

        // 手动排序模式下给新笔记一个位置编号，排在非置顶笔记的最上面。
        // 这样编辑后 editedAt 变化也不会打乱顺序。
        if sortMode == .manual, let idx = notes.firstIndex(where: { $0.id == note.id }) {
            let minPos = notes
                .filter { $0.projectID == note.projectID }
                .compactMap(\.position).min() ?? Self.positionGap
            notes[idx].position = minPos - Self.positionGap
        }

        selectedProjectID = targetProjectID
        selectedOverview = nil
        selectedSmartOverviewID = nil
        selectedNoteID = note.id
        return note
    }

    @discardableResult
    public func addNote(customTemplate templateID: CustomNoteTemplate.ID, date: Date? = Date()) -> Note? {
        guard let template = customNoteTemplate(withID: templateID) else { return nil }
        let targetProjectID = selectedProjectID ?? projects.first?.id ?? addProject(name: "默认项目").id
        let note = Note(
            projectID: targetProjectID,
            title: normalizedName(template.title, fallback: template.name),
            body: template.body,
            scheduledDate: date,
            tags: template.tags,
            isBrief: true
        )
        notes.insert(note, at: 0)

        if sortMode == .manual, let idx = notes.firstIndex(where: { $0.id == note.id }) {
            let minPos = notes
                .filter { $0.projectID == note.projectID }
                .compactMap(\.position).min() ?? Self.positionGap
            notes[idx].position = minPos - Self.positionGap
        }

        selectedProjectID = targetProjectID
        selectedOverview = nil
        selectedSmartOverviewID = nil
        selectedNoteID = note.id
        return note
    }

    @discardableResult
    public func addNoteForCalendarEvent(id eventID: String, title: String, startDate: Date) -> Note {
        let note = addNote(title: title, date: startDate)
        _ = associateCalendarEvent(id: eventID, title: title, startDate: startDate, to: note.id)
        return self.note(withID: note.id) ?? note
    }

    @discardableResult
    public func addNoteForReminder(id reminderID: String, title: String, dueDate: Date?) -> Note {
        let note = addNote(title: title, date: dueDate)
        _ = associateReminder(id: reminderID, title: title, dueDate: dueDate, to: note.id)
        return self.note(withID: note.id) ?? note
    }

    @discardableResult
    public func associateCalendarEvent(id eventID: String, title: String, startDate: Date, to noteID: Note.ID) -> Bool {
        associateExternalObject(
            kind: Self.calendarEventLinkKind,
            id: eventID,
            title: title,
            labelPrefix: "日程",
            date: startDate,
            to: noteID
        )
    }

    @discardableResult
    public func unassociateCalendarEvent(id eventID: String, from noteID: Note.ID) -> Bool {
        unassociateExternalObject(kind: Self.calendarEventLinkKind, id: eventID, from: noteID)
    }

    @discardableResult
    public func associateReminder(id reminderID: String, title: String, dueDate: Date?, to noteID: Note.ID) -> Bool {
        associateExternalObject(
            kind: Self.reminderLinkKind,
            id: reminderID,
            title: title,
            labelPrefix: "提醒",
            date: dueDate,
            to: noteID
        )
    }

    @discardableResult
    public func unassociateReminder(id reminderID: String, from noteID: Note.ID) -> Bool {
        unassociateExternalObject(kind: Self.reminderLinkKind, id: reminderID, from: noteID)
    }

    // MARK: - Custom Note Templates

    @discardableResult
    public func addCustomNoteTemplate(name: String, from note: Note) -> CustomNoteTemplate {
        let source = self.note(withID: note.id) ?? note
        let template = CustomNoteTemplate(
            name: name,
            title: source.title,
            body: source.body,
            tags: source.tags
        )
        customNoteTemplates.append(template)
        return template
    }

    public func deleteCustomNoteTemplate(_ templateID: CustomNoteTemplate.ID) {
        customNoteTemplates.removeAll { $0.id == templateID }
    }

    public func renameCustomNoteTemplate(_ templateID: CustomNoteTemplate.ID, name: String) {
        guard let idx = customNoteTemplates.firstIndex(where: { $0.id == templateID }) else { return }
        customNoteTemplates[idx].name = name
    }

    public func customNoteTemplate(withID templateID: CustomNoteTemplate.ID) -> CustomNoteTemplate? {
        customNoteTemplates.first { $0.id == templateID }
    }

    @discardableResult
    public func duplicateNote(_ noteID: Note.ID) -> Note? {
        guard let note = notes.first(where: { $0.id == noteID }) else { return nil }
        let copy = Note(
            projectID: note.projectID,
            title: "\(note.title) 副本",
            body: note.body,
            blockJSON: note.blockJSON,
            plainTextPreview: note.plainTextPreview,
            previewHTML: note.previewHTML,
            scheduledDate: note.scheduledDate,
            tags: note.tags,
            people: note.people,
            status: note.status,
            isFocused: note.isFocused,
            isStarred: note.isStarred,
            isCollapsed: note.isCollapsed,
            noteColor: note.noteColor,
            pinState: note.pinState,
            isBrief: note.isBrief,
            position: note.position
        )
        notes.insert(copy, at: 0)
        selectedProjectID = copy.projectID
        selectedOverview = nil
        selectedSmartOverviewID = nil
        selectedNoteID = copy.id
        return copy
    }

    public func deleteNote(_ noteID: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].status = .trashed
        notes[index].editedAt = Date()
        if selectedNoteID == noteID {
            selectedNoteID = nil
        }
    }

    public func permanentlyDeleteNote(_ noteID: Note.ID) {
        notes.removeAll { $0.id == noteID }
        if selectedNoteID == noteID {
            selectedNoteID = nil
        }
    }

    public func restoreNote(_ noteID: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].status = .open
        notes[index].editedAt = Date()
    }

    public var trashedNotes: [Note] {
        notes.filter { $0.status == .trashed }
    }

    public func emptyTrash() {
        notes.removeAll { $0.status == .trashed }
    }

    // MARK: - Batch Operations

    public func batchDeleteNotes(_ noteIDs: Set<Note.ID>) {
        for noteID in noteIDs {
            guard let index = notes.firstIndex(where: { $0.id == noteID }) else { continue }
            notes[index].status = .trashed
            notes[index].editedAt = Date()
        }
        batchSelectedNoteIDs.removeAll()
        if let sid = selectedNoteID, noteIDs.contains(sid) {
            selectedNoteID = nil
        }
    }

    public func batchRestoreNotes(_ noteIDs: Set<Note.ID>) {
        for noteID in noteIDs {
            guard let index = notes.firstIndex(where: { $0.id == noteID }) else { continue }
            notes[index].status = .open
            notes[index].editedAt = Date()
        }
        batchSelectedNoteIDs.removeAll()
    }

    public func batchPermanentlyDeleteNotes(_ noteIDs: Set<Note.ID>) {
        notes.removeAll { noteIDs.contains($0.id) }
        batchSelectedNoteIDs.removeAll()
        if let sid = selectedNoteID, noteIDs.contains(sid) {
            selectedNoteID = nil
        }
    }

    public func moveNotes(_ noteIDs: Set<Note.ID>, toProject projectID: Project.ID) {
        for noteID in noteIDs {
            guard let index = notes.firstIndex(where: { $0.id == noteID }) else { continue }
            notes[index].projectID = projectID
            notes[index].position = nil  // Reset position so target project assigns a fresh one
            notes[index].editedAt = Date()
        }
        batchSelectedNoteIDs.removeAll()
    }

    @discardableResult
    public func addProject(name: String = "新项目", categoryID: ProjectCategory.ID? = nil) -> Project {
        let normalizedName = normalizedName(name, fallback: "新项目")
        let project = Project(name: normalizedName, categoryID: categoryID)
        projects.append(project)

        if let categoryID, let categoryIndex = categories.firstIndex(where: { $0.id == categoryID }) {
            categories[categoryIndex].projectIDs.append(project.id)
        }

        selectedProjectID = project.id
        selectedOverview = nil
        selectedSmartOverviewID = nil
        selectedNoteID = nil
        return project
    }

    @discardableResult
    public func addSmartOverview(name: String, query: String) -> SmartOverview {
        let fallbackQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "has:tasks" : searchText
        let smartOverview = SmartOverview(
            name: normalizedName(name, fallback: "智能概览"),
            query: normalizedName(query, fallback: fallbackQuery)
        )
        smartOverviews.append(smartOverview)
        selectSmartOverview(smartOverview.id)
        return smartOverview
    }

    public func renameSmartOverview(_ smartOverviewID: SmartOverview.ID, name: String, query: String? = nil) {
        guard let index = smartOverviews.firstIndex(where: { $0.id == smartOverviewID }) else { return }
        smartOverviews[index].name = normalizedName(name, fallback: smartOverviews[index].name)

        if let query {
            smartOverviews[index].query = normalizedName(query, fallback: smartOverviews[index].query)
        }
    }

    public func deleteSmartOverview(_ smartOverviewID: SmartOverview.ID) {
        smartOverviews.removeAll { $0.id == smartOverviewID }

        if selectedSmartOverviewID == smartOverviewID {
            selectedSmartOverviewID = nil
            selectedOverview = .all
            selectedNoteID = nil
        }
    }

    @discardableResult
    public func addCategory(
        name: String = "未命名分类",
        color: CategoryColor = .orange,
        parentID: ProjectCategory.ID? = nil
    ) -> ProjectCategory {
        let category = ProjectCategory(
            name: normalizedName(name, fallback: "未命名分类"),
            color: color,
            parentID: parentID
        )
        categories.append(category)
        return category
    }

    public func updateCategory(
        _ categoryID: ProjectCategory.ID,
        name: String,
        color: CategoryColor
    ) {
        guard let index = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        categories[index].name = normalizedName(name, fallback: categories[index].name)
        categories[index].color = color
    }

    public func renameCategory(_ categoryID: ProjectCategory.ID, name: String) {
        guard let category = category(withID: categoryID) else { return }
        updateCategory(categoryID, name: name, color: category.color)
    }

    public func renameProject(_ projectID: Project.ID, name: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[index].name = normalizedName(name, fallback: projects[index].name)
    }

    public func deleteProject(_ projectID: Project.ID) {
        projects.removeAll { $0.id == projectID }
        notes.removeAll { $0.projectID == projectID }

        for index in categories.indices {
            categories[index].projectIDs.removeAll { $0 == projectID }
        }

        if selectedProjectID == projectID {
            selectedProjectID = nil
            selectedOverview = .all
            selectedSmartOverviewID = nil
            selectedNoteID = nil
        } else if selectedNoteID.map({ noteID in !notes.contains { $0.id == noteID } }) == true {
            selectedNoteID = nil
        }
    }

    public func deleteCategory(
        _ categoryID: ProjectCategory.ID,
        keepProjects: Bool = true
    ) {
        let affectedProjectIDs = Set(
            projects.filter { $0.categoryID == categoryID }.map(\.id)
        )
        // Also collect subcategories
        let subcategoryIDs = Set(categories.filter { $0.parentID == categoryID }.map(\.id))

        categories.removeAll { $0.id == categoryID }

        if keepProjects {
            // Projects become uncategorized
            for index in projects.indices where affectedProjectIDs.contains(projects[index].id) {
                projects[index].categoryID = nil
            }
            // Remove from all categories' projectIDs
            for catIndex in categories.indices {
                categories[catIndex].projectIDs.removeAll { affectedProjectIDs.contains($0) }
            }
            // Subcategories become top-level (parentID = nil)
            for catIndex in categories.indices where subcategoryIDs.contains(categories[catIndex].id) {
                categories[catIndex].parentID = nil
            }
        } else {
            // Legacy cascade behavior
            projects.removeAll { affectedProjectIDs.contains($0.id) }
            notes.removeAll { affectedProjectIDs.contains($0.projectID) }
        }

        if !keepProjects, let selectedProjectID, affectedProjectIDs.contains(selectedProjectID) {
            self.selectedProjectID = nil
            selectedOverview = .all
            selectedSmartOverviewID = nil
        }

        if selectedNoteID.map({ noteID in !notes.contains { $0.id == noteID } }) == true {
            selectedNoteID = nil
        }
    }

    // MARK: - Category Queries

    public var uncategorizedProjects: [Project] {
        projects.filter { $0.categoryID == nil && !$0.isArchived }
    }

    public func subcategories(of categoryID: ProjectCategory.ID) -> [ProjectCategory] {
        categories.filter { $0.parentID == categoryID }
    }

    public var topLevelCategories: [ProjectCategory] {
        categories.filter { $0.parentID == nil }
    }

    /// Projects ordered by category.projectIDs (for sidebar display).
    /// Falls back to simple filter if no ordering info.
    public func orderedProjects(in categoryID: ProjectCategory.ID) -> [Project] {
        let activeProjects = projects.filter { $0.categoryID == categoryID && !$0.isArchived }
        guard let category = category(withID: categoryID) else { return activeProjects }

        let byID = Dictionary(uniqueKeysWithValues: activeProjects.map { ($0.id, $0) })
        var ordered = category.projectIDs.compactMap { byID[$0] }

        let accountedFor = Set(ordered.map(\.id))
        let missing = activeProjects.filter { !accountedFor.contains($0.id) }
        ordered.append(contentsOf: missing)

        return ordered
    }

    public func sortProjectsAlphabetically(in categoryID: ProjectCategory.ID) {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == categoryID }) else { return }

        let sortedIDs = orderedProjects(in: categoryID)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map(\.id)

        categories[categoryIndex].projectIDs = sortedIDs
    }

    @discardableResult
    public func updateSelectedNote(title: String, body: String, scheduledDate: Date?, tags: [String], people: [String]) -> Bool {
        guard let selectedNoteID else {
            return false
        }

        return updateNote(noteID: selectedNoteID, title: title, body: body, scheduledDate: scheduledDate, tags: tags, people: people)
    }

    @discardableResult
    public func updateNote(
        noteID: Note.ID,
        title: String,
        body: String,
        blockJSON: Data? = nil,
        plainTextPreview: String? = nil,
        previewHTML: String? = nil,
        scheduledDate: Date?,
        tags: [String],
        people: [String],
        status: NoteStatus? = nil
    ) -> Bool {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else {
            return false
        }

        let nextTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "无标题" : title
        let nextBlockJSON = blockJSON ?? notes[index].blockJSON
        let nextPlainTextPreview = plainTextPreview ?? notes[index].plainTextPreview
        let nextPreviewHTML = (previewHTML != nil || blockJSON != nil) ? previewHTML : notes[index].previewHTML
        let nextTags = normalizedList(tags)
        let nextPeople = normalizedList(people)
        let nextStatus = status ?? notes[index].status

        guard notes[index].title != nextTitle ||
              notes[index].body != body ||
              notes[index].blockJSON != nextBlockJSON ||
              notes[index].plainTextPreview != nextPlainTextPreview ||
              notes[index].previewHTML != nextPreviewHTML ||
              notes[index].scheduledDate != scheduledDate ||
              notes[index].tags != nextTags ||
              notes[index].people != nextPeople ||
              notes[index].status != nextStatus else {
            return false
        }

        notes[index].title = nextTitle
        notes[index].body = body
        if let blockJSON {
            notes[index].blockJSON = blockJSON
        }
        if let plainTextPreview {
            notes[index].plainTextPreview = plainTextPreview
        }
        if previewHTML != nil || blockJSON != nil {
            notes[index].previewHTML = previewHTML
        }
        notes[index].scheduledDate = scheduledDate
        notes[index].tags = nextTags
        notes[index].people = nextPeople
        if let status {
            notes[index].status = status
        }
        notes[index].editedAt = Date()
        return true
    }

    public func setFocused(_ isFocused: Bool, noteID: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].isFocused = isFocused
        notes[index].editedAt = Date()
    }

    public func setStarred(_ isStarred: Bool, noteID: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].isStarred = isStarred
        notes[index].editedAt = Date()
    }

    public func setStatus(_ status: NoteStatus, noteID: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].status = status
        notes[index].editedAt = Date()
    }

    public func setCollapsed(_ isCollapsed: Bool, noteID: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].isCollapsed = isCollapsed
    }

    public func setNoteColor(_ noteColor: NoteColor?, noteID: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].noteColor = noteColor
        notes[index].editedAt = Date()
    }

    public func setPinState(_ pinState: PinState, noteID: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].pinState = pinState
        notes[index].editedAt = Date()
    }

    public func setBrief(_ isBrief: Bool, noteID: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].isBrief = isBrief
        notes[index].editedAt = Date()
    }

    public func scheduleToday(noteID: Note.ID, now: Date = Date()) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].scheduledDate = Calendar.current.startOfDay(for: now)
        notes[index].editedAt = Date()
    }

    public func scheduleDate(_ date: Date, noteID: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].scheduledDate = date
        notes[index].editedAt = Date()
    }

    public func clearScheduledDate(noteID: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].scheduledDate = nil
        notes[index].editedAt = Date()
    }

    public func navigateToPreviousScheduledNote(from noteID: Note.ID, now: Date = Date()) -> Note.ID? {
        guard note(withID: noteID) != nil else { return nil }
        let sorted = filteredNotes(now: now).filter { $0.scheduledDate != nil }
        guard let currentIndex = sorted.firstIndex(where: { $0.id == noteID }), currentIndex > 0 else {
            return nil
        }
        return sorted[currentIndex - 1].id
    }

    public func navigateToNextScheduledNote(from noteID: Note.ID, now: Date = Date()) -> Note.ID? {
        guard note(withID: noteID) != nil else { return nil }
        let sorted = filteredNotes(now: now).filter { $0.scheduledDate != nil }
        guard let currentIndex = sorted.firstIndex(where: { $0.id == noteID }), currentIndex < sorted.count - 1 else {
            return nil
        }
        return sorted[currentIndex + 1].id
    }

    public func navigateToTodayNote(now: Date = Date()) -> Note.ID? {
        filteredNotes(now: now).first { note in
            guard let d = note.scheduledDate else { return false }
            return Calendar.current.isDate(d, inSameDayAs: now)
        }?.id
    }

    public func timelineCounts(now: Date = Date()) -> TimelineCounts {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.safeDate(byAdding: .day, value: 1, to: startOfToday)
        let startOfDayAfter = calendar.safeDate(byAdding: .day, value: 2, to: startOfToday)

        let activeNotes = notes.filter { $0.status == .open }

        var todayCount = 0
        var tomorrowCount = 0
        var yesterdayCount = 0
        var overdueCount = 0
        var thisWeekCount = 0
        let weekday = calendar.component(.weekday, from: now)
        let daysUntilEndOfWeek = 7 - weekday
        let endOfWeek = calendar.safeDate(byAdding: .day, value: daysUntilEndOfWeek, to: startOfToday)

        for note in activeNotes {
            guard let date = note.scheduledDate else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            if startOfDay == startOfToday {
                todayCount += 1
            } else if startOfDay == startOfTomorrow {
                tomorrowCount += 1
            } else if startOfDay == calendar.safeDate(byAdding: .day, value: -1, to: startOfToday) {
                yesterdayCount += 1
            } else if startOfDay < startOfToday {
                overdueCount += 1
            } else if startOfDay >= startOfDayAfter && startOfDay <= endOfWeek {
                thisWeekCount += 1
            }
        }

        return TimelineCounts(
            today: todayCount,
            tomorrow: tomorrowCount,
            yesterday: yesterdayCount,
            overdue: overdueCount,
            thisWeek: thisWeekCount
        )
    }

    public func filteredNotes(now: Date = Date()) -> [Note] {
        let trimmedCurrentSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedSearchText = currentSavedSearchText()
        let baseNotes = currentScopeNotes(now: now)

        let trimmedSavedSearch = savedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = NoteSearchEngine.mergedQuery(savedQuery: trimmedSavedSearch, transientText: trimmedCurrentSearch)
        let matchingNotes = query.isEmpty
            ? baseNotes
            : NoteSearchEngine.filter(baseNotes, query: query, now: now)

        return sortedNotesForCurrentMode(matchingNotes)
    }

    /// 当前视图范围的基础笔记集合（不受搜索文本影响），供搜索弹窗预览使用
    public func currentScopeNotesForPreview(now: Date = Date()) -> [Note] {
        currentScopeNotes(now: now)
    }

    /// 当前视图范围的基础笔记集合（不受搜索文本影响）
    private func currentScopeNotes(now: Date) -> [Note] {
        // Smart Overview → 全库（由 query 定义范围）
        if let selectedSmartOverviewID, smartOverview(withID: selectedSmartOverviewID) != nil {
            return notes.filter { selectedOverview != .trash ? $0.status != .trashed : $0.status == .trashed }
        }

        // 搜索模式下：.all 搜索全库，.currentScope 保持当前范围
        let trimmedCurrentSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCurrentSearch.isEmpty && searchScope == .all {
            return selectedOverview == .trash
                ? notes.filter { $0.status == .trashed }
                : notes.filter { $0.status != .trashed }
        }

        // 按当前选择确定范围
        if let selectedProjectID {
            let projectNotes = notes.filter { $0.projectID == selectedProjectID }
            return selectedOverview != .trash
                ? projectNotes.filter { $0.status != .trashed }
                : projectNotes
        }

        if let selectedOverview {
            let isTrashView = selectedOverview == .trash
            let filtered = notes.filter { note in
                if isTrashView { return note.status == .trashed }
                guard note.status != .trashed else { return false }
                switch selectedOverview {
                case .today:
                    guard let scheduledDate = note.scheduledDate else { return false }
                    return Calendar.current.isDate(scheduledDate, inSameDayAs: now)
                case .tasks:
                    return note.checklistSummary.hasOpenItems && note.status != .closed
                case .upcoming:
                    guard let scheduledDate = note.scheduledDate else { return false }
                    return scheduledDate > Calendar.current.startOfDay(for: now) && note.status != .closed
                case .focused:
                    return note.isFocused
                case .starred:
                    return note.isStarred
                case .brief:
                    return note.isBrief
                case .all:
                    return true
                case .trash:
                    return false
                }
            }
            return filtered
        }

        // 默认：全部笔记
        return notes.filter { selectedOverview != .trash ? $0.status != .trashed : $0.status == .trashed }
    }

    /// 当前视图的已保存搜索文本
    private func currentSavedSearchText() -> String {
        if let selectedSmartOverviewID,
           let smartOverview = smartOverview(withID: selectedSmartOverviewID) {
            return smartOverview.query
        }
        return ""
    }

    public func globalSearchNotes(for query: String, onlyTrash: Bool = false, now: Date = Date()) -> [Note] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let baseNotes = notes.filter { note in
            onlyTrash ? note.status == .trashed : note.status != .trashed
        }
        let parsed = NoteSearchEngine.parse(trimmed)
        let matchingNotes = NoteSearchEngine.filter(baseNotes, query: parsed, now: now)
        return sortedNotesForCurrentMode(matchingNotes)
    }

    public func globalSearchOccurrences(for query: String, onlyTrash: Bool = false, now: Date = Date()) -> [SearchOccurrence] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let notes = globalSearchNotes(for: query, onlyTrash: onlyTrash, now: now)
        return NoteSearchEngine.occurrences(in: notes, query: trimmed, now: now)
    }

    public func commitSearchText(_ newText: String) {
        searchText = newText
        currentOccurrenceIndex = nil

        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearSearchOccurrences()
            return
        }

        // .all scope: 切换到全局视图（现有行为）
        // .currentScope: 保持当前 overview/project，只设搜索文本
        if searchScope == .all {
            if selectedOverview != .trash {
                selectedOverview = .all
            }
            selectedProjectID = nil
            selectedSmartOverviewID = nil
        }
        calculateSearchOccurrences()
    }

    private func sortedNotesForCurrentMode(_ matchingNotes: [Note]) -> [Note] {
        // Manual sorting mode
        if sortMode == .manual {
            return matchingNotes.sorted(by: Self.projectSortComparator)
        }

        return matchingNotes.sorted { lhs, rhs in
            // Pin state takes priority
            if lhs.pinState != rhs.pinState {
                if lhs.pinState == .pinnedTop { return true }
                if rhs.pinState == .pinnedTop { return false }
                if lhs.pinState == .pinnedBottom { return false }
                if rhs.pinState == .pinnedBottom { return true }
            }

            switch sortOrder {
            case .scheduledDateDesc:
                switch (lhs.scheduledDate, rhs.scheduledDate) {
                case let (l?, r?): return l > r
                case (nil, _?): return false
                case (_?, nil): return true
                case (nil, nil): return lhs.createdAt > rhs.createdAt
                }
            case .scheduledDateAsc:
                switch (lhs.scheduledDate, rhs.scheduledDate) {
                case let (l?, r?): return l < r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return lhs.createdAt > rhs.createdAt
                }
            case .editedAtDesc:
                return lhs.editedAt > rhs.editedAt
            case .createdAtDesc:
                return lhs.createdAt > rhs.createdAt
            }
        }
    }

    private func normalizedList(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(values.count)
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }
        return result
    }


    private func summaryText(for summaryNotes: [Note], now: Date) -> String {
        var lines = [
            "Agendada 摘要",
            "",
            "生成：\(isoDateTime(now))",
            "笔记数：\(summaryNotes.count)"
        ]

        guard !summaryNotes.isEmpty else {
            lines.append("")
            lines.append("没有匹配的笔记。")
            return lines.joined(separator: "\n")
        }

        let highlightedNotes = summaryNotes.filter { note in
            note.isStarred || note.isFocused || note.checklistSummary.hasOpenItems
        }

        if !highlightedNotes.isEmpty {
            lines.append("")
            lines.append("重点")
            for note in highlightedNotes {
                lines.append("  - \(summaryLine(for: note))")
            }
        }

        let taskLines = summaryNotes.flatMap { note in
            checklistItems(in: note).map { item in
                "  - [\(item.isCompleted ? "x" : " ")] \(note.title)：\(item.title)"
            }
        }

        if !taskLines.isEmpty {
            lines.append("")
            lines.append("待办")
            lines.append(contentsOf: taskLines)
        }

        lines.append("")
        lines.append("全部笔记")
        for note in summaryNotes {
            lines.append("  - \(summaryLine(for: note))")
        }

        return lines.joined(separator: "\n")
    }

    private func summaryLine(for note: Note) -> String {
        var parts = [note.title]

        if let project = project(withID: note.projectID) {
            parts.append("项目：\(project.name)")
        }

        if let scheduledDate = note.scheduledDate {
            parts.append("日期：\(isoDate(scheduledDate))")
        }

        if note.isStarred {
            parts.append("星标")
        }

        if note.isFocused {
            parts.append("关注")
        }

        if note.checklistSummary.totalCount > 0 {
            parts.append("待办：\(note.checklistSummary.title)")
        }

        if !note.tags.isEmpty {
            parts.append(note.tags.map { "#\($0)" }.joined(separator: " "))
        }

        if !note.people.isEmpty {
            parts.append(note.people.map { "@\($0)" }.joined(separator: " "))
        }

        parts.append("状态：\(note.status.title)")
        return parts.joined(separator: " · ")
    }

    private func checklistItems(in note: Note) -> [(title: String, isCompleted: Bool)] {
        let html = note.body

        // Parse task items from HTML (regex cached as static)
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = Self.taskItemPattern.matches(in: html, range: nsRange)

        if !matches.isEmpty {
            return matches.compactMap { match in
                guard match.numberOfRanges >= 3,
                      let checkedRange = Range(match.range(at: 1), in: html),
                      let textRange = Range(match.range(at: 2), in: html) else { return nil }
                let checked = String(html[checkedRange]) == "true"
                let text = String(html[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (title: text.isEmpty ? "未命名待办" : text, isCompleted: checked)
            }
        }

        // Fallback: parse legacy markdown checklists from plain text
        return note.bodyPlainText.components(separatedBy: .newlines).compactMap { line in
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercasedLine = trimmedLine.lowercased()
            let prefixes: [(String, Bool)] = [
                ("- [ ]", false),
                ("* [ ]", false),
                ("- [x]", true),
                ("* [x]", true)
            ]
            guard let prefix = prefixes.first(where: { lowercasedLine.hasPrefix($0.0) }) else { return nil }
            let title = String(trimmedLine.dropFirst(prefix.0.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return (title: title.isEmpty ? "未命名待办" : title, isCompleted: prefix.1)
        }
    }

    private func isoDate(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func isoDateTime(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func relatedReasons(between note: Note, and candidate: Note) -> [String] {
        var reasons: [String] = []

        if note.projectID == candidate.projectID {
            reasons.append("同一项目")
        }

        if let noteDate = note.scheduledDate,
           let candidateDate = candidate.scheduledDate,
           Calendar.current.isDate(noteDate, inSameDayAs: candidateDate) {
            reasons.append("同一天")
        }

        let sharedTags = Set(note.tags).intersection(candidate.tags)
        if !sharedTags.isEmpty {
            reasons.append("标签 \(sharedTags.sorted().joined(separator: ", "))")
        }

        let sharedPeople = Set(note.people).intersection(candidate.people)
        if !sharedPeople.isEmpty {
            reasons.append("人员 \(sharedPeople.sorted().joined(separator: ", "))")
        }

        if note.checklistSummary.hasOpenItems && candidate.checklistSummary.hasOpenItems {
            reasons.append("都有未完成待办")
        }

        // Note links: note links to candidate, or candidate links to note
        if noteLinksTo(noteID: note.id, targetID: candidate.id)
            || noteLinksTo(noteID: candidate.id, targetID: note.id) {
            reasons.append("链接")
        }

        return reasons
    }

    /// Check if a note's content contains a link to the target note.
    private func noteLinksTo(noteID: Note.ID, targetID: Note.ID) -> Bool {
        guard let note = notes.first(where: { $0.id == noteID }) else { return false }
        return linkedNoteIDs(from: note).contains(targetID)
    }

    /// Extract all note IDs linked from a note's content.
    public func linkedNoteIDs(from noteID: Note.ID) -> [Note.ID] {
        guard let note = notes.first(where: { $0.id == noteID }) else { return [] }
        return linkedNoteIDs(from: note)
    }

    /// Extract all note IDs linked from a note's content.
    public func linkedNoteIDs(from note: Note) -> [Note.ID] {
        let content = note.body + note.blockJSONString
        var ids: [Note.ID] = []
        var seen = Set<Note.ID>()
        let pattern = "agendada://note/"
        var searchStart = content.startIndex
        while let range = content.range(of: pattern, range: searchStart..<content.endIndex) {
            let afterPrefix = content[range.upperBound...]
            let uuidStr = String(afterPrefix.prefix(36))
            if let uuid = UUID(uuidString: uuidStr), seen.insert(uuid).inserted {
                ids.append(uuid)
            }
            searchStart = range.upperBound
        }
        return ids
    }

    public func backlinkedNotes(to noteID: Note.ID) -> [Note] {
        notes
            .lazy
            .filter { $0.id != noteID && $0.status != .trashed }
            .filter { self.linkedNoteIDs(from: $0).contains(noteID) }
            .sorted { $0.editedAt > $1.editedAt }
    }

    public func linkedCalendarEventIDs(from noteID: Note.ID) -> [String] {
        guard let note = notes.first(where: { $0.id == noteID }) else { return [] }
        return linkedCalendarEventIDs(from: note)
    }

    public func linkedCalendarEventIDs(from note: Note) -> [String] {
        linkedExternalIDs(kind: Self.calendarEventLinkKind, from: note)
    }

    public func linkedReminderIDs(from noteID: Note.ID) -> [String] {
        guard let note = notes.first(where: { $0.id == noteID }) else { return [] }
        return linkedReminderIDs(from: note)
    }

    public func linkedReminderIDs(from note: Note) -> [String] {
        linkedExternalIDs(kind: Self.reminderLinkKind, from: note)
    }

    public func notesLinked(toCalendarEventID eventID: String) -> [Note] {
        notesLinked(toExternalID: eventID, kind: Self.calendarEventLinkKind)
    }

    public func noteLinked(toCalendarEventID eventID: String) -> Note? {
        notesLinked(toCalendarEventID: eventID).first
    }

    public func notesLinked(toReminderID reminderID: String) -> [Note] {
        notesLinked(toExternalID: reminderID, kind: Self.reminderLinkKind)
    }

    public func noteLinked(toReminderID reminderID: String) -> Note? {
        notesLinked(toReminderID: reminderID).first
    }

    private func linkedExternalIDs(kind: String, from note: Note) -> [String] {
        let content = note.body + note.blockJSONString
        let pattern = "agendada://\(kind)/"
        var ids: [String] = []
        var seen = Set<String>()
        var searchStart = content.startIndex

        while let range = content.range(of: pattern, range: searchStart..<content.endIndex) {
            let afterPrefix = content[range.upperBound...]
            let encoded = String(afterPrefix.prefix { !Self.externalLinkTerminators.contains($0) })
            let decoded = encoded.removingPercentEncoding ?? encoded
            if !decoded.isEmpty, seen.insert(decoded).inserted {
                ids.append(decoded)
            }
            searchStart = range.upperBound
        }

        return ids
    }

    private func notesLinked(toExternalID externalID: String, kind: String) -> [Note] {
        notes
            .filter { $0.status != .trashed }
            .filter { linkedExternalIDs(kind: kind, from: $0).contains(externalID) }
            .sorted { lhs, rhs in lhs.editedAt > rhs.editedAt }
    }

    private func associateExternalObject(
        kind: String,
        id externalID: String,
        title: String,
        labelPrefix: String,
        date: Date?,
        to noteID: Note.ID
    ) -> Bool {
        let normalizedID = externalID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty,
              let index = notes.firstIndex(where: { $0.id == noteID && $0.status != .trashed }) else {
            return false
        }

        guard !linkedExternalIDs(kind: kind, from: notes[index]).contains(normalizedID) else {
            return false
        }

        let anchor = externalAssociationAnchor(
            kind: kind,
            id: normalizedID,
            label: "\(labelPrefix)：\(normalizedName(title, fallback: labelPrefix))"
        )
        let body = notes[index].body.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextBody = body.isEmpty ? anchor : "\(body)\n\(anchor)"
        updateBodyOnly(nextBody, noteIndex: index)

        if notes[index].scheduledDate == nil, let date {
            notes[index].scheduledDate = date
        }
        notes[index].editedAt = Date()
        return true
    }

    private func unassociateExternalObject(kind: String, id externalID: String, from noteID: Note.ID) -> Bool {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return false }
        let nextBody = removingExternalAssociation(kind: kind, id: externalID, from: notes[index].body)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard nextBody != notes[index].body.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }

        updateBodyOnly(nextBody, noteIndex: index)
        notes[index].editedAt = Date()
        return true
    }

    private func updateBodyOnly(_ body: String, noteIndex index: Int) {
        notes[index].body = body
        let previewNote = Note(projectID: notes[index].projectID, title: notes[index].title, body: body)
        notes[index].plainTextPreview = previewNote.plainTextPreview
        notes[index].previewHTML = nil
    }

    private func externalAssociationAnchor(kind: String, id: String, label: String) -> String {
        let encodedID = Self.encodeExternalID(id)
        return "<p><a href=\"agendada://\(kind)/\(encodedID)\">\(Self.escapeHTML(label))</a></p>"
    }

    private func removingExternalAssociation(kind: String, id externalID: String, from body: String) -> String {
        let pattern = #"<p><a href="agendada://\#(kind)/([^"]+)">[^<]*</a></p>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return body }

        var result = body
        let matches = regex.matches(in: body, range: NSRange(body.startIndex..<body.endIndex, in: body))
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2,
                  let idRange = Range(match.range(at: 1), in: body),
                  let fullRange = Range(match.range(at: 0), in: result) else {
                continue
            }
            let encodedID = String(body[idRange])
            let decodedID = encodedID.removingPercentEncoding ?? encodedID
            if decodedID == externalID {
                result.removeSubrange(fullRange)
            }
        }
        return result
    }

    private static let calendarEventLinkKind = "calendar-event"
    private static let reminderLinkKind = "reminder"
    private static let externalLinkTerminators = Set<Character>(["\"", "'", "<", ">", " ", "\n", "\r", "\t", ")", "]", "}"])
    private static let externalIDAllowedCharacters: CharacterSet = {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=\"<>%")
        return allowed
    }()

    private static func encodeExternalID(_ id: String) -> String {
        id.addingPercentEncoding(withAllowedCharacters: externalIDAllowedCharacters) ?? id
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func uniqueSorted(_ values: [String]) -> [String] {
        Array(Set(normalizedList(values))).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    private func normalizedName(_ name: String, fallback: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? fallback : trimmedName
    }

    // MARK: - Project-Scoped Sort Comparator

    /// Shared sort comparator used by manual ordering, project-scoped queries,
    /// and position rebalancing. Pin state first, then position, then stable tie-breaker.
    private static func projectSortComparator(_ lhs: Note, _ rhs: Note) -> Bool {
        if lhs.pinState != rhs.pinState {
            if lhs.pinState == .pinnedTop { return true }
            if rhs.pinState == .pinnedTop { return false }
            if lhs.pinState == .pinnedBottom { return false }
            if rhs.pinState == .pinnedBottom { return true }
        }
        switch (lhs.position, rhs.position) {
        case let (l?, r?) where l != r: return l < r
        case (_?, nil): return false   // nil (new) notes sort on top
        case (nil, _?): return true    // nil (new) notes sort on top
        default: break                 // equal or both nil — use tie-breaker
        }
        // Stable tie-breaker: newer notes first, then by ID for determinism
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    // MARK: - Position Management

    /// Sparse interval between adjacent positions. Large enough to allow many
    /// insertions before a rebalance is needed.
    private static let positionGap: Int64 = 1024
    /// Minimum allowed difference between two positions. When an insertion
    /// would produce a gap ≤ this value, the project is rebalanced instead.
    private static let positionMinGap: Int64 = 1

    // MARK: Position queries (view-scoped — reflect current filteredNotes order)

    /// Detect whether a position move would cross a pinned-top boundary.
    /// Returns true if the user should be prompted about pinning the note.
    public func wouldCrossPinnedTopBoundary(_ noteID: Note.ID, move: PositionMove) -> Bool {
        let currentNotes = projectScopedNotes(for: noteID)
        guard let currentIndex = currentNotes.firstIndex(where: { $0.id == noteID }) else { return false }
        let note = currentNotes[currentIndex]

        // Already pinned — no boundary to cross
        guard note.pinState != .pinnedTop else { return false }

        switch move {
        case .toFirst:
            return currentNotes.first?.pinState == .pinnedTop
        case .beforePrevious:
            guard currentIndex > 0 else { return false }
            return currentNotes[currentIndex - 1].pinState == .pinnedTop
        default:
            return false
        }
    }

    /// Detect whether a pinned-top note would leave the pinned group
    /// via a menu move (`.afterNext` or `.toLast`).
    /// Used by `moveWithPinCheck` to show a confirmation alert.
    public func wouldLeavePinnedTopBoundary(_ noteID: Note.ID, move: PositionMove) -> Bool {
        let currentNotes = projectScopedNotes(for: noteID)
        guard let currentIndex = currentNotes.firstIndex(where: { $0.id == noteID }) else { return false }
        let note = currentNotes[currentIndex]

        // Only pinned-top notes have a boundary to leave
        guard note.pinState == .pinnedTop else { return false }

        switch move {
        case .afterNext:
            guard currentIndex < currentNotes.count - 1 else { return false }
            return currentNotes[currentIndex + 1].pinState != .pinnedTop
        case .toLast:
            return currentNotes.last?.pinState != .pinnedTop
        default:
            return false
        }
    }

    /// Detect whether a drag-and-drop operation crosses a pin boundary.
    /// Used by `CardInteractionLayer` to decide whether to show a confirmation alert.
    public func pinBoundaryCrossing(draggedNoteID: Note.ID, targetNoteID: Note.ID) -> PinBoundaryCrossing {
        guard let dragged = note(withID: draggedNoteID),
              let target = note(withID: targetNoteID) else { return .none }

        if dragged.pinState != .pinnedTop && target.pinState == .pinnedTop {
            return .intoPinnedTop
        }
        if dragged.pinState == .pinnedTop && target.pinState != .pinnedTop {
            return .outOfPinnedTop
        }
        return .none
    }

    /// Project-scoped ordered notes for the given note's project.
    /// Used by move operations so that manual ordering is always
    /// scoped to a project, matching the drag-and-drop constraint.
    private func projectScopedNotes(for noteID: Note.ID) -> [Note] {
        guard let note = notes.first(where: { $0.id == noteID }) else { return [] }
        return projectScopedNotes(forProjectID: note.projectID)
    }

    private func projectScopedNotes(forProjectID projectID: Project.ID) -> [Note] {
        notes
            .filter { $0.projectID == projectID && $0.status != .trashed }
            .sorted(by: Self.projectSortComparator)
    }

    // MARK: Rank arithmetic

    /// Compute a new position between `before` and `after`.
    /// Returns `nil` when the gap is too tight and the project needs rebalancing.
    private func rankBetween(_ before: Int64?, _ after: Int64?) -> Int64? {
        switch (before, after) {
        case let (b?, a?) where a - b > Self.positionMinGap:
            return b + (a - b) / 2
        case let (b?, nil):
            return b + Self.positionGap
        case let (nil, a?):
            return a - Self.positionGap
        case (nil, nil):
            return Self.positionGap
        default:
            return nil  // Gap too tight — caller must rebalance
        }
    }

    /// Redistribute positions evenly across all notes in a project.
    /// After rebalancing every adjacent pair has `positionGap` between them.
    private func rebalancePositions(for projectID: Project.ID) {
        let projectNotes = projectScopedNotes(forProjectID: projectID)
        guard !projectNotes.isEmpty else { return }

        // Build an ID→index lookup once to avoid O(n²) scans in the loop.
        let indexByID = Dictionary(uniqueKeysWithValues: notes.enumerated().map { ($1.id, $0) })

        var pos: Int64 = Self.positionGap
        for note in projectNotes {
            if let idx = indexByID[note.id] {
                notes[idx].position = pos
                pos += Self.positionGap
            }
        }
    }

    /// Move note to the first position among non-pinned notes (within its project).
    public func moveToFirstNonPinned(_ noteID: Note.ID) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteID }) else { return }
        if sortMode != .manual { setSortMode(.manual) }

        let projectNotes = projectScopedNotes(for: noteID)
        let nonPinnedNotes = projectNotes.filter { $0.pinState != .pinnedTop }
        if let firstNonPinned = nonPinnedNotes.first {
            notes[noteIndex].position = (firstNonPinned.position ?? Self.positionGap) - 1
        } else {
            notes[noteIndex].position = 1
        }
        notes[noteIndex].editedAt = Date()
    }

    public func setSortMode(_ mode: SortMode) {
        sortMode = mode
        if mode == .manual {
            assignInitialPositions()
        } else {
            // Keep sortOrder in sync so the filteredNotes() non-manual path
            // (which still reads sortOrder) produces the correct ordering.
            switch mode {
            case .scheduledDate: sortOrder = .scheduledDateDesc
            case .editedAt:      sortOrder = .editedAtDesc
            case .createdAt:     sortOrder = .createdAtDesc
            default: break
            }
        }
    }

    // MARK: Move operations (project-scoped)

    public func moveNote(_ noteID: Note.ID, to move: PositionMove) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteID }) else { return }
        let note = notes[noteIndex]

        // Auto-switch to manual mode
        if sortMode != .manual {
            setSortMode(.manual)
        }

        // Project-scoped: only consider notes in the same project,
        // matching the drag-and-drop constraint.
        let projectNotes = projectScopedNotes(for: noteID)
        guard let currentIndex = projectNotes.firstIndex(where: { $0.id == noteID }) else { return }

        switch move {
        case .beforePrevious:
            guard currentIndex > 0 else { return }
            let prevNote = projectNotes[currentIndex - 1]
            insertNote(noteID, before: prevNote.id, projectNotes: projectNotes)
        case .afterNext:
            guard currentIndex < projectNotes.count - 1 else { return }
            let nextNote = projectNotes[currentIndex + 1]
            insertNote(noteID, after: nextNote.id, projectNotes: projectNotes)
        case .toFirst:
            guard let firstNote = projectNotes.first, firstNote.id != noteID else { return }
            assignToEdge(noteID, noteIndex: noteIndex, before: firstNote.id, projectID: note.projectID)
        case .toLast:
            guard let lastNote = projectNotes.last, lastNote.id != noteID else { return }
            assignToEdge(noteID, noteIndex: noteIndex, after: lastNote.id, projectID: note.projectID)
        }

        notes[noteIndex].editedAt = Date()
    }

    // Public wrappers for drag-and-drop reordering (already project-scoped via
    // the guard in CardInteractionLayer; these methods enforce it as well).

    public func insertNoteBefore(_ noteID: Note.ID, targetID: Note.ID) {
        guard noteID != targetID else { return }
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteID }) else { return }
        if sortMode != .manual { setSortMode(.manual) }
        let projectNotes = projectScopedNotes(for: noteID)
        insertNote(noteID, before: targetID, projectNotes: projectNotes)
        notes[noteIndex].editedAt = Date()
    }

    public func insertNoteAfter(_ noteID: Note.ID, targetID: Note.ID) {
        guard noteID != targetID else { return }
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteID }) else { return }
        if sortMode != .manual { setSortMode(.manual) }
        let projectNotes = projectScopedNotes(for: noteID)
        insertNote(noteID, after: targetID, projectNotes: projectNotes)
        notes[noteIndex].editedAt = Date()
    }

    // MARK: Private insert helpers

    /// Insert `noteID` immediately before `targetID` in the given project order.
    private func insertNote(_ noteID: Note.ID, before targetID: Note.ID, projectNotes: [Note]) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteID }) else { return }
        guard let targetIdx = projectNotes.firstIndex(where: { $0.id == targetID }) else { return }

        let targetPosition = projectNotes[targetIdx].position
        let prevPosition: Int64? = targetIdx > 0 ? projectNotes[targetIdx - 1].position : nil

        if let newPosition = rankBetween(prevPosition, targetPosition) {
            notes[noteIndex].position = newPosition
        } else {
            // Gap too tight — rebalance then recompute
            let projectID = notes[noteIndex].projectID
            rebalancePositions(for: projectID)
            let freshNotes = projectScopedNotes(for: noteID)
            guard let freshTargetIdx = freshNotes.firstIndex(where: { $0.id == targetID }) else { return }
            let freshTargetPos = freshNotes[freshTargetIdx].position
            let freshPrevPos: Int64? = freshTargetIdx > 0 ? freshNotes[freshTargetIdx - 1].position : nil
            notes[noteIndex].position = rankBetween(freshPrevPos, freshTargetPos)
                ?? freshTargetPos ?? Self.positionGap
        }
    }

    /// Insert `noteID` immediately after `targetID` in the given project order.
    private func insertNote(_ noteID: Note.ID, after targetID: Note.ID, projectNotes: [Note]) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteID }) else { return }
        guard let targetIdx = projectNotes.firstIndex(where: { $0.id == targetID }) else { return }

        let targetPosition = projectNotes[targetIdx].position
        let nextPosition: Int64? = targetIdx < projectNotes.count - 1
            ? projectNotes[targetIdx + 1].position : nil

        if let newPosition = rankBetween(targetPosition, nextPosition) {
            notes[noteIndex].position = newPosition
        } else {
            // Gap too tight — rebalance then recompute
            let projectID = notes[noteIndex].projectID
            rebalancePositions(for: projectID)
            let freshNotes = projectScopedNotes(for: noteID)
            guard let freshTargetIdx = freshNotes.firstIndex(where: { $0.id == targetID }) else { return }
            let freshTargetPos = freshNotes[freshTargetIdx].position
            let freshNextPos: Int64? = freshTargetIdx < freshNotes.count - 1
                ? freshNotes[freshTargetIdx + 1].position : nil
            notes[noteIndex].position = rankBetween(freshTargetPos, freshNextPos)
                ?? (freshTargetPos ?? Self.positionGap) + Self.positionGap
        }
    }

    /// Assign a note to the very beginning or end of its project order.
    private func assignToEdge(_ noteID: Note.ID, noteIndex: Int, before targetID: Note.ID, projectID: Project.ID) {
        guard let targetPosition = notes.first(where: { $0.id == targetID })?.position else { return }
        let edgePosition = rankBetween(nil, targetPosition)
        if let edgePosition {
            notes[noteIndex].position = edgePosition
        } else {
            rebalancePositions(for: projectID)
            let freshTargetPos = notes.first(where: { $0.id == targetID })?.position
            notes[noteIndex].position = rankBetween(nil, freshTargetPos)
                ?? (freshTargetPos ?? Self.positionGap) - Self.positionGap
        }
    }

    private func assignToEdge(_ noteID: Note.ID, noteIndex: Int, after targetID: Note.ID, projectID: Project.ID) {
        guard let targetPosition = notes.first(where: { $0.id == targetID })?.position else { return }
        let edgePosition = rankBetween(targetPosition, nil)
        if let edgePosition {
            notes[noteIndex].position = edgePosition
        } else {
            rebalancePositions(for: projectID)
            let freshTargetPos = notes.first(where: { $0.id == targetID })?.position
            notes[noteIndex].position = rankBetween(freshTargetPos, nil)
                ?? (freshTargetPos ?? Self.positionGap) + Self.positionGap
        }
    }

    // MARK: Initial position assignment (per-project)

    private func assignInitialPositions() {
        // Assign sparse positions to notes that don't have one yet.
        // This runs per-project so that each project gets its own
        // independent position space.
        let indexByID = Dictionary(uniqueKeysWithValues: notes.enumerated().map { ($1.id, $0) })
        let allProjectIDs = Set(notes.map(\.projectID))
        for projectID in allProjectIDs {
            let projectNotes = projectScopedNotes(forProjectID: projectID)
            let needsPosition = projectNotes.filter { $0.position == nil }
            guard !needsPosition.isEmpty else { continue }

            let minExisting = projectNotes.compactMap(\.position).min() ?? Self.positionGap
            var pos = minExisting - Int64(needsPosition.count) * Self.positionGap
            for note in needsPosition {
                if let noteIndex = indexByID[note.id] {
                    notes[noteIndex].position = pos
                    pos += Self.positionGap
                }
            }
        }
    }

    // MARK: - Search Engine

    /// 更新搜索文本并重新计算所有命中位置（同步，适合一次性提交）。
    /// Auto-selects the first matching note — appropriate for programmatic use
    /// (e.g. tests, Enter key). The debounced typing path in ObservableLibraryStore
    /// uses setSearchTextOnly + calculateSearchOccurrences to avoid the auto-select.
    public func updateSearchText(_ newText: String) {
        searchText = newText
        calculateSearchOccurrences()
        if let first = searchOccurrences.first {
            selectedNoteID = first.noteID
        }
    }

    /// 仅设置搜索文本，不触发计算（由 ObservableLibraryStore 的 debounce 机制调用）
    public func setSearchTextOnly(_ newText: String) {
        searchText = newText
    }

    public func setSearchScope(_ scope: SearchScope) {
        searchScope = scope
    }

    /// 清除所有搜索命中（搜索文本已清空时调用）
    public func clearSearchOccurrences() {
        searchOccurrences = []
        currentOccurrenceIndex = nil
    }

    /// 重新计算搜索命中位置（由 debounce 机制调用）
    public func calculateSearchOccurrences() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            searchOccurrences = []
            currentOccurrenceIndex = nil
            return
        }

        // 通过 NoteSearchEngine 解析查询并计算命中位置
        let query = NoteSearchEngine.parse(trimmed)

        // 获取过滤后的笔记列表（应用全部搜索语法）
        let notes = filteredNotes()

        searchOccurrences = NoteSearchEngine.occurrences(in: notes, query: query)
        currentOccurrenceIndex = nil
        // Leave currentOccurrenceIndex as nil so the first Enter/next press
        // lands on the first match (goToNextSearchOccurrence resolves
        // (nil ?? -1) + 1 = 0 → index 0). Do NOT auto-select the first note
        // here — that would trigger an onChange storm across all StreamNoteRow views.
    }

    /// 用于 UI 高亮的纯关键词（空格分隔）
    public var searchHighlightText: String {
        NoteSearchEngine.highlightText(for: searchText)
    }

    // MARK: - Find in Note

    /// 设置查找文本，只在当前笔记内搜索
    public func updateFindInNoteText(_ text: String) {
        findInNoteText = text
        calculateFindInNoteOccurrences()
        // 不自动切换笔记，让用户在当前笔记内查找
    }

    /// 计算当前笔记内的 occurrence
    public func calculateFindInNoteOccurrences() {
        let trimmed = findInNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let noteID = selectedNoteID else {
            findInNoteOccurrences = []
            currentFindInNoteIndex = nil
            findInNoteNavigation = nil
            return
        }

        guard let note = note(withID: noteID) else { return }

        // 为 WebView onReady 准备导航（当笔记重新加载时能重新应用查找）
        findInNoteNavigation = (noteID, trimmed, 0)

        let query = NoteSearchEngine.parse(trimmed)
        var result: [SearchOccurrence] = []

        // 只在当前笔记内搜索
        let titleHits = sortedUniqueHitsInText(note.title, terms: query.highlightTerms)
        var bodyIdx = 0

        for hit in titleHits {
            result.append(SearchOccurrence(
                noteID: note.id,
                noteTitle: note.title,
                globalIndex: result.count,
                occurrenceIndexInNote: result.count,
                bodyIndexInNote: -1,
                field: .title,
                matchPosition: hit.position,
                matchLength: hit.length,
                excerpt: hit.excerpt
            ))
        }

        let bodyHits = sortedUniqueHitsInText(note.bodyPlainText, terms: query.highlightTerms)
        for hit in bodyHits {
            result.append(SearchOccurrence(
                noteID: note.id,
                noteTitle: note.title,
                globalIndex: result.count,
                occurrenceIndexInNote: result.count,
                bodyIndexInNote: bodyIdx,
                field: .body,
                matchPosition: hit.position,
                matchLength: hit.length,
                excerpt: hit.excerpt
            ))
            bodyIdx += 1
        }

        findInNoteOccurrences = result
        currentFindInNoteIndex = result.isEmpty ? nil : 0
    }

    /// 当前笔记内下一个命中
    public func goToNextInNote() -> SearchOccurrence? {
        guard !findInNoteOccurrences.isEmpty else { return nil }
        let nextIdx = ((currentFindInNoteIndex ?? -1) + 1) % findInNoteOccurrences.count
        currentFindInNoteIndex = nextIdx
        return findInNoteOccurrences[safe: nextIdx]
    }

    /// 当前笔记内上一个命中
    public func goToPreviousInNote() -> SearchOccurrence? {
        guard !findInNoteOccurrences.isEmpty else { return nil }
        let prevIdx = ((currentFindInNoteIndex ?? 0) - 1 + findInNoteOccurrences.count) % findInNoteOccurrences.count
        currentFindInNoteIndex = prevIdx
        return findInNoteOccurrences[safe: prevIdx]
    }

    /// 清空 Find in Note 状态
    public func clearFindInNote() {
        findInNoteText = ""
        findInNoteOccurrences = []
        currentFindInNoteIndex = nil
        findInNoteNavigation = nil
    }

    /// 消费 Find in Note 导航（用于 WebView 加载时应用查找）
    public func consumeFindInNoteNavigation(for noteID: Note.ID) -> (query: String, bodyIndex: Int)? {
        guard let pending = findInNoteNavigation, pending.noteID == noteID else { return nil }
        findInNoteNavigation = nil
        return (pending.query, pending.bodyIndex)
    }

    /// Find in Note 摘要
    public var findInNoteSummary: FindInNoteSummary {
        guard !findInNoteOccurrences.isEmpty else { return .empty }
        return FindInNoteSummary(
            totalOccurrences: findInNoteOccurrences.count,
            currentIndex: (currentFindInNoteIndex ?? -1) + 1
        )
    }

    private func sortedUniqueHitsInText(_ text: String, terms: [NoteSearchTextTerm]) -> [SearchHit] {
        var hits: [SearchHit] = []
        var seen = Set<String>()

        for term in terms where !term.value.isEmpty {
            for hit in hitsForTerm(term.value, in: text) {
                let key = "\(hit.position):\(hit.length)"
                if seen.insert(key).inserted {
                    hits.append(hit)
                }
            }
        }

        return hits.sorted {
            if $0.position != $1.position { return $0.position < $1.position }
            return $0.length > $1.length
        }
    }

    private func hitsForTerm(_ term: String, in text: String) -> [SearchHit] {
        guard !term.isEmpty, !text.isEmpty else { return [] }

        var hits: [SearchHit] = []
        var searchStart = text.startIndex

        while let range = text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], range: searchStart..<text.endIndex) {
            let nsRange = NSRange(range, in: text)
            hits.append(SearchHit(
                position: nsRange.location,
                length: nsRange.length,
                excerpt: excerpt(around: range, in: text)
            ))

            guard range.upperBound < text.endIndex else { break }
            searchStart = range.upperBound
        }

        return hits
    }

    private func excerpt(around range: Range<String.Index>, in text: String) -> String {
        let context = 30
        let lower = text.index(range.lowerBound, offsetBy: -context, limitedBy: text.startIndex) ?? text.startIndex
        let upper = text.index(range.upperBound, offsetBy: context, limitedBy: text.endIndex) ?? text.endIndex
        var value = String(text[lower..<upper]).trimmingCharacters(in: .whitespacesAndNewlines)
        if lower > text.startIndex { value = "…" + value }
        if upper < text.endIndex { value += "…" }
        return value
    }

    // MARK: - Occurrence Navigation

    /// 当前所在的命中位置
    public var currentOccurrence: SearchOccurrence? {
        guard let idx = currentOccurrenceIndex,
              idx >= 0, idx < searchOccurrences.count else { return nil }
        return searchOccurrences[idx]
    }

    /// 跳转到下一个命中位置
    @discardableResult
    public func goToNextSearchOccurrence() -> SearchOccurrence? {
        guard !searchOccurrences.isEmpty else { return nil }

        let nextIdx = ((currentOccurrenceIndex ?? -1) + 1) % searchOccurrences.count
        currentOccurrenceIndex = nextIdx

        let occ = searchOccurrences[nextIdx]
        // 跨笔记时切换 selectedNoteID
        if occ.noteID != selectedNoteID {
            selectedNoteID = occ.noteID
        }
        return occ
    }

    /// 跳转到上一个命中位置
    @discardableResult
    public func goToPreviousSearchOccurrence() -> SearchOccurrence? {
        guard !searchOccurrences.isEmpty else { return nil }

        let prevIdx = ((currentOccurrenceIndex ?? 0) - 1 + searchOccurrences.count) % searchOccurrences.count
        currentOccurrenceIndex = prevIdx

        let occ = searchOccurrences[prevIdx]
        if occ.noteID != selectedNoteID {
            selectedNoteID = occ.noteID
        }
        return occ
    }

    /// 搜索摘要信息
    public var searchSummary: SearchSummary {
        guard !searchOccurrences.isEmpty else { return .empty }

        let currentIdx = currentOccurrenceIndex ?? 0
        let currentNoteID = searchOccurrences[safe: currentIdx]?.noteID

        // 计算当前所在笔记的索引
        let uniqueNoteIDs = orderedMatchedNoteIDs()
        let noteIdx = currentNoteID.flatMap { id in
            uniqueNoteIDs.firstIndex(of: id)
        } ?? 0

        return SearchSummary(
            totalOccurrences: searchOccurrences.count,
            totalMatchedNotes: uniqueNoteIDs.count,
            currentOccurrenceIndex: currentIdx + 1, // 1-based for display
            currentNoteIndex: noteIdx + 1
        )
    }

    /// 按 filteredNotes 顺序返回匹配到的笔记 ID 列表
    private func orderedMatchedNoteIDs() -> [Note.ID] {
        let noteIDs = Set(searchOccurrences.map(\.noteID))
        let filtered = filteredNotes()
        return filtered.compactMap { noteIDs.contains($0.id) ? $0.id : nil }
    }

    public func snapshot() -> LibrarySnapshot {
        #if DEBUG
        let start = Date()
        #endif
        let result = LibrarySnapshot(
            categories: categories,
            projects: projects,
            notes: notes,
            smartOverviews: smartOverviews,
            selectedProjectID: selectedProjectID,
            selectedOverview: selectedOverview,
            selectedSmartOverviewID: selectedSmartOverviewID,
            selectedNoteID: selectedNoteID,
            searchText: searchText,
            searchScope: searchScope,
            sortOrder: sortOrder,
            sortMode: sortMode,
            customNoteTemplates: customNoteTemplates
        )
        #if DEBUG
        let elapsed = Date().timeIntervalSince(start)
        if elapsed > 0.010 {  // 只记录超过 10ms 的
            print("⚠️ [PERF] snapshot() took \(String(format: "%.3f", elapsed))s - notes: \(notes.count)")
        }
        #endif
        return result
    }

    // MARK: - Cached Resources

    private static let taskItemPattern = try! NSRegularExpression(
        pattern: #"<li data-type="taskItem" data-checked="(true|false)"><label><input type="checkbox"></label><div><p>(.*?)</p></div></li>"#,
        options: []
    )
}

// MARK: - Array Safe Access Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
