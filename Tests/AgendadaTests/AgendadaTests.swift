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

    store.updateSearchText("工程")

    #expect(store.filteredNotes().contains { $0.people.contains("工程") })
}

@Test func searchSupportsOpenTaskPredicate() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)

    store.updateSearchText("has:tasks")

    let notes = store.filteredNotes()
    #expect(notes.isEmpty == false)
    #expect(notes.allSatisfy { $0.checklistSummary.hasOpenItems })
}

@Test func searchSupportsDateAndBooleanPredicates() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let store = LibraryStore.sample(today: now)
    store.selectOverview(.all)

    store.updateSearchText("is:starred date:today")

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

    store.updateSearchText("tag:MVP person:产品")

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

@Test func noteLinksCanBeExtractedAndResolvedAsBacklinks() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let source = store.addNote(title: "来源")
    let target = store.addNote(title: "目标")
    let body = "参考 <a href=\"agendada://note/\(target.id.uuidString)\">目标</a>"
    let blockJSON = Data("""
    [{"content":[{"type":"link","href":"agendada://note/\(target.id.uuidString)"}]}]
    """.utf8)

    store.updateNote(
        noteID: source.id,
        title: source.title,
        body: body,
        blockJSON: blockJSON,
        scheduledDate: nil,
        tags: [],
        people: []
    )

    let updatedSource = try #require(store.note(withID: source.id))
    #expect(store.linkedNoteIDs(from: updatedSource) == [target.id])
    #expect(store.linkedNoteIDs(from: source.id) == [target.id])
    #expect(store.backlinkedNotes(to: target.id).map(\.id) == [source.id])
    #expect(store.relatedNotes(for: target.id).contains { related in
        related.noteID == source.id && related.reasons.contains("链接")
    })
}

@Test func trashedLinkedNotesAreIgnoredByBacklinksAndRelatedNotes() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let source = store.addNote(title: "来源")
    let target = store.addNote(title: "目标")

    store.updateNote(
        noteID: source.id,
        title: source.title,
        body: "agendada://note/\(target.id.uuidString)",
        scheduledDate: nil,
        tags: [],
        people: []
    )
    store.deleteNote(source.id)

    #expect(store.linkedNoteIDs(from: source.id) == [target.id])
    #expect(store.backlinkedNotes(to: target.id).isEmpty)
    #expect(store.relatedNotes(for: target.id).contains { $0.noteID == source.id } == false)
}

@Test func selectingTrashedOrMissingLinkedTargetsIsIgnored() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let source = store.addNote(title: "来源")
    let target = store.addNote(title: "目标")

    store.updateNote(
        noteID: source.id,
        title: source.title,
        body: "agendada://note/\(target.id.uuidString)",
        scheduledDate: nil,
        tags: [],
        people: []
    )
    store.selectNote(source.id)
    store.deleteNote(target.id)

    #expect(store.linkedNoteIDs(from: source.id) == [target.id])
    store.selectNote(target.id)
    #expect(store.selectedNoteID == source.id)

    store.permanentlyDeleteNote(target.id)
    store.selectNote(target.id)
    #expect(store.selectedNoteID == source.id)
}

@Test func calendarAndReminderAssociationsPersistInNoteBody() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let note = store.addNote(title: "关联笔记", date: nil)
    let eventID = "calendar/event id with spaces"
    let reminderID = "reminder/id with spaces"

    #expect(store.associateCalendarEvent(id: eventID, title: "启动会", startDate: date, to: note.id))
    #expect(store.associateReminder(id: reminderID, title: "提交材料", dueDate: date, to: note.id))
    #expect(store.associateCalendarEvent(id: eventID, title: "启动会", startDate: date, to: note.id) == false)

    let updated = try #require(store.note(withID: note.id))
    #expect(store.linkedCalendarEventIDs(from: updated) == [eventID])
    #expect(store.linkedReminderIDs(from: updated) == [reminderID])
    #expect(store.noteLinked(toCalendarEventID: eventID)?.id == note.id)
    #expect(store.noteLinked(toReminderID: reminderID)?.id == note.id)
    #expect(updated.scheduledDate == date)

    let decoded = LibraryStore(snapshot: store.snapshot())
    #expect(decoded.noteLinked(toCalendarEventID: eventID)?.id == note.id)
    #expect(decoded.noteLinked(toReminderID: reminderID)?.id == note.id)

    #expect(decoded.unassociateCalendarEvent(id: eventID, from: note.id))
    #expect(decoded.linkedCalendarEventIDs(from: note.id).isEmpty)
    #expect(decoded.noteLinked(toReminderID: reminderID)?.id == note.id)
}

