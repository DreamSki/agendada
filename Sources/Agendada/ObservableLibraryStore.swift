import AgendadaCore
import Foundation
import Observation

@Observable
@MainActor
final class ObservableLibraryStore {
    private var store: LibraryStore
    private var revision = 0
    @ObservationIgnored
    private let repository: FileLibraryRepository
    @ObservationIgnored
    private var persistTask: Task<Void, Never>?

    var searchText: String {
        get {
            observeRevision()
            return store.searchText
        }
        set {
            store.searchText = newValue
            publishChange()
            persistSoon()
        }
    }

    init(seed: LibraryStore, repository: FileLibraryRepository = FileLibraryRepository()) {
        self.store = seed
        self.repository = repository
    }

    static func load(repository: FileLibraryRepository = FileLibraryRepository()) -> ObservableLibraryStore {
        do {
            if let snapshot = try repository.load() {
                return ObservableLibraryStore(seed: LibraryStore(snapshot: snapshot), repository: repository)
            }
        } catch {
            assertionFailure("Failed to load Agendada library: \(error)")
        }

        let observableStore = ObservableLibraryStore(seed: .sample(), repository: repository)
        observableStore.persist()
        return observableStore
    }

    var categories: [ProjectCategory] {
        observeRevision()
        return store.categories
    }

    var projects: [Project] {
        observeRevision()
        return store.projects
    }

    var smartOverviews: [SmartOverview] {
        observeRevision()
        return store.smartOverviews
    }

    var selectedProjectID: Project.ID? {
        observeRevision()
        return store.selectedProjectID
    }

    var selectedOverview: Overview? {
        observeRevision()
        return store.selectedOverview
    }

    var selectedSmartOverviewID: SmartOverview.ID? {
        observeRevision()
        return store.selectedSmartOverviewID
    }

    var selectedNoteID: Note.ID? {
        observeRevision()
        return store.selectedNoteID
    }

    var selectedNote: Note? {
        observeRevision()
        return store.selectedNote
    }

    var activeTitle: String {
        observeRevision()
        return store.activeTitle
    }

    var allTags: [String] {
        observeRevision()
        return store.allTags
    }

    var allPeople: [String] {
        observeRevision()
        return store.allPeople
    }

    func project(withID id: Project.ID) -> Project? {
        observeRevision()
        return store.project(withID: id)
    }

    func note(withID id: Note.ID) -> Note? {
        observeRevision()
        return store.note(withID: id)
    }

    func category(withID id: ProjectCategory.ID) -> ProjectCategory? {
        observeRevision()
        return store.category(withID: id)
    }

    func projects(in categoryID: ProjectCategory.ID) -> [Project] {
        observeRevision()
        return store.projects(in: categoryID)
    }

    func smartOverview(withID id: SmartOverview.ID) -> SmartOverview? {
        observeRevision()
        return store.smartOverview(withID: id)
    }

    func selectOverview(_ overview: Overview) {
        store.selectOverview(overview)
        publishChange()
        persistSoon()
    }

    func selectProject(_ projectID: Project.ID) {
        store.selectProject(projectID)
        publishChange()
        persistSoon()
    }

    func selectSmartOverview(_ smartOverviewID: SmartOverview.ID) {
        store.selectSmartOverview(smartOverviewID)
        publishChange()
        persistSoon()
    }

    func selectNote(_ noteID: Note.ID) {
        store.selectNote(noteID)
        publishChange()
        persistSoon()
    }

    func relatedNotes(for noteID: Note.ID) -> [RelatedNote] {
        observeRevision()
        return store.relatedNotes(for: noteID)
    }

    func summaryMarkdownForFilteredNotes() -> String {
        observeRevision()
        return store.summaryMarkdownForFilteredNotes()
    }

    func summaryMarkdown(for noteID: Note.ID) -> String? {
        observeRevision()
        return store.summaryMarkdown(for: noteID)
    }

    func addNote(template: NoteTemplate = .blank) {
        _ = store.addNote(template: template)
        publishChange()
        persistNow()
    }

    func duplicateNote(_ noteID: Note.ID) {
        _ = store.duplicateNote(noteID)
        publishChange()
        persistNow()
    }

    func deleteNote(_ noteID: Note.ID) {
        store.deleteNote(noteID)
        publishChange()
        persistNow()
    }

    func addCategory(name: String) {
        _ = store.addCategory(name: name)
        publishChange()
        persistNow()
    }

    func addProject(name: String, categoryID: ProjectCategory.ID?) {
        _ = store.addProject(name: name, categoryID: categoryID)
        publishChange()
        persistNow()
    }

    func renameCategory(_ categoryID: ProjectCategory.ID, name: String) {
        store.renameCategory(categoryID, name: name)
        publishChange()
        persistNow()
    }

    func renameProject(_ projectID: Project.ID, name: String) {
        store.renameProject(projectID, name: name)
        publishChange()
        persistNow()
    }

