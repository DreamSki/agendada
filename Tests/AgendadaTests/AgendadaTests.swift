import Foundation
import Testing
@testable import AgendadaCore

@Test func todayOverviewOnlyShowsTodayNotes() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let store = LibraryStore.sample(today: now)

    store.selectOverview(.today)
    let notes = store.filteredNotes(now: now)

    #expect(notes.isEmpty == false)
    #expect(notes.allSatisfy { note in
        guard let scheduledDate = note.scheduledDate else { return false }
        return Calendar.current.isDate(scheduledDate, inSameDayAs: now)
    })
}

@Test func focusedOverviewOnlyShowsFocusedNotes() async throws {
    let store = LibraryStore.sample()

    store.selectOverview(.focused)
    let notes = store.filteredNotes()

    #expect(notes.isEmpty == false)
    #expect(notes.allSatisfy { $0.isFocused })
}

@Test func upcomingOverviewShowsFutureDatedNotes() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let store = LibraryStore.sample(today: now)

    store.selectOverview(.upcoming)
    let notes = store.filteredNotes(now: now)

    #expect(notes.isEmpty == false)
    #expect(notes.allSatisfy { note in
        guard let scheduledDate = note.scheduledDate else { return false }
        return scheduledDate > Calendar.current.startOfDay(for: now)
    })
}

@Test func tasksOverviewShowsNotesWithOpenChecklistItems() async throws {
    let store = LibraryStore.sample()

    store.selectOverview(.tasks)
    let notes = store.filteredNotes()

    #expect(notes.isEmpty == false)
    #expect(notes.allSatisfy { $0.checklistSummary.hasOpenItems })
}

@Test func starredOverviewOnlyShowsStarredNotes() async throws {
    let store = LibraryStore.sample()

    store.selectOverview(.starred)
    let notes = store.filteredNotes()

    #expect(notes.isEmpty == false)
    #expect(notes.allSatisfy { $0.isStarred })
}

@Test func checklistSummaryCountsMarkdownTasks() async throws {
    let project = Project(name: "项目")
    let note = Note(
        projectID: project.id,
        title: "清单",
        body: """
        - [ ] 未完成
        - [x] 已完成
        * [ ] 另一个未完成
        """
    )

    #expect(note.checklistSummary.openCount == 2)
    #expect(note.checklistSummary.completedCount == 1)
    #expect(note.checklistSummary.totalCount == 3)
}

@Test func filteredNotesCanBeCopiedAsMarkdownSummary() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let store = LibraryStore.sample(today: now)
    store.selectOverview(.tasks)

    let summary = store.summaryForFilteredNotes(now: now)

    #expect(summary.contains("Agendada 摘要"))
    #expect(summary.contains("重点"))
    #expect(summary.contains("待办"))
    #expect(summary.contains("第一版范围"))
    #expect(summary.contains("[ ] 第一版范围：补齐时间线工作流"))
    #expect(summary.contains("#MVP"))
    #expect(summary.contains("@产品"))
}

@Test func singleNoteCanBeCopiedAsMarkdownSummary() async throws {
    let store = LibraryStore.sample()
    let note = try #require(store.filteredNotes().first)

    let summary = try #require(store.summary(for: note.id))

    #expect(summary.contains("笔记数：1"))
    #expect(summary.contains(note.title))
    #expect(summary.contains("状态：\(note.status.title)"))
}

@Test func searchMatchesTagsAndPeople() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)

    store.searchText = "工程"

    #expect(store.filteredNotes().contains { $0.people.contains("工程") })
}

@Test func searchSupportsOpenTaskPredicate() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)

    store.searchText = "has:tasks"

    let notes = store.filteredNotes()
    #expect(notes.isEmpty == false)
    #expect(notes.allSatisfy { $0.checklistSummary.hasOpenItems })
}

@Test func searchSupportsDateAndBooleanPredicates() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let store = LibraryStore.sample(today: now)
    store.selectOverview(.all)

    store.searchText = "is:starred date:today"

    let notes = store.filteredNotes(now: now)
    #expect(notes.isEmpty == false)
    #expect(notes.allSatisfy { note in
        guard let scheduledDate = note.scheduledDate else { return false }
        return note.isStarred && Calendar.current.isDate(scheduledDate, inSameDayAs: now)
    })
}

@Test func searchSupportsTagAndPersonPrefixes() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)

    store.searchText = "tag:MVP person:产品"

    let notes = store.filteredNotes()
    #expect(notes.isEmpty == false)
    #expect(notes.allSatisfy { $0.tags.contains("MVP") && $0.people.contains("产品") })
}

@Test func relatedNotesExplainSharedContext() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)
    let note = try #require(store.filteredNotes().first { $0.tags.contains("MVP") })

    let relatedNotes = store.relatedNotes(for: note.id)

    #expect(relatedNotes.isEmpty == false)
    #expect(relatedNotes.contains { relatedNote in
        relatedNote.reasons.contains("同一项目") || relatedNote.reasons.contains { $0.hasPrefix("人员 ") }
    })
}

