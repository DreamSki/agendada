import AgendadaCore
import Foundation
import Observation
@preconcurrency import AgendadaCore

@Observable
@MainActor
final class ObservableLibraryStore {
    private var store: LibraryStore
    private var revision = 0
    private var dataRevision = 0
    @ObservationIgnored
    private let repository: FileLibraryRepository
    @ObservationIgnored
    private var persistTask: Task<Void, Never>?
    @ObservationIgnored
    private var saveTask: Task<Void, Never>?
    @ObservationIgnored
    private let persistenceEnabled: Bool
    // @ObservationIgnored
    // private var autoMonitor: AutoPerformanceMonitor!

    // MARK: - Filtered Notes Cache

    /// Cached result of filteredNotes() to avoid recomputing on every view body evaluation.
    /// Invalidated when note/filter data changes, not when only the selected note changes.
    @ObservationIgnored
    private var cachedFilteredNotes: [Note]?
    @ObservationIgnored
    private var cachedFilteredNotesRevision: Int = -1
    @ObservationIgnored
    private var cachedFilteredNotesSearchText: String = ""

    /// Debounced search-occurrence calculation task.
    @ObservationIgnored
    private var searchCalcTask: Task<Void, Never>?

    var searchText: String {
        get {
            observeRevision()
            return store.searchText
        }
        set {
            store.setSearchTextOnly(newValue)
            publishChange()
            scheduleSearchCalculation()
            persistSoon()
        }
    }

    // MARK: - Search

    /// 底层 LibraryStore 的直接访问（只读）
    var library: LibraryStore {
        observeRevision()
        return store
    }

    var searchOccurrences: [SearchOccurrence] {
        observeRevision()
        return store.searchOccurrences
    }

    var currentOccurrence: SearchOccurrence? {
        observeRevision()
        return store.currentOccurrence
    }

    var searchSummary: SearchSummary {
        observeRevision()
        return store.searchSummary
    }

    @discardableResult
    func goToNextSearchOccurrence() -> SearchOccurrence? {
        let occurrence = store.goToNextSearchOccurrence()
        publishChange()
        persistSoon()
        return occurrence
    }

    @discardableResult
    func goToPreviousSearchOccurrence() -> SearchOccurrence? {
        let occurrence = store.goToPreviousSearchOccurrence()
        publishChange()
        persistSoon()
        return occurrence
    }

    var sortOrder: NoteSortOrder {
        get {
            observeRevision()
            return store.sortOrder
        }
        set {
            store.sortOrder = newValue
            publishChange()
            persistSoon()
        }
    }

    var sortMode: SortMode {
        get {
            observeRevision()
            return store.sortMode
        }
        set {
            store.setSortMode(newValue)
            publishChange()
            persistSoon()
        }
    }

    func setSortMode(_ mode: SortMode) {
        store.setSortMode(mode)
        publishChange()
        persistSoon()
    }

    func moveNote(_ noteID: Note.ID, to move: PositionMove) {
        store.moveNote(noteID, to: move)
        publishChange()
        persistSoon()
    }

    func wouldCrossPinnedTopBoundary(_ noteID: Note.ID, move: PositionMove) -> Bool {
        store.wouldCrossPinnedTopBoundary(noteID, move: move)
    }

    func moveToFirstNonPinned(_ noteID: Note.ID) {
        store.moveToFirstNonPinned(noteID)
        publishChange()
        persistSoon()
    }

    func pinAndMoveNote(_ noteID: Note.ID, to move: PositionMove) {
        store.setPinState(.pinnedTop, noteID: noteID)
        store.moveNote(noteID, to: move)
        publishChange()
        persistSoon()
    }

    func pinBoundaryCrossing(draggedNoteID: Note.ID, targetNoteID: Note.ID) -> PinBoundaryCrossing {
        store.pinBoundaryCrossing(draggedNoteID: draggedNoteID, targetNoteID: targetNoteID)
    }

    func wouldLeavePinnedTopBoundary(_ noteID: Note.ID, move: PositionMove) -> Bool {
        store.wouldLeavePinnedTopBoundary(noteID, move: move)
    }