    func deleteCategory(_ categoryID: ProjectCategory.ID) {
        store.deleteCategory(categoryID)
        publishChange()
        persistNow()
    }

    func deleteProject(_ projectID: Project.ID) {
        store.deleteProject(projectID)
        publishChange()
        persistNow()
    }

    func addSmartOverview(name: String, query: String) {
        _ = store.addSmartOverview(name: name, query: query)
        publishChange()
        persistNow()
    }

    func renameSmartOverview(_ smartOverviewID: SmartOverview.ID, name: String, query: String? = nil) {
        store.renameSmartOverview(smartOverviewID, name: name, query: query)
        publishChange()
        persistNow()
    }

    func deleteSmartOverview(_ smartOverviewID: SmartOverview.ID) {
        store.deleteSmartOverview(smartOverviewID)
        publishChange()
        persistNow()
    }

    func updateSelectedNote(title: String, body: String, scheduledDate: Date?, tags: [String], people: [String]) {
        store.updateSelectedNote(title: title, body: body, scheduledDate: scheduledDate, tags: tags, people: people)
        publishChange()
        persistNow()
    }

    func updateNote(
        noteID: Note.ID,
        title: String,
        body: String,
        scheduledDate: Date?,
        tags: [String],
        people: [String],
        status: NoteStatus? = nil
    ) {
        store.updateNote(
            noteID: noteID,
            title: title,
            body: body,
            scheduledDate: scheduledDate,
            tags: tags,
            people: people,
            status: status
        )
        publishChange()
        persistNow()
    }

    func setFocused(_ isFocused: Bool, noteID: Note.ID) {
        store.setFocused(isFocused, noteID: noteID)
        publishChange()
        persistSoon()
    }

    func setStarred(_ isStarred: Bool, noteID: Note.ID) {
        store.setStarred(isStarred, noteID: noteID)
        publishChange()
        persistSoon()
    }

    func setStatus(_ status: NoteStatus, noteID: Note.ID) {
        store.setStatus(status, noteID: noteID)
        publishChange()
        persistSoon()
    }

    func setCollapsed(_ isCollapsed: Bool, noteID: Note.ID) {
        store.setCollapsed(isCollapsed, noteID: noteID)
        publishChange()
        persistSoon()
    }

    func setNoteColor(_ noteColor: NoteColor?, noteID: Note.ID) {
        store.setNoteColor(noteColor, noteID: noteID)
        publishChange()
        persistSoon()
    }

    func setPinState(_ pinState: PinState, noteID: Note.ID) {
        store.setPinState(pinState, noteID: noteID)
        publishChange()
        persistSoon()
    }

    func scheduleToday(noteID: Note.ID) {
        store.scheduleToday(noteID: noteID)
        publishChange()
        persistSoon()
    }

    func scheduleDate(_ date: Date, noteID: Note.ID) {
        store.scheduleDate(date, noteID: noteID)
        publishChange()
        persistSoon()
    }

    func clearScheduledDate(noteID: Note.ID) {
        store.clearScheduledDate(noteID: noteID)
        publishChange()
        persistSoon()
    }

    func navigateToPreviousScheduledNote(from noteID: Note.ID) -> Note.ID? {
        observeRevision()
        return store.navigateToPreviousScheduledNote(from: noteID)
    }

    func navigateToNextScheduledNote(from noteID: Note.ID) -> Note.ID? {
        observeRevision()
        return store.navigateToNextScheduledNote(from: noteID)
    }

    func navigateToTodayNote() -> Note.ID? {
        observeRevision()
        return store.navigateToTodayNote()
    }

    var tagCounts: [(name: String, count: Int)] {
        observeRevision()
        return store.tagCounts
    }

    func renameTag(_ oldName: String, to newName: String) {
        store.renameTag(oldName, to: newName)
        publishChange()
        persistSoon()
    }

    func deleteTag(_ name: String) {
        store.deleteTag(name)
        publishChange()
        persistSoon()
    }

    func mergeTag(_ source: String, into target: String) {
        store.mergeTag(source, into: target)
        publishChange()
        persistSoon()
    }

    func timelineCounts() -> TimelineCounts {
        observeRevision()
        return store.timelineCounts()
    }

    func filteredNotes() -> [Note] {
        observeRevision()
        return store.filteredNotes()
    }

    private func observeRevision() {
        _ = revision
    }

    private func publishChange() {
        revision &+= 1
    }

    private func persistSoon() {
        persistTask?.cancel()
        persistTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.persist()
            self?.persistTask = nil
        }
    }

    private func persistNow() {
        persistTask?.cancel()
        persistTask = nil
        persist()
    }

    private func persist() {
        do {
            try repository.save(store.snapshot())
        } catch {
            assertionFailure("Failed to save Agendada library: \(error)")
        }
    }
}
