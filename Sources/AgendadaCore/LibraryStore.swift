import Foundation

public final class LibraryStore {
    public private(set) var categories: [ProjectCategory]
    public private(set) var projects: [Project]
    public private(set) var notes: [Note]
    public private(set) var smartOverviews: [SmartOverview]
    public private(set) var selectedProjectID: Project.ID?
    public private(set) var selectedOverview: Overview?
    public private(set) var selectedSmartOverviewID: SmartOverview.ID?
    public private(set) var selectedNoteID: Note.ID?
    public var searchText: String

    public init(
        categories: [ProjectCategory] = [],
        projects: [Project] = [],
        notes: [Note] = [],
        smartOverviews: [SmartOverview] = [],
        selectedProjectID: Project.ID? = nil,
        selectedOverview: Overview? = .today,
        selectedSmartOverviewID: SmartOverview.ID? = nil,
        selectedNoteID: Note.ID? = nil,
        searchText: String = ""
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
            searchText: snapshot.searchText
        )
    }

    public static func sample(today: Date = Date()) -> LibraryStore {
        let work = ProjectCategory(name: "工作")
        let personal = ProjectCategory(name: "个人")
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
                body: """
                三栏布局、本地数据模型、今天视图、当前关注、标签和基础搜索。

                - [x] 搭好数据模型
                - [ ] 补齐时间线工作流
                """,
                scheduledDate: today,
                tags: ["MVP", "范围"],
                people: ["产品"],
                isFocused: true,
                isStarred: true
            ),
            Note(
                projectID: launch.id,
                title: "编辑器取舍",
                body: "第一版先用纯文本编辑区承载内容，保留后续替换为富文本编辑器的边界。",
                scheduledDate: tomorrow,
                tags: ["编辑器"],
                people: ["工程"]
            ),
            Note(
                projectID: research.id,
                title: "竞品观察",
                body: "记录 Apple Notes、Things、Notion、Obsidian 在项目笔记场景里的差异。",
                tags: ["调研"],
                people: ["产品"],
                status: .open
            ),
            Note(
                projectID: life.id,
                title: "本周待办",
                body: "把个人事务也放入同一时间线，验证工作与生活项目共存的体验。",
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
            selectedNoteID: notes.first?.id
        )
    }

    public var selectedNote: Note? {
        guard let selectedNoteID else { return nil }
        return notes.first { $0.id == selectedNoteID }
    }

    public var allTags: [String] {
        uniqueSorted(notes.flatMap(\.tags))
    }

    public var allPeople: [String] {
        uniqueSorted(notes.flatMap(\.people))
    }

    public var tagCounts: [(name: String, count: Int)] {
        let all = notes.flatMap(\.tags)
        return uniqueSorted(all).map { tag in
            (name: tag, count: all.filter { $0 == tag }.count)
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
        selectedNoteID = filteredNotes().first?.id
    }

    public func selectProject(_ projectID: Project.ID) {
        selectedProjectID = projectID
        selectedOverview = nil
        selectedSmartOverviewID = nil
        selectedNoteID = filteredNotes().first?.id
    }

    public func selectSmartOverview(_ smartOverviewID: SmartOverview.ID) {
        guard smartOverview(withID: smartOverviewID) != nil else { return }
        selectedSmartOverviewID = smartOverviewID
        selectedOverview = nil
        selectedProjectID = nil
        selectedNoteID = filteredNotes().first?.id
    }

    public func selectNote(_ noteID: Note.ID) {
        selectedNoteID = noteID
    }

    public func note(withID noteID: Note.ID) -> Note? {
        notes.first { $0.id == noteID }
    }

    public func relatedNotes(for noteID: Note.ID, limit: Int = 6) -> [RelatedNote] {
        guard let note = notes.first(where: { $0.id == noteID }) else { return [] }

        return notes
            .filter { $0.id != noteID }
            .compactMap { candidate -> (RelatedNote, Int)? in
                let reasons = relatedReasons(between: note, and: candidate)
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

                let lhsEditedAt = notes.first { $0.id == lhs.0.noteID }?.editedAt ?? .distantPast
                let rhsEditedAt = notes.first { $0.id == rhs.0.noteID }?.editedAt ?? .distantPast
                return lhsEditedAt > rhsEditedAt
            }
            .prefix(limit)
            .map(\.0)
    }

    public func summaryMarkdownForFilteredNotes(now: Date = Date()) -> String {
        summaryMarkdown(for: filteredNotes(now: now), now: now)
    }

    public func summaryMarkdown(for noteID: Note.ID, now: Date = Date()) -> String? {
        guard let note = notes.first(where: { $0.id == noteID }) else { return nil }
        return summaryMarkdown(for: [note], now: now)
    }

    @discardableResult
    public func addNote(title: String? = nil, date: Date? = Date(), template: NoteTemplate = .blank) -> Note {
        let targetProjectID = selectedProjectID ?? projects.first?.id ?? addProject(name: "默认项目").id
        let note = Note(
            projectID: targetProjectID,
            title: normalizedName(title ?? template.defaultNoteTitle, fallback: template.defaultNoteTitle),
            body: template.body,
            scheduledDate: date,
            tags: template.defaultTags
        )
        notes.insert(note, at: 0)
        selectedProjectID = targetProjectID
        selectedOverview = nil
        selectedSmartOverviewID = nil
        selectedNoteID = note.id
        return note
    }

    @discardableResult
    public func duplicateNote(_ noteID: Note.ID) -> Note? {
        guard let note = notes.first(where: { $0.id == noteID }) else { return nil }
        let copy = Note(
            projectID: note.projectID,
            title: "\(note.title) 副本",
            body: note.body,
            scheduledDate: note.scheduledDate,
            tags: note.tags,
            people: note.people,
            status: note.status,
            isFocused: note.isFocused,
            isStarred: note.isStarred,
            isCollapsed: note.isCollapsed,
            noteColor: note.noteColor,
            pinState: note.pinState
        )
        notes.insert(copy, at: 0)
        selectedProjectID = copy.projectID
        selectedOverview = nil
        selectedSmartOverviewID = nil
        selectedNoteID = copy.id
        return copy
    }

    public func deleteNote(_ noteID: Note.ID) {
        notes.removeAll { $0.id == noteID }
        if selectedNoteID == noteID {
            selectedNoteID = filteredNotes().first?.id
        }
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
        selectedNoteID = filteredNotes().first?.id
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
            selectedNoteID = filteredNotes().first?.id
        }
    }

    @discardableResult
    public func addCategory(name: String = "新分类") -> ProjectCategory {
        let category = ProjectCategory(name: normalizedName(name, fallback: "新分类"))
        categories.append(category)
        return category
    }

    public func renameCategory(_ categoryID: ProjectCategory.ID, name: String) {
        guard let index = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        categories[index].name = normalizedName(name, fallback: categories[index].name)
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
            selectedNoteID = filteredNotes().first?.id
        } else if selectedNoteID.map({ noteID in !notes.contains { $0.id == noteID } }) == true {
            selectedNoteID = filteredNotes().first?.id
        }
    }

    public func deleteCategory(_ categoryID: ProjectCategory.ID) {
        let projectIDs = Set(projects.filter { $0.categoryID == categoryID }.map(\.id))
        categories.removeAll { $0.id == categoryID }
        projects.removeAll { projectIDs.contains($0.id) }
        notes.removeAll { projectIDs.contains($0.projectID) }

        if let selectedProjectID, projectIDs.contains(selectedProjectID) {
            self.selectedProjectID = nil
            selectedOverview = .all
            selectedSmartOverviewID = nil
        }

        if selectedNoteID.map({ noteID in !notes.contains { $0.id == noteID } }) == true {
            selectedNoteID = filteredNotes().first?.id
        }
    }

    public func updateSelectedNote(title: String, body: String, scheduledDate: Date?, tags: [String], people: [String]) {
        guard let selectedNoteID else {
            return
        }

        updateNote(noteID: selectedNoteID, title: title, body: body, scheduledDate: scheduledDate, tags: tags, people: people)
    }

    public func updateNote(
        noteID: Note.ID,
        title: String,
        body: String,
        scheduledDate: Date?,
        tags: [String],
        people: [String],
        status: NoteStatus? = nil
    ) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else {
            return
        }

        notes[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "无标题" : title
        notes[index].body = body
        notes[index].scheduledDate = scheduledDate
        notes[index].tags = normalizedList(tags)
        notes[index].people = normalizedList(people)
        if let status {
            notes[index].status = status
        }
        notes[index].editedAt = Date()
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
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let startOfDayAfter = calendar.date(byAdding: .day, value: 2, to: startOfToday)!

        let activeNotes = notes.filter { $0.status == .open }

        var todayCount = 0
        var tomorrowCount = 0
        var yesterdayCount = 0
        var overdueCount = 0
        var thisWeekCount = 0
        let weekday = calendar.component(.weekday, from: now)
        let daysUntilEndOfWeek = 7 - weekday
        let endOfWeek = calendar.date(byAdding: .day, value: daysUntilEndOfWeek, to: startOfToday)!

        for note in activeNotes {
            guard let date = note.scheduledDate else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            if startOfDay == startOfToday {
                todayCount += 1
            } else if startOfDay == startOfTomorrow {
                tomorrowCount += 1
            } else if startOfDay == calendar.date(byAdding: .day, value: -1, to: startOfToday)! {
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
        let baseNotes: [Note]
        let savedSearchText: String

        if let selectedSmartOverviewID,
           let smartOverview = smartOverview(withID: selectedSmartOverviewID) {
            baseNotes = notes
            savedSearchText = smartOverview.query
        } else if let selectedProjectID {
            baseNotes = notes.filter { $0.projectID == selectedProjectID }
            savedSearchText = ""
        } else if let selectedOverview {
            baseNotes = notes.filter { note in
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
                case .all:
                    return true
                }
            }
            savedSearchText = ""
        } else {
            baseNotes = notes
            savedSearchText = ""
        }

        let trimmedSavedSearch = savedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let queryParts = [trimmedSavedSearch, trimmedSearchText].filter { !$0.isEmpty }
        let trimmedSearch = queryParts.joined(separator: " ").lowercased()
        let matchingNotes = trimmedSearch.isEmpty
            ? baseNotes
            : baseNotes.filter { note in
                matchesSearch(trimmedSearch, note: note, now: now)
            }

        return matchingNotes.sorted { lhs, rhs in
            // Pin state takes priority
            if lhs.pinState != rhs.pinState {
                if lhs.pinState == .pinnedTop { return true }
                if rhs.pinState == .pinnedTop { return false }
                if lhs.pinState == .pinnedBottom { return false }
                if rhs.pinState == .pinnedBottom { return true }
            }

            switch (lhs.scheduledDate, rhs.scheduledDate) {
            case let (lhsDate?, rhsDate?):
                if lhsDate == rhsDate {
                    return lhs.editedAt > rhs.editedAt
                }
                return lhsDate < rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.editedAt > rhs.editedAt
            }
        }
    }

    private func normalizedList(_ values: [String]) -> [String] {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: []) { result, value in
                if !result.contains(value) {
                    result.append(value)
                }
            }
    }

    private func matchesSearch(_ searchText: String, note: Note, now: Date) -> Bool {
        let terms = searchText.split(separator: " ").map(String.init)
        let haystack = ([note.title, note.body] + note.tags + note.people).joined(separator: " ").lowercased()

        return terms.allSatisfy { term in
            if let tag = prefixedValue("tag:", in: term) {
                return note.tags.contains { $0.lowercased() == tag }
            }

            if let person = prefixedValue("person:", in: term) {
                return note.people.contains { $0.lowercased() == person }
            }

            if let status = prefixedValue("status:", in: term) {
                return note.status.rawValue == status || note.status.title.lowercased() == status
            }

            if term == "has:tasks" {
                return note.checklistSummary.hasOpenItems
            }

            if term == "has:date" {
                return note.scheduledDate != nil
            }

            if term == "is:focused" {
                return note.isFocused
            }

            if term == "is:starred" {
                return note.isStarred
            }

            if term == "date:today" {
                guard let scheduledDate = note.scheduledDate else { return false }
                return Calendar.current.isDate(scheduledDate, inSameDayAs: now)
            }

            if term == "date:upcoming" {
                guard let scheduledDate = note.scheduledDate else { return false }
                return scheduledDate > Calendar.current.startOfDay(for: now)
            }

            return haystack.contains(term)
        }
    }

    private func summaryMarkdown(for summaryNotes: [Note], now: Date) -> String {
        var lines = [
            "# Agendada 摘要",
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
            lines.append("## 重点")
            for note in highlightedNotes {
                lines.append("- \(summaryLine(for: note))")
            }
        }

        let taskLines = summaryNotes.flatMap { note in
            checklistItems(in: note).map { item in
                "- [\(item.isCompleted ? "x" : " ")] \(note.title)：\(item.title)"
            }
        }

        if !taskLines.isEmpty {
            lines.append("")
            lines.append("## 待办")
            lines.append(contentsOf: taskLines)
        }

        lines.append("")
        lines.append("## 全部笔记")
        for note in summaryNotes {
            lines.append("- \(summaryLine(for: note))")
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
        note.body.components(separatedBy: .newlines).compactMap { line in
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercasedLine = trimmedLine.lowercased()
            let prefixes: [(String, Bool)] = [
                ("- [ ]", false),
                ("* [ ]", false),
                ("- [x]", true),
                ("* [x]", true)
            ]

            guard let prefix = prefixes.first(where: { lowercasedLine.hasPrefix($0.0) }) else {
                return nil
            }

            let title = String(trimmedLine.dropFirst(prefix.0.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
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

        return reasons
    }

    private func prefixedValue(_ prefix: String, in term: String) -> String? {
        guard term.hasPrefix(prefix) else { return nil }
        let value = String(term.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
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

    public func snapshot() -> LibrarySnapshot {
        LibrarySnapshot(
            categories: categories,
            projects: projects,
            notes: notes,
            smartOverviews: smartOverviews,
            selectedProjectID: selectedProjectID,
            selectedOverview: selectedOverview,
            selectedSmartOverviewID: selectedSmartOverviewID,
            selectedNoteID: selectedNoteID,
            searchText: searchText
        )
    }
}