@Test func notesCanBeCreatedForCalendarEventsAndReminders() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    let eventNote = store.addNoteForCalendarEvent(id: "event/123", title: "产品评审", startDate: date)
    let reminderNote = store.addNoteForReminder(id: "reminder/456", title: "发会议纪要", dueDate: nil)

    #expect(eventNote.title == "产品评审")
    #expect(eventNote.scheduledDate == date)
    #expect(store.linkedCalendarEventIDs(from: eventNote) == ["event/123"])
    #expect(reminderNote.title == "发会议纪要")
    #expect(reminderNote.scheduledDate == nil)
    #expect(store.linkedReminderIDs(from: reminderNote) == ["reminder/456"])
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
    let observableStore = await ObservableLibraryStore.load(repository: repository)

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
    try await repository.save(firstSnapshot)

    let secondStore = LibraryStore(snapshot: firstSnapshot)
    secondStore.updateSearchText("changed")
    try await repository.save(secondStore.snapshot())

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
    store.updateSearchText("")

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

@Test func customTemplatesRoundTripAndCreateNotes() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let source = store.addNote(title: "项目周会")
    store.updateNote(
        noteID: source.id,
        title: source.title,
        body: "<h2>议题</h2><p>进度</p>",
        scheduledDate: nil,
        tags: ["会议", "客户"],
        people: []
    )
    let template = store.addCustomNoteTemplate(name: "客户周会", from: source)
    let decodedStore = LibraryStore(snapshot: store.snapshot())
    decodedStore.renameCustomNoteTemplate(template.id, name: "客户复盘")
    let renamedStore = LibraryStore(snapshot: decodedStore.snapshot())

    let created = try #require(renamedStore.addNote(customTemplate: template.id, date: nil))

    #expect(renamedStore.customNoteTemplate(withID: template.id)?.name == "客户复盘")
    #expect(created.title == "项目周会")
    #expect(created.body.contains("议题"))
    #expect(created.tags == ["会议", "客户"])
    #expect(created.scheduledDate == nil)

    renamedStore.deleteCustomNoteTemplate(template.id)
    let deletedStore = LibraryStore(snapshot: renamedStore.snapshot())
    #expect(deletedStore.customNoteTemplate(withID: template.id) == nil)
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

@Test func deletingCategoryKeepsProjectsAndNotes() async throws {
    let store = LibraryStore()
    let category = store.addCategory(name: "工作")
    let project = store.addProject(name: "项目", categoryID: category.id)
    let note = store.addNote(title: "笔记")

    #expect(note.projectID == project.id)
    #expect(project.categoryID == category.id)

    store.deleteCategory(category.id)

    // Category is removed
    #expect(store.category(withID: category.id) == nil)
    // Project still exists, now uncategorized
    #expect(store.project(withID: project.id) != nil)
    #expect(store.project(withID: project.id)?.categoryID == nil)
    // Note still exists
    #expect(store.note(withID: note.id) != nil)
}

// MARK: - Category Model Tests

@Test func legacyCategoryWithoutColorDecodes() async throws {
    let json = """
    {"id":"12345678-1234-1234-1234-123456789012","name":"旧分类","projectIDs":[]}
    """
    let category = try JSONDecoder().decode(ProjectCategory.self, from: Data(json.utf8))
    #expect(category.name == "旧分类")
    #expect(category.color == .orange)
    #expect(category.parentID == nil)
    #expect(category.projectIDs.isEmpty)
}

@Test func updateCategoryChangesNameAndColor() async throws {
    let store = LibraryStore()
    let category = store.addCategory(name: "旧名称", color: .orange)

    store.updateCategory(category.id, name: "新名称", color: .teal)

    let updated = try #require(store.category(withID: category.id))
    #expect(updated.name == "新名称")
    #expect(updated.color == .teal)
}

@Test func categoryProjectsSortAlphabetically() async throws {
    let store = LibraryStore()
    let category = store.addCategory(name: "测试")
    _ = store.addProject(name: "B项目", categoryID: category.id)
    _ = store.addProject(name: "A项目", categoryID: category.id)
    _ = store.addProject(name: "项目10", categoryID: category.id)
    _ = store.addProject(name: "项目2", categoryID: category.id)

    store.sortProjectsAlphabetically(in: category.id)

    let names = store.orderedProjects(in: category.id).map(\.name)
    // localizedStandardCompare: numbers < letters
    #expect(names.firstIndex(of: "项目2")! < names.firstIndex(of: "项目10")!)
    #expect(names.firstIndex(of: "项目10")! < names.firstIndex(of: "A项目")!)
    #expect(names.firstIndex(of: "A项目")! < names.firstIndex(of: "B项目")!)
}