@Test func snapshotRoundTripsThroughJSON() async throws {
    let store = LibraryStore.sample()
    let smartOverview = store.addSmartOverview(name: "有待办", query: "has:tasks")
    let snapshot = store.snapshot()

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(snapshot)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(LibrarySnapshot.self, from: data)

    #expect(decoded.categories == snapshot.categories)
    #expect(decoded.projects == snapshot.projects)
    #expect(decoded.notes.map(\.id) == snapshot.notes.map(\.id))
    #expect(decoded.notes.map(\.title) == snapshot.notes.map(\.title))
    #expect(decoded.selectedOverview == snapshot.selectedOverview)
    #expect(decoded.smartOverviews == [smartOverview])
    #expect(decoded.selectedSmartOverviewID == smartOverview.id)
}

@Test func legacySnapshotWithoutSmartOverviewsStillDecodes() async throws {
    let json = """
    {
      "categories": [],
      "projects": [],
      "notes": [],
      "selectedProjectID": null,
      "selectedOverview": "all",
      "selectedNoteID": null,
      "searchText": ""
    }
    """

    let decoded = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(json.utf8))

    #expect(decoded.smartOverviews.isEmpty)
    #expect(decoded.selectedSmartOverviewID == nil)
    #expect(decoded.selectedOverview == .all)
}

@Test func smartOverviewFiltersBySavedQuery() async throws {
    let store = LibraryStore.sample()
    let smartOverview = store.addSmartOverview(name: "有待办", query: "has:tasks")
    store.searchText = ""

    let notes = store.filteredNotes()

    #expect(store.selectedSmartOverviewID == smartOverview.id)
    #expect(store.activeTitle == "有待办")
    #expect(notes.isEmpty == false)
    #expect(notes.allSatisfy { $0.checklistSummary.hasOpenItems })
}

@Test func smartOverviewCanBeRenamedAndDeleted() async throws {
    let store = LibraryStore.sample()
    let smartOverview = store.addSmartOverview(name: "旧名称", query: "has:tasks")

    store.renameSmartOverview(smartOverview.id, name: "新名称", query: "is:starred")
    let renamed = try #require(store.smartOverview(withID: smartOverview.id))

    #expect(renamed.name == "新名称")
    #expect(renamed.query == "is:starred")

    store.deleteSmartOverview(smartOverview.id)

    #expect(store.smartOverview(withID: smartOverview.id) == nil)
    #expect(store.selectedSmartOverviewID == nil)
    #expect(store.selectedOverview == .all)
}

@Test func categoryAndProjectCanBeCreatedAndRenamed() async throws {
    let store = LibraryStore()
    let category = store.addCategory(name: "客户")
    let project = store.addProject(name: "会议记录", categoryID: category.id)

    store.renameCategory(category.id, name: "客户项目")
    store.renameProject(project.id, name: "周会记录")

    #expect(store.category(withID: category.id)?.name == "客户项目")
    #expect(store.project(withID: project.id)?.name == "周会记录")
    #expect(store.projects(in: category.id).map(\.id) == [project.id])
}

@Test func deletingProjectAlsoDeletesItsNotes() async throws {
    let store = LibraryStore()
    let category = store.addCategory(name: "工作")
    let project = store.addProject(name: "项目", categoryID: category.id)
    let note = store.addNote(title: "要被删除")

    #expect(note.projectID == project.id)

    store.deleteProject(project.id)

    #expect(store.project(withID: project.id) == nil)
    #expect(store.filteredNotes().contains { $0.id == note.id } == false)
}

@Test func noteTemplatesCreateStructuredNotes() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let note = store.addNote(template: .meeting)

    #expect(note.title == "会议纪要")
    #expect(note.tags == ["会议"])
    #expect(note.bodyPlainText.contains("议题"))
}

@Test func notesCanBeDuplicatedStarredScheduledAndDeleted() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let note = store.addNote(title: "原始笔记", date: nil)

    store.setStarred(true, noteID: note.id)
    store.setCollapsed(true, noteID: note.id)
    store.scheduleToday(noteID: note.id, now: now)
    let copy = try #require(store.duplicateNote(note.id))

    #expect(copy.title == "原始笔记 副本")
    #expect(copy.isStarred)
    #expect(copy.isCollapsed)
    #expect(copy.scheduledDate == Calendar.current.startOfDay(for: now))

    store.deleteNote(copy.id)
    store.selectOverview(.all)
    #expect(store.filteredNotes().contains { $0.id == copy.id } == false)
}

@Test func deletingCategoryAlsoDeletesContainedProjectsAndNotes() async throws {
    let store = LibraryStore()
    let category = store.addCategory(name: "工作")
    let project = store.addProject(name: "项目", categoryID: category.id)
    let note = store.addNote(title: "要被删除")

    store.deleteCategory(category.id)

    #expect(store.category(withID: category.id) == nil)
    #expect(store.project(withID: project.id) == nil)
    #expect(store.filteredNotes().contains { $0.id == note.id } == false)
}
