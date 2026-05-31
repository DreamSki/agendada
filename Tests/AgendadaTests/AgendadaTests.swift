import Foundation
import Testing
@testable import Agendada
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

@MainActor
@Test func existingUnreadableLibraryIsNotOverwrittenWithSampleData() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "AgendadaTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let libraryURL = temporaryDirectory.appending(path: "Library.json")
    let originalData = Data("this is not valid library json".utf8)
    try originalData.write(to: libraryURL)

    let repository = FileLibraryRepository(fileURL: libraryURL)
    let observableStore = ObservableLibraryStore.load(repository: repository)

    observableStore.addNote()

    let storedData = try Data(contentsOf: libraryURL)
    #expect(storedData == originalData)
}

@Test func savingLibraryCreatesPreviousBackupBeforeReplacingExistingFile() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "AgendadaTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let libraryURL = temporaryDirectory.appending(path: "Library.json")
    let repository = FileLibraryRepository(fileURL: libraryURL)
    let firstSnapshot = LibraryStore.sample().snapshot()
    try repository.save(firstSnapshot)

    let secondStore = LibraryStore(snapshot: firstSnapshot)
    secondStore.searchText = "changed"
    try repository.save(secondStore.snapshot())

    let backupURL = temporaryDirectory.appending(path: "Library.previous.json")
    let backupData = try Data(contentsOf: backupURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let backupSnapshot = try decoder.decode(LibrarySnapshot.self, from: backupData)

    #expect(backupSnapshot.searchText == firstSnapshot.searchText)
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

// MARK: - Batch Selection Tests

@Test func batchSelectAllAndDeselect() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)

    store.selectAllFilteredNotes()
    #expect(store.batchSelectedNoteIDs.isEmpty == false)
    #expect(store.batchSelectedNoteIDs.count == store.filteredNotes().count)

    store.deselectAllNotes()
    #expect(store.batchSelectedNoteIDs.isEmpty)
}

@Test func batchInvertSelection() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)
    let allIDs = Set(store.filteredNotes().map(\.id))

    // Start with empty selection, invert should select all
    store.invertBatchSelection()
    #expect(store.batchSelectedNoteIDs == allIDs)

    // Invert again should deselect all
    store.invertBatchSelection()
    #expect(store.batchSelectedNoteIDs.isEmpty)
}

@Test func batchDeleteMovesNotesToTrash() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)
    let notes = store.filteredNotes()
    let ids = Set(notes.prefix(2).map(\.id))

    store.batchDeleteNotes(ids)

    // Batch selection cleared
    #expect(store.batchSelectedNoteIDs.isEmpty)

    // Notes are now trashed
    for id in ids {
        let note = store.note(withID: id)
        #expect(note?.status == .trashed)
    }

    // Not visible in normal view
    #expect(store.filteredNotes().contains { ids.contains($0.id) } == false)
}

@Test func batchRestoreNotesFromTrash() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)

    // First batch delete some notes
    let notes = store.filteredNotes()
    let ids = Set(notes.prefix(2).map(\.id))
    store.batchDeleteNotes(ids)

    // Now restore them
    store.batchRestoreNotes(ids)

    // Batch selection cleared
    #expect(store.batchSelectedNoteIDs.isEmpty)

    // Notes are back to open
    for id in ids {
        let note = store.note(withID: id)
        #expect(note?.status == .open)
    }
}

@Test func batchPermanentlyDeleteNotesRemovesThem() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)

    // First batch delete to trash
    let notes = store.filteredNotes()
    let ids = Set(notes.prefix(1).map(\.id))
    store.batchDeleteNotes(ids)

    // Then permanently delete
    store.batchPermanentlyDeleteNotes(ids)

    #expect(store.batchSelectedNoteIDs.isEmpty)
    for id in ids {
        #expect(store.note(withID: id) == nil)
    }
}

@Test func batchMoveNotesToProject() async throws {
    let store = LibraryStore()
    let category = store.addCategory(name: "工作")
    let sourceProject = store.addProject(name: "源项目", categoryID: category.id)
    let targetProject = store.addProject(name: "目标项目", categoryID: category.id)

    _ = store.addProject(name: "源项目") // re-select source since addProject navigates
    store.selectProject(sourceProject.id)

    let note1 = store.addNote(title: "笔记1")
    let note2 = store.addNote(title: "笔记2")

    let ids: Set<Note.ID> = [note1.id, note2.id]
    store.moveNotes(ids, toProject: targetProject.id)

    #expect(store.batchSelectedNoteIDs.isEmpty)
    #expect(store.note(withID: note1.id)?.projectID == targetProject.id)
    #expect(store.note(withID: note2.id)?.projectID == targetProject.id)
}

@Test func batchSelectionClearsOnNavigation() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)
    store.selectAllFilteredNotes()
    #expect(store.batchSelectedNoteIDs.isEmpty == false)

    // Switching overview should clear batch selection
    store.selectOverview(.today)
    #expect(store.batchSelectedNoteIDs.isEmpty)
}

@Test func batchSelectionNotPersistedInSnapshot() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)
    store.selectAllFilteredNotes()
    #expect(store.batchSelectedNoteIDs.isEmpty == false)

    let snapshot = store.snapshot()
    // Snapshot does not include batch selection — verified by round-trip
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(snapshot)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(LibrarySnapshot.self, from: data)

    // The decoded store should have no batch selection
    let restored = LibraryStore(snapshot: decoded)
    #expect(restored.batchSelectedNoteIDs.isEmpty)
}

@Test func togglingBatchSelectionEntersBatchMode() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)

    guard let firstNote = store.filteredNotes().first else {
        #expect(Bool(false), "Expected at least one note")
        return
    }

    // Toggle a note into batch selection
    store.toggleBatchSelection(noteID: firstNote.id)
    #expect(store.batchSelectedNoteIDs.contains(firstNote.id))

    // Toggle it off
    store.toggleBatchSelection(noteID: firstNote.id)
    #expect(store.batchSelectedNoteIDs.contains(firstNote.id) == false)
}

@Test func batchSelectionClearsSelectedNoteID() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)

    // First select a note normally
    guard let firstNote = store.filteredNotes().first else {
        #expect(Bool(false), "Expected at least one note")
        return
    }
    store.selectNote(firstNote.id)
    #expect(store.selectedNoteID == firstNote.id)

    // Enter batch mode — should clear selectedNoteID
    store.toggleBatchSelection(noteID: firstNote.id)
    #expect(store.selectedNoteID == nil)
    #expect(store.batchSelectedNoteIDs.contains(firstNote.id))
}