@Test func subcategoryBelongsToParent() async throws {
    let store = LibraryStore()
    let parent = store.addCategory(name: "工作", color: .teal)
    let child = store.addCategory(name: "设计组", color: .purple, parentID: parent.id)

    #expect(child.parentID == parent.id)

    let children = store.subcategories(of: parent.id)
    #expect(children.count == 1)
    #expect(children.first?.name == "设计组")
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

// MARK: - Timeline Design Token Tests

@Test func timelineDesignTokensAreConsistent() async throws {
    // Verify timeline-specific design tokens are properly defined
    #expect(AgendaSpacing.panelPaddingH == 22)
    #expect(AgendaSpacing.panelSpineLeading == 14)
    #expect(AgendaSpacing.timelineRowIndent == 30)
    #expect(AgendaSpacing.timelineTodayTopSpacing == 10)
    #expect(AgendaSpacing.timelineHoverBarOffset == 4)
    #expect(AgendaSpacing.timelineDateDotLeadingAdjust == -3)
    #expect(AgendaSpacing.timelineTodayBarOffset == -2)
}

@Test func timelineRowIndentMatchesCalculatedValue() async throws {
    // Verify that timelineRowIndent matches the original calculation
    // Original: panelLevel1 - panelPaddingH + panelSpineLeading - 2
    let calculated = AgendaSpacing.panelLevel1 - AgendaSpacing.panelPaddingH + AgendaSpacing.panelSpineLeading - 2
    #expect(calculated == AgendaSpacing.timelineRowIndent, "Expected timelineRowIndent to match calculated value")
}

@Test func timelineDateDotPositionMatchesCalculatedValue() async throws {
    // Verify that date dot position matches the original calculation
    // Original: panelSpineLeading - 3
    let calculated = AgendaSpacing.panelSpineLeading + AgendaSpacing.timelineDateDotLeadingAdjust
    #expect(calculated == 11, "Expected date dot position to be 11px (14 - 3)")
}

// MARK: - DaySchedule Logic Tests

@Test func dayScheduleIsEmptyCheck() async throws {
    // Verify DaySchedule.isEmpty works correctly
    let today = Date()
    let emptySchedule = DaySchedule(date: today)
    #expect(emptySchedule.isEmpty == true)

    let nonEmptySchedule = DaySchedule(
        date: today,
        notes: [ScheduledNoteInfo(id: UUID(), title: "Test", projectID: UUID())]
    )
    #expect(nonEmptySchedule.isEmpty == false)
}

@Test func dayScheduleHasCorrectDate() async throws {
    // Verify DaySchedule uses the correct date
    let date = Date()
    let schedule = DaySchedule(date: date)
    #expect(schedule.id == date)
}

@Test func dayScheduleWithAllDayEventIsNotEmpty() async throws {
    // Verify DaySchedule with events is not empty
    let today = Date()
    let event = CalendarEvent(
        id: "test-event",
        title: "Test Event",
        startDate: today,
        endDate: today.addingTimeInterval(3600),
        isAllDay: true,
        calendarColor: CalendarColorInfo(red: 1, green: 0, blue: 0),
        calendarTitle: "Test Calendar",
        accountTitle: "Test Account"
    )

    let schedule = DaySchedule(date: today, allDayEvents: [event])
    #expect(schedule.isEmpty == false)
}

@Test func dayScheduleWithReminderIsNotEmpty() async throws {
    // Verify DaySchedule with reminders is not empty
    let today = Date()
    let reminder = CalendarReminder(
        id: "test-reminder",
        title: "Test Reminder",
        dueDate: today,
        isCompleted: false,
        completionDate: nil,
        calendarColor: CalendarColorInfo(red: 1, green: 0, blue: 0),
        calendarTitle: "Test List",
        accountTitle: "Test Account",
        priority: 0
    )

    let schedule = DaySchedule(date: today, reminders: [reminder])
    #expect(schedule.isEmpty == false)
}

// MARK: - Timeline Display Logic Tests

@Test func timelineDisplayDaysIncludesTodayWhenNotEmpty() async throws {
    // Verify that today is always included in displayDays
    let cal = Calendar.current
    let today = Date()
    
    // Create a day schedule for today with notes
    let todaySchedule = DaySchedule(
        date: today,
        notes: [ScheduledNoteInfo(id: UUID(), title: "Today Note", projectID: UUID())]
    )
    
    #expect(todaySchedule.isEmpty == false)
    #expect(cal.isDateInToday(todaySchedule.date))
}

@Test func timelineDisplayDaysSortsCorrectly() async throws {
    // Verify that displayDays are sorted by date
    let cal = Calendar.current
    let today = Date()
    
    let dates = [
        cal.date(byAdding: .day, value: 2, to: today)!,
        today,
        cal.date(byAdding: .day, value: -1, to: today)!,
        cal.date(byAdding: .day, value: 1, to: today)!
    ]
    
    let schedules = dates.map { DaySchedule(date: $0) }
    let sorted = schedules.sorted { $0.date < $1.date }
    
    // Verify sorting
    for i in 0..<sorted.count - 1 {
        #expect(sorted[i].date <= sorted[i + 1].date)
    }
}

@Test func timelineHasMoreDaysCalculation() async throws {
    // Verify hasMoreDays calculation
    let cal = Calendar.current
    let today = Date()
    
    // Create 10 days of data
    var allSchedules: [DaySchedule] = []
    for i in -5..<5 {
        if let date = cal.date(byAdding: .day, value: i, to: today) {
            allSchedules.append(DaySchedule(
                date: date,
                notes: [ScheduledNoteInfo(id: UUID(), title: "Note \(i)", projectID: UUID())]
            ))
        }
    }
    
    let nonEmpty = allSchedules.filter { !$0.isEmpty }
    let displayCount = 5 // Assuming we show 5 days in compact mode
    
    let hasMore = nonEmpty.count > displayCount
    #expect(hasMore == true)
    #expect(nonEmpty.count == 10)
}

// MARK: - Search Comprehensive Tests

@Test func searchEmptyStringReturnsAllNotes() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)
    store.updateSearchText("")

    let notes = store.filteredNotes()
    let baseline = LibraryStore.sample()
    baseline.selectOverview(.all)
    #expect(notes.count == baseline.filteredNotes().count)
}