    func insertNoteBefore(_ noteID: Note.ID, targetID: Note.ID) {
        store.insertNoteBefore(noteID, targetID: targetID)
        publishChange()
        persistSoon()
    }

    func insertNoteAfter(_ noteID: Note.ID, targetID: Note.ID) {
        store.insertNoteAfter(noteID, targetID: targetID)
        publishChange()
        persistSoon()
    }

    init(seed: LibraryStore, repository: FileLibraryRepository = FileLibraryRepository(), persistenceEnabled: Bool = true) {
        self.store = seed
        self.repository = repository
        self.persistenceEnabled = persistenceEnabled
        // self.autoMonitor = AutoPerformanceMonitor()
    }

    static func load(repository: FileLibraryRepository = FileLibraryRepository()) async -> ObservableLibraryStore {
        do {
            if let snapshot = try await repository.load() {
                // Defer GC to background so it doesn't block startup
                let repo = repository
                Task { await repo.collectGarbage(in: snapshot) }
                return ObservableLibraryStore(seed: LibraryStore(snapshot: snapshot), repository: repository)
            }
        } catch {
            print("Failed to load Agendada library: \(error)")
            if await repository.fileExists {
                return ObservableLibraryStore(seed: .sample(), repository: repository, persistenceEnabled: false)
            }
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
        publishSelectionChange()
        persistSoon()
    }

    func relatedNotes(for noteID: Note.ID) -> [RelatedNote] {
        observeRevision()
        return store.relatedNotes(for: noteID)
    }

    func summaryForFilteredNotes() -> String {
        observeRevision()
        return store.summaryForFilteredNotes()
    }

    func summary(for noteID: Note.ID) -> String? {
        observeRevision()
        return store.summary(for: noteID)
    }

    func addNote(template: NoteTemplate = .blank) {
        _ = store.addNote(template: template)
        publishChange()
        persistNow()
    }

    /// Create a note and return its ID
    @discardableResult
    func addNoteReturningID(template: NoteTemplate = .blank) -> Note.ID {
        let note = store.addNote(template: template)
        publishChange()
        persistNow()
        return note.id
    }

    // MARK: - Custom Note Templates

    func addCustomNoteTemplate(name: String, from note: Note) {
        _ = store.addCustomNoteTemplate(name: name, from: note)
        publishChange()
        persistNow()
    }

    func deleteCustomNoteTemplate(_ templateID: CustomNoteTemplate.ID) {
        store.deleteCustomNoteTemplate(templateID)
        publishChange()
        persistNow()
    }

    func customNoteTemplatesList() -> [CustomNoteTemplate] {
        observeRevision()
        return store.customNoteTemplates
    }

    func duplicateNote(_ noteID: Note.ID) {
        _ = store.duplicateNote(noteID)
        publishChange()
        persistNow()
    }

    func deleteNote(_ noteID: Note.ID) {
        store.deleteNote(noteID)
        publishChange()
        persistSoon()
    }

    func permanentlyDeleteNote(_ noteID: Note.ID) {
        store.permanentlyDeleteNote(noteID)
        publishChange()
        persistSoon()
    }

    func restoreNote(_ noteID: Note.ID) {
        store.restoreNote(noteID)
        publishChange()
        persistSoon()
    }

    var trashedNotes: [Note] {
        observeRevision()
        return store.trashedNotes
    }

    func emptyTrash() {
        store.emptyTrash()
        publishChange()
        persistSoon()
    }

    // MARK: - Batch Selection

    var batchSelectedNoteIDs: Set<Note.ID> {
        observeRevision()
        return store.batchSelectedNoteIDs
    }
    var isInBatchMode: Bool {
        observeRevision()
        return !store.batchSelectedNoteIDs.isEmpty
    }

    func selectAllFilteredNotes() {
        store.selectAllFilteredNotes()
        publishChange()
    }

    func deselectAllNotes() {
        store.deselectAllNotes()
        publishChange()
    }

    func toggleBatchSelection(noteID: Note.ID) {
        store.toggleBatchSelection(noteID: noteID)
        publishChange()
    }

    func invertBatchSelection() {
        store.invertBatchSelection()
        publishChange()
    }

    // MARK: - Batch Operations

    func batchDeleteNotes(_ noteIDs: Set<Note.ID>) {
        store.batchDeleteNotes(noteIDs)
        publishChange()
        persistSoon()
    }

    func batchRestoreNotes(_ noteIDs: Set<Note.ID>) {
        store.batchRestoreNotes(noteIDs)
        publishChange()
        persistSoon()
    }

    func batchPermanentlyDeleteNotes(_ noteIDs: Set<Note.ID>) {
        store.batchPermanentlyDeleteNotes(noteIDs)
        publishChange()
        persistSoon()
    }

    func moveNotes(_ noteIDs: Set<Note.ID>, toProject projectID: Project.ID) {
        store.moveNotes(noteIDs, toProject: projectID)
        publishChange()
        persistSoon()
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
        guard store.updateSelectedNote(title: title, body: body, scheduledDate: scheduledDate, tags: tags, people: people) else {
            return
        }
        publishChange()
        persistNow()
    }

    func updateNote(
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
    ) {
        guard store.updateNote(
            noteID: noteID,
            title: title,
            body: body,
            blockJSON: blockJSON,
            plainTextPreview: plainTextPreview,
            previewHTML: previewHTML,
            scheduledDate: scheduledDate,
            tags: tags,
            people: people,
            status: status
        ) else {
            return
        }
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

    func setBrief(_ isBrief: Bool, noteID: Note.ID) {
        store.setBrief(isBrief, noteID: noteID)
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
        #if DEBUG
        let start = Date()
        let cacheHit = cachedFilteredNotes != nil &&
                       cachedFilteredNotesRevision == dataRevision &&
                       cachedFilteredNotesSearchText == store.searchText
        #endif
        observeRevision()
        if let cached = cachedFilteredNotes,
           cachedFilteredNotesRevision == dataRevision,
           cachedFilteredNotesSearchText == store.searchText {
            #if DEBUG
            if !cacheHit {
                print("🔄 [PERF] filteredNotes cache MISS - recalculating")
            }
            #endif
            return cached
        }
        #if DEBUG
        print("🔄 [PERF] filteredNotes recalculating...")
        #endif
        let result = store.filteredNotes()
        cachedFilteredNotes = result
        cachedFilteredNotesRevision = dataRevision
        cachedFilteredNotesSearchText = store.searchText
        // Invalidate derived caches
        cachedScheduledNotesHash = nil
        #if DEBUG
        let elapsed = Date().timeIntervalSince(start)
        if elapsed > 0.050 {
            print("⚠️ [PERF] filteredNotes took \(String(format: "%.3f", elapsed))s - result count: \(result.count)")
        }
        #endif
        return result
    }

    /// Cached hash of scheduled notes (id + scheduledDate) for RelatedPanelContentView.
    /// Computed once per filteredNotes() result to avoid O(n) hashing in view body.
    @ObservationIgnored
    private var cachedScheduledNotesHash: Int?

    var scheduledNotesHash: Int {
        observeRevision()
        if let cached = cachedScheduledNotesHash { return cached }
        var hasher = Hasher()
        let notes = filteredNotes()
        for note in notes {
            hasher.combine(note.id)
            hasher.combine(note.scheduledDate)
        }
        let hash = hasher.finalize()
        cachedScheduledNotesHash = hash
        return hash
    }

    private func invalidateFilteredNotesCache() {
        cachedFilteredNotes = nil
        cachedFilteredNotesRevision = -1
        cachedFilteredNotesSearchText = ""
    }

    /// Debounce search-occurrence calculation so fast typing doesn't
    /// trigger expensive full-text scanning on every keystroke.
    private func scheduleSearchCalculation() {
        searchCalcTask?.cancel()
        let text = store.searchText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            store.clearSearchOccurrences()
            return
        }
        searchCalcTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000) // 180ms debounce
            guard !Task.isCancelled, let self else { return }
            self.store.calculateSearchOccurrences()
            // Don't auto-select first result during typing — wait for Enter.
            // Only publish the change so searchSummary / occurrences are visible.
            self.publishChange()
        }
    }

    private func observeRevision() {
        _ = revision
    }

    private func publishChange() {
        #if DEBUG
        let start = Date()
        let caller = Thread.callStackSymbols.dropFirst().first?.components(separatedBy: " ").last ?? "unknown"
        let logLine = "📢 [PERF] publishChange called from: \(caller.prefix(50))\n"
        print(logLine)
        appendToLogFile(logLine)
        #endif
        revision &+= 1
        dataRevision &+= 1
        invalidateFilteredNotesCache()
        #if DEBUG
        let elapsed = Date().timeIntervalSince(start)
        if elapsed > 0.001 {
            let warnLine = "⚠️ [PERF] publishChange took \(String(format: "%.3f", elapsed))s\n"
            print(warnLine)
            appendToLogFile(warnLine)
        }
        #endif

        // Notify auto monitor
        // Task { await autoMonitor?.logOperation("publishChange") }
    }

    private func publishSelectionChange() {
        revision &+= 1
    }

    private func persistSoon() {
        guard persistenceEnabled else { return }
        persistTask?.cancel()
        persistTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.persist()
            self?.persistTask = nil
        }
    }

    private func persistNow() {
        guard persistenceEnabled else { return }
        persistTask?.cancel()
        persistTask = nil
        persist()
    }

    private func persist() {
        guard persistenceEnabled else { return }
        #if DEBUG
        let start = Date()
        print("🔖 [PERF] persist() started")
        #endif
        saveTask?.cancel()
        let snapshot = store.snapshot()
        let repo = repository
        #if DEBUG
        let snapshotTime = Date().timeIntervalSince(start)
        print("⏱️ [PERF] snapshot() took \(String(format: "%.3f", snapshotTime))s")
        #endif
        saveTask = Task {
            do { try await repo.save(snapshot) }
            catch { assertionFailure("Failed to save Agendada library: \(error)") }
        }
    }

    /// Synchronously flush any pending save. Blocks the calling thread until the
    /// write completes. Only intended for app-termination paths.
    func flushPendingSaveSync() {
        guard persistenceEnabled else { return }
        persistTask?.cancel()
        persistTask = nil

        // Flush any pending WKWebView editor content before snapshotting.
        // WKWebView JS callbacks are delivered on the main run loop, so we
        // spin the run loop (with a timeout) rather than blocking with
        // DispatchGroup.wait(), which would deadlock the callback.
        if SharedBlockNoteWebView.shared.hasContentChanges {
            let sema = DispatchSemaphore(value: 0)
            SharedBlockNoteWebView.shared.saveCurrentContentNow { [weak self] content in
                guard let self, let content,
                      let activeNote = store.note(withID: content.noteID) else {
                    sema.signal()
                    return
                }
                store.updateNote(
                    noteID: activeNote.id,
                    title: activeNote.title,
                    body: content.previewHTML ?? content.plainTextPreview,
                    blockJSON: content.blockJSON,
                    plainTextPreview: content.plainTextPreview,
                    previewHTML: content.previewHTML,
                    scheduledDate: activeNote.scheduledDate,
                    tags: activeNote.tags,
                    people: activeNote.people,
                    status: activeNote.status
                )
                sema.signal()
            }
            let deadline = Date().addingTimeInterval(3.0)
            while sema.wait(timeout: .now()) == .timedOut, Date() < deadline {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
            }
            if Date() >= deadline {
                print("⚠️ [Agendada] flushPendingSaveSync: editor flush timed out after 3s — snapshotting without latest editor content")
            }
        }

        let snapshot = store.snapshot()
        let repo = repository
        let done = DispatchGroup()
        done.enter()
        Task {
            do { try await repo.save(snapshot) }
            catch { assertionFailure("Failed to save Agendada library on terminate: \(error)") }
            done.leave()
        }
        if done.wait(timeout: .now() + 5.0) == .timedOut {
            print("⚠️ [Agendada] flushPendingSaveSync: save timed out after 5s — proceeding with termination")
        }
    }

    #if DEBUG
    @ObservationIgnored
    private let logFilePath = "/tmp/agendada-perf.log"

    private func appendToLogFile(_ message: String) {
        DispatchQueue.main.async {
            if let data = message.data(using: .utf8) {
                if let handle = FileHandle(forWritingAtPath: self.logFilePath) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                } else {
                    FileManager.default.createFile(atPath: self.logFilePath, contents: data, attributes: nil)
                }
            }
        }
    }
    #endif
}