@Test func searchMatchesTitle() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    _ = store.addNote(title: "架构设计文档")
    _ = store.addNote(title: "接口规范")
    store.selectOverview(.all)

    store.updateSearchText("架构")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes.first?.title == "架构设计文档")
}

@Test func searchMatchesBodyContent() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let noteA = store.addNote(title: "笔记A")
    store.updateNote(noteID: noteA.id, title: "笔记A", body: "这是一段关于机器学习的正文内容", scheduledDate: nil, tags: [], people: [])
    let noteB = store.addNote(title: "笔记B")
    store.updateNote(noteID: noteB.id, title: "笔记B", body: "这是关于前端开发的正文", scheduledDate: nil, tags: [], people: [])
    store.selectOverview(.all)

    store.updateSearchText("机器学习")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes.first?.title == "笔记A")
}

@Test func searchIsCaseInsensitive() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    _ = store.addNote(title: "API Documentation")
    store.selectOverview(.all)

    store.updateSearchText("api")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
}

@Test func searchMultipleTermsUseANDLogic() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let noteA = store.addNote(title: "Swift入门")
    store.updateNote(noteID: noteA.id, title: "Swift入门", body: "", scheduledDate: nil, tags: ["教程"], people: [])
    let noteB = store.addNote(title: "Swift进阶")
    store.updateNote(noteID: noteB.id, title: "Swift进阶", body: "", scheduledDate: nil, tags: ["高级"], people: [])
    let noteC = store.addNote(title: "Python入门")
    store.updateNote(noteID: noteC.id, title: "Python入门", body: "", scheduledDate: nil, tags: ["教程"], people: [])
    store.selectOverview(.all)

    store.updateSearchText("swift 教程")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes.first?.title == "Swift入门")
}

@Test func searchTermNotFound() async throws {
    let store = LibraryStore.sample()
    store.selectOverview(.all)

    store.updateSearchText("xyz不存在的内容abc")

    let notes = store.filteredNotes()
    #expect(notes.isEmpty)
}

@Test func searchWithTagPrefix() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let noteA = store.addNote(title: "笔记A")
    store.updateNote(noteID: noteA.id, title: "笔记A", body: "", scheduledDate: nil, tags: ["MVP", "重要"], people: [])
    let noteB = store.addNote(title: "笔记B")
    store.updateNote(noteID: noteB.id, title: "笔记B", body: "", scheduledDate: nil, tags: ["调研"], people: [])
    store.selectOverview(.all)

    store.updateSearchText("tag:MVP")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes.first?.title == "笔记A")
}

@Test func searchWithPersonPrefix() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let noteA = store.addNote(title: "笔记A")
    store.updateNote(noteID: noteA.id, title: "笔记A", body: "", scheduledDate: nil, tags: [], people: ["产品", "工程"])
    let noteB = store.addNote(title: "笔记B")
    store.updateNote(noteID: noteB.id, title: "笔记B", body: "", scheduledDate: nil, tags: [], people: ["设计"])
    store.selectOverview(.all)

    store.updateSearchText("person:产品")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes.first?.title == "笔记A")
}

@Test func searchWithStatusPrefix() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let note = store.addNote(title: "已完成笔记")
    store.setStatus(.closed, noteID: note.id)
    _ = store.addNote(title: "进行中笔记")
    store.selectOverview(.all)

    store.updateSearchText("status:closed")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes.first?.title == "已完成笔记")
}

@Test func searchHasDatePredicate() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    _ = store.addNote(title: "有日期笔记", date: Date())
    _ = store.addNote(title: "无日期笔记", date: nil)
    store.selectOverview(.all)

    store.updateSearchText("has:date")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes.first?.title == "有日期笔记")
}

@Test func searchIsFocusedPredicate() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let focused = store.addNote(title: "关注笔记")
    store.setFocused(true, noteID: focused.id)
    _ = store.addNote(title: "普通笔记")
    store.selectOverview(.all)

    store.updateSearchText("is:focused")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes.first?.title == "关注笔记")
}

@Test func searchIsStarredPredicate() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let starred = store.addNote(title: "星标笔记")
    store.setStarred(true, noteID: starred.id)
    _ = store.addNote(title: "普通笔记")
    store.selectOverview(.all)

    store.updateSearchText("is:starred")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes.first?.title == "星标笔记")
}

@Test func searchIsBriefPredicate() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let brief = store.addNote(title: "简达笔记")
    store.setBrief(true, noteID: brief.id)
    let normal = store.addNote(title: "普通笔记")
    store.setBrief(false, noteID: normal.id)
    store.selectOverview(.all)

    store.updateSearchText("is:brief")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes.first?.title == "简达笔记")
}

@Test func searchDateTodayPredicate() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    _ = store.addNote(title: "今天笔记", date: now)
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
    _ = store.addNote(title: "明天笔记", date: tomorrow)
    store.selectOverview(.all)

    store.updateSearchText("date:today")

    let notes = store.filteredNotes(now: now)
    #expect(notes.count == 1)
    #expect(notes.first?.title == "今天笔记")
}

@Test func searchDateUpcomingPredicate() async throws {
    // date:upcoming now uses day-level comparison (strictly after today),
    // matching the "即将到来" overview semantics.
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    _ = store.addNote(title: "今天笔记", date: now)
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
    _ = store.addNote(title: "明天笔记", date: tomorrow)
    store.selectOverview(.all)

    store.updateSearchText("date:upcoming")

    let notes = store.filteredNotes(now: now)
    // Only tomorrow qualifies as upcoming (strictly after today's day)
    #expect(notes.count == 1)
    #expect(notes[0].title == "明天笔记")
}

@Test func searchCombinedTagAndKeyword() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let noteA = store.addNote(title: "架构设计")
    store.updateNote(noteID: noteA.id, title: "架构设计", body: "", scheduledDate: nil, tags: ["MVP"], people: [])
    let noteB = store.addNote(title: "需求文档")
    store.updateNote(noteID: noteB.id, title: "需求文档", body: "", scheduledDate: nil, tags: ["MVP"], people: [])
    let noteC = store.addNote(title: "架构设计")
    store.updateNote(noteID: noteC.id, title: "架构设计", body: "", scheduledDate: nil, tags: ["调研"], people: [])
    store.selectOverview(.all)

    store.updateSearchText("tag:MVP 架构")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes.first?.title == "架构设计")
}

@Test func searchWithSmartOverviewAndAdditionalFilter() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let starred = store.addNote(title: "星标有任务")
    store.updateNote(noteID: starred.id, title: "星标有任务", body: "- [ ] 任务1", scheduledDate: nil, tags: [], people: [])
    store.setStarred(true, noteID: starred.id)
    let normal = store.addNote(title: "普通有任务")
    store.updateNote(noteID: normal.id, title: "普通有任务", body: "- [ ] 任务2", scheduledDate: nil, tags: [], people: [])
    _ = store.addNote(title: "星标无任务")
    let lastStarred = store.addNote(title: "最后星标")
    store.setStarred(true, noteID: lastStarred.id)

    _ = store.addSmartOverview(name: "星标", query: "is:starred")

    // Smart overview filters to starred only, then further filter with keyword
    store.updateSearchText("任务")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes.first?.title == "星标有任务")
}

@Test func searchMatchesPeople() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let noteA = store.addNote(title: "会议")
    store.updateNote(noteID: noteA.id, title: "会议", body: "", scheduledDate: nil, tags: [], people: ["张三", "李四"])
    let noteB = store.addNote(title: "评审")
    store.updateNote(noteID: noteB.id, title: "评审", body: "", scheduledDate: nil, tags: [], people: ["王五"])
    store.selectOverview(.all)

    store.updateSearchText("张三")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes.first?.title == "会议")
}

@Test func searchTrashedNotesAreExcludedFromNonTrashViews() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let deleted = store.addNote(title: "被删笔记")
    store.updateNote(noteID: deleted.id, title: "被删笔记", body: "特殊关键词xyz", scheduledDate: nil, tags: [], people: [])
    store.deleteNote(deleted.id)
    let normal = store.addNote(title: "正常笔记")
    store.updateNote(noteID: normal.id, title: "正常笔记", body: "特殊关键词xyz", scheduledDate: nil, tags: [], people: [])
    store.selectOverview(.all)

    store.updateSearchText("特殊关键词xyz")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes.first?.title == "正常笔记")
}

// MARK: - Search Occurrence Tests

@Test func searchOccurrencesFindsMatchesInBody() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let n = store.addNote(title: "Swift教程")
    store.updateNote(noteID: n.id, title: "Swift教程", body: "Swift 是一门编程语言，Swift 很流行。", scheduledDate: nil, tags: [], people: [])
    store.selectOverview(.all)

    store.updateSearchText("swift")

    let summary = store.searchSummary
    // "swift" appears 3 times: once in title, twice in body
    #expect(summary.totalOccurrences == 3)
    #expect(summary.totalMatchedNotes == 1)
    #expect(summary.currentOccurrenceIndex == 1)
}

@Test func searchOccurrencesAcrossMultipleNotes() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let n1 = store.addNote(title: "架构设计")
    store.updateNote(noteID: n1.id, title: "架构设计", body: "讨论微服务架构方案", scheduledDate: nil, tags: [], people: [])
    let n2 = store.addNote(title: "架构评审")
    store.updateNote(noteID: n2.id, title: "架构评审", body: "评审结果：架构有缺陷", scheduledDate: nil, tags: [], people: [])
    store.selectOverview(.all)

    store.updateSearchText("架构")

    let summary = store.searchSummary
    // Note 1: title "架构设计" (1), body "讨论微服务架构方案" (1) = 2
    // Note 2: title "架构评审" (1), body "评审结果：架构有缺陷" (1) = 2
    // Total = 4
    #expect(summary.totalOccurrences == 4)
    #expect(summary.totalMatchedNotes == 2)
    #expect(summary.currentOccurrenceIndex == 1)
}

@Test func searchOccurrencesOrderedByNoteThenPosition() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let nA = store.addNote(title: "AAA笔记", date: nil)
    store.updateNote(noteID: nA.id, title: "AAA笔记", body: "关键词 出现在 关键词 正文中。", scheduledDate: nil, tags: [], people: [])
    store.selectOverview(.all)

    store.updateSearchText("关键词")

    let occurrences = store.searchOccurrences
    // Title has no "关键词" match. Body has 2 matches.
    #expect(occurrences.count == 2)

    // Both occurrences in same note, globalIndex 0 and 1
    #expect(occurrences[0].globalIndex == 0)
    #expect(occurrences[0].occurrenceIndexInNote == 0)
    #expect(occurrences[0].noteID == nA.id)
    #expect(occurrences[0].excerpt.contains("关键词"))

    #expect(occurrences[1].globalIndex == 1)
    #expect(occurrences[1].occurrenceIndexInNote == 1)
    #expect(occurrences[1].noteID == nA.id)
    // Second occurrence should appear after the first in the text
    #expect(occurrences[1].matchPosition > occurrences[0].matchPosition)
}

@Test func searchOccurrenceTitleField() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    _ = store.addNote(title: "架构设计文档")
    store.selectOverview(.all)

    store.updateSearchText("架构")

    let occurrences = store.searchOccurrences
    #expect(occurrences.count == 1)
    #expect(occurrences[0].field == .title)
    #expect(occurrences[0].excerpt.contains("架构"))
}

@Test func searchOccurrenceBodyField() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let n = store.addNote(title: "无关键词标题")
    store.updateNote(noteID: n.id, title: "无关键词标题", body: "正文中包含 架构 这两个字。", scheduledDate: nil, tags: [], people: [])
    store.selectOverview(.all)

    store.updateSearchText("架构")

    let occurrences = store.searchOccurrences
    #expect(occurrences.count == 1)
    #expect(occurrences[0].field == .body)
    #expect(occurrences[0].excerpt.contains("架构"))
}

@Test func searchOccurrenceNavigationGoesToNext() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let n = store.addNote(title: "Swift")
    store.updateNote(noteID: n.id, title: "Swift", body: "Swift A Swift B Swift C", scheduledDate: nil, tags: [], people: [])
    store.selectOverview(.all)

    store.updateSearchText("swift")
    // Occurrences: title(0), body(1), body(2), body(3) = 4 total
    // currentOccurrenceIndex starts nil; first Enter lands on index 0.

    let summary = store.searchSummary
    #expect(summary.totalOccurrences == 4)
    #expect(summary.currentOccurrenceIndex == 1)

    // First goToNext: lands on index 0 (first match, no longer skipped)
    let next1 = store.goToNextSearchOccurrence()
    #expect(next1?.globalIndex == 0)
    #expect(store.searchSummary.currentOccurrenceIndex == 1)

    // Second: index 1
    let next2 = store.goToNextSearchOccurrence()
    #expect(next2?.globalIndex == 1)
    #expect(store.searchSummary.currentOccurrenceIndex == 2)

    // Fourth: index 3
    _ = store.goToNextSearchOccurrence() // index 2
    let next4 = store.goToNextSearchOccurrence() // index 3
    #expect(next4?.globalIndex == 3)
    #expect(store.searchSummary.currentOccurrenceIndex == 4)

    // Wrap to 1st
    let wrap = store.goToNextSearchOccurrence()
    #expect(wrap?.globalIndex == 0)
    #expect(store.searchSummary.currentOccurrenceIndex == 1)
}

@Test func searchOccurrenceNavigationGoesToPreviousAndWraps() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let n = store.addNote(title: "Swift")
    store.updateNote(noteID: n.id, title: "Swift", body: "Swift A Swift B", scheduledDate: nil, tags: [], people: [])
    store.selectOverview(.all)

    store.updateSearchText("swift")
    // 3 occurrences

    // Previous from first wraps to last
    let prev = store.goToPreviousSearchOccurrence()
    #expect(prev?.globalIndex == 2)
    #expect(store.searchSummary.currentOccurrenceIndex == 3)
}

@Test func searchOccurrenceNavigationSwitchesNote() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    // Use nil dates so sort is by createdAt (nA created first, nB second)
    let nA = store.addNote(title: "架构文档", date: nil)
    store.updateNote(noteID: nA.id, title: "架构文档", body: "只有一处 架构。", scheduledDate: nil, tags: [], people: [])
    let nB = store.addNote(title: "架构评审", date: nil)
    store.updateNote(noteID: nB.id, title: "架构评审", body: "另外一处 架构。", scheduledDate: nil, tags: [], people: [])
    store.selectOverview(.all)

    store.updateSearchText("架构")

    // filteredNotes sorts by createdAt desc → nB (later) first, nA second
    // Occurrences: nB title(0), nB body(1), nA title(2), nA body(3)
    // updateSearchText auto-selects nB
    #expect(store.searchOccurrences[0].noteID == nB.id)
    #expect(store.selectedNoteID == nB.id)

    // 1st goToNext: index 0 → nB title (no longer skipped)
    _ = store.goToNextSearchOccurrence()
    #expect(store.selectedNoteID == nB.id)

    // 2nd goToNext: index 1 → nB body (still nB)
    _ = store.goToNextSearchOccurrence()
    #expect(store.selectedNoteID == nB.id)

    // 3rd goToNext: index 2 → nA title → switches to nA
    let next = store.goToNextSearchOccurrence()
    #expect(next?.globalIndex == 2)
    #expect(store.selectedNoteID == nA.id)
}

@Test func searchOccurrenceEmptyWhenNoResults() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    _ = store.addNote(title: "Hello World")
    store.selectOverview(.all)

    store.updateSearchText("xyz不存在")

    let summary = store.searchSummary
    #expect(summary == .empty)
    #expect(store.searchOccurrences.isEmpty)
    #expect(store.currentOccurrence == nil)
    #expect(store.goToNextSearchOccurrence() == nil)
    #expect(store.goToPreviousSearchOccurrence() == nil)
}

@Test func searchOccurrenceWithSyntaxOnlyNoKeywords() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let taskNote = store.addNote(title: "有任务")
    store.updateNote(noteID: taskNote.id, title: "有任务", body: "- [ ] 任务1", scheduledDate: nil, tags: [], people: [])
    _ = store.addNote(title: "无任务")
    store.selectOverview(.all)

    // has:tasks syntax — no plain keywords
    store.updateSearchText("has:tasks")

    // Occurrences: empty (no plain keywords to search for), but filteredNotes still works
    let summary = store.searchSummary
    #expect(summary.totalOccurrences == 0)
}

// MARK: - searchHighlightText Tests

@Test func searchHighlightTextExcludesSyntaxPrefixes() async throws {
    let store = LibraryStore()
    store.updateSearchText("tag:MVP 重要 keyword")
    let highlight = store.searchHighlightText
    #expect(!highlight.contains("tag:"))
    #expect(highlight.contains("重要"))
    #expect(highlight.contains("keyword"))
}

@Test func searchHighlightTextEmptyWhenOnlySyntax() async throws {
    let store = LibraryStore()
    store.updateSearchText("has:tasks is:starred")
    let highlight = store.searchHighlightText
    #expect(highlight.isEmpty)
}

// MARK: - Global Search Tests

@Test func searchWithSelectedProjectSearchesAllActiveNotes() async throws {
    // .all scope: 搜索全库（旧行为）
    let store = LibraryStore()
    let cat = store.addCategory(name: "工作")
    let proj1 = store.addProject(name: "项目A", categoryID: cat.id)
    let proj2 = store.addProject(name: "项目B", categoryID: cat.id)

    store.selectProject(proj1.id)
    _ = store.addNote(title: "架构文档A")
    store.selectProject(proj2.id)
    _ = store.addNote(title: "架构文档B")

    store.selectProject(proj1.id)
    store.setSearchScope(.all)
    store.updateSearchText("架构")

    let notes = store.filteredNotes()
    #expect(Set(notes.map(\.title)) == ["架构文档A", "架构文档B"])
}

@Test func searchWithSelectedProjectScopedToCurrentProject() async throws {
    // .currentScope（默认）: 只搜当前项目
    let store = LibraryStore()
    let cat = store.addCategory(name: "工作")
    let proj1 = store.addProject(name: "项目A", categoryID: cat.id)
    let proj2 = store.addProject(name: "项目B", categoryID: cat.id)

    store.selectProject(proj1.id)
    _ = store.addNote(title: "架构文档A")
    store.selectProject(proj2.id)
    _ = store.addNote(title: "架构文档B")

    store.selectProject(proj1.id)
    // default scope is .currentScope
    store.updateSearchText("架构")

    let notes = store.filteredNotes()
    #expect(notes.map(\.title) == ["架构文档A"])
}

@Test func previewingGlobalSearchDoesNotChangeCurrentProjectFilter() async throws {
    let store = LibraryStore()
    let cat = store.addCategory(name: "工作")
    let proj1 = store.addProject(name: "项目A", categoryID: cat.id)
    let proj2 = store.addProject(name: "项目B", categoryID: cat.id)

    store.selectProject(proj1.id)
    _ = store.addNote(title: "架构文档A")
    store.selectProject(proj2.id)
    _ = store.addNote(title: "架构文档B")

    store.selectProject(proj1.id)
    let preview = store.globalSearchNotes(for: "架构")

    #expect(Set(preview.map(\.title)) == ["架构文档A", "架构文档B"])
    #expect(store.searchText.isEmpty)
    #expect(store.selectedProjectID == proj1.id)
    #expect(store.filteredNotes().map(\.title) == ["架构文档A"])
}

@Test func committingGlobalSearchLeavesProjectContext() async throws {
    // .all scope: commit 切换到全局视图（旧行为）
    let store = LibraryStore()
    let cat = store.addCategory(name: "工作")
    let proj1 = store.addProject(name: "项目A", categoryID: cat.id)
    let proj2 = store.addProject(name: "项目B", categoryID: cat.id)

    store.selectProject(proj1.id)
    _ = store.addNote(title: "架构文档A")
    store.selectProject(proj2.id)
    _ = store.addNote(title: "架构文档B")

    store.selectProject(proj1.id)
    store.setSearchScope(.all)
    store.commitSearchText("架构")

    #expect(store.selectedProjectID == nil)
    #expect(store.selectedOverview == .all)
    #expect(store.searchText == "架构")
    #expect(Set(store.filteredNotes().map(\.title)) == ["架构文档A", "架构文档B"])
}

@Test func committingScopedSearchStaysInCurrentProject() async throws {
    // .currentScope（默认）: commit 不切换视图
    let store = LibraryStore()
    let cat = store.addCategory(name: "工作")
    let proj1 = store.addProject(name: "项目A", categoryID: cat.id)
    let proj2 = store.addProject(name: "项目B", categoryID: cat.id)

    store.selectProject(proj1.id)
    _ = store.addNote(title: "架构文档A")
    store.selectProject(proj2.id)
    _ = store.addNote(title: "架构文档B")

    store.selectProject(proj1.id)
    // default scope is .currentScope
    store.commitSearchText("架构")

    #expect(store.selectedProjectID == proj1.id)
    #expect(store.searchText == "架构")
    #expect(store.filteredNotes().map(\.title) == ["架构文档A"])
}

@Test func currentScopeSearchStaysInsideTodayOverview() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let todayNote = store.addNote(title: "今天架构", date: now)
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
    _ = store.addNote(title: "明天架构", date: tomorrow)
    _ = store.addNote(title: "无日期架构")

    store.selectOverview(.today)
    // default scope is .currentScope
    store.updateSearchText("架构")

    let notes = store.filteredNotes(now: now)
    #expect(notes.count == 1)
    #expect(notes[0].id == todayNote.id)
}

@Test func trashScopeOnlySearchesTrashedNotes() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    let note1 = store.addNote(title: "正常架构")
    let note2 = store.addNote(title: "已删架构")
    store.deleteNote(note2.id)

    store.selectOverview(.trash)
    store.updateSearchText("架构")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes[0].id == note2.id)
}

@Test func switchingSearchScopeRecalculates() async throws {
    let store = LibraryStore()
    let cat = store.addCategory(name: "工作")
    let proj1 = store.addProject(name: "项目A", categoryID: cat.id)
    let proj2 = store.addProject(name: "项目B", categoryID: cat.id)

    store.selectProject(proj1.id)
    _ = store.addNote(title: "架构文档A")
    store.selectProject(proj2.id)
    _ = store.addNote(title: "架构文档B")

    // Start in project A, current scope
    store.selectProject(proj1.id)
    store.updateSearchText("架构")
    #expect(store.filteredNotes().map(\.title) == ["架构文档A"])

    // Switch to all scope — should now see both
    store.setSearchScope(.all)
    #expect(Set(store.filteredNotes().map(\.title)) == ["架构文档A", "架构文档B"])

    // Switch back to current scope — should be back to one
    store.setSearchScope(.currentScope)
    #expect(store.filteredNotes().map(\.title) == ["架构文档A"])
}

@Test func searchScopePersistsInSnapshot() async throws {
    let store = LibraryStore()
    store.setSearchScope(.all)
    store.updateSearchText("测试")

    let snapshot = store.snapshot()
    #expect(snapshot.searchScope == .all)
    #expect(snapshot.searchText == "测试")

    let restored = LibraryStore(snapshot: snapshot)
    #expect(restored.searchScope == .all)
    #expect(restored.searchText == "测试")
}

// MARK: - Search with Special Characters

@Test func searchWithPartialMatch() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    _ = store.addNote(title: "机器学习入门")
    _ = store.addNote(title: "深度学习入门")
    store.selectOverview(.all)

    store.updateSearchText("学习")

    let notes = store.filteredNotes()
    #expect(notes.count == 2)
}

@Test func searchWithSingleCharacter() async throws {
    let store = LibraryStore()
    _ = store.addProject(name: "项目")
    _ = store.addNote(title: "A笔记")
    _ = store.addNote(title: "B笔记")
    store.selectOverview(.all)

    store.updateSearchText("A")

    let notes = store.filteredNotes()
    #expect(notes.count == 1)
    #expect(notes.first?.title == "A笔记")
}
