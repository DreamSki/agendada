import AgendadaCore
import SwiftUI

// MARK: - Supporting Types

struct SearchFilterOption: Identifiable {
    let label: String
    let token: String
    let systemImage: String

    var id: String { token }
}

struct SearchPopoverResult: Identifiable {
    let note: Note
    let projectName: String
    let excerpt: String
    let matchCount: Int
    let field: SearchField?

    var id: Note.ID { note.id }
}

// MARK: - Enter-intercepting TextField for Search Popover

// ReturnKeyTextField removed — replaced with SwiftUI TextField + .onSubmit
// which handles Enter/Return reliably without NSViewRepresentable complexity.

// MARK: - Search Popover Content

struct SearchPopoverContent: View {
    let committedSearchText: String
    let clearCommittedSearch: () -> Void
    let pendingDraft: String
    let onDraftChange: (String) -> Void
    @Binding var navigationTargetNoteID: Note.ID?
    @Environment(ObservableLibraryStore.self) private var store
    @State private var showSaveSheet = false
    @State private var showAdvanced = false
    @State private var draftSearchText = ""
    @State private var searchScope: SearchScope = .currentScope

    private var summary: SearchSummary {
        store.searchSummary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 搜索输入框行
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AgendaColor.textMuted)
                TextField("搜索标题、正文、标签或人员", text: $draftSearchText)
                    .textFieldStyle(.plain)
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(AgendaColor.textPrimary)
                    .frame(width: 180, height: 20)
                    .onSubmit {
                        handleSearchReturn()
                    }
                if !draftSearchText.isEmpty {
                    Button {
                        clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AgendaColor.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 搜索范围切换
            HStack(spacing: 0) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    Button {
                        searchScope = scope
                    } label: {
                        Text(scope == .currentScope ? "当前范围" : "全部笔记")
                            .font(.custom("Avenir Next Medium", size: 11))
                            .foregroundStyle(searchScope == scope ? AgendaColor.amber : AgendaColor.textMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                searchScope == scope
                                    ? AgendaColor.amber.opacity(0.12)
                                    : Color.clear,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if !draftChips.isEmpty {
                QueryChipsRow(chips: draftChips)
                    .padding(.top, 4)
            }

            // Syntax hint — shown when input is empty
            if !hasActiveSearch {
                syntaxHintRow
            }

            // Recent search history — shown when draft is empty
            if !hasActiveSearch && !store.searchHistory.isEmpty {
                recentSearchHistory
            }

            if hasActiveSearch {
                searchResultsOverview
            }

            if !searchResultRows.isEmpty {
                searchResultList
            }

            // 导航和计数行
            if isCommittedDraft && summary.totalOccurrences > 0 {
                HStack(spacing: 8) {
                    Button { handlePrevious() } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AgendaColor.amber)
                    }
                    .buttonStyle(.plain)

                    Button { handleNext() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AgendaColor.amber)
                    }
                    .buttonStyle(.plain)

                    Text("\(summary.currentOccurrenceIndex)/\(summary.totalOccurrences)")
                        .font(.custom("Avenir Next Medium", size: 11))
                        .foregroundStyle(AgendaColor.textMuted)

                    Spacer()

                    Button {
                        showSaveSheet = true
                    } label: {
                        Image(systemName: "plus.rectangle.on.folder")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AgendaColor.amber)
                    }
                    .buttonStyle(.plain)
                    .help("保存为智能概览")

                    Text("笔记 \(summary.currentNoteIndex)/\(summary.totalMatchedNotes)")
                        .font(.custom("Avenir Next", size: 11))
                        .foregroundStyle(AgendaColor.textMuted)
                }
            }

            Divider()
                .padding(.vertical, 2)

            Button {
                showAdvanced.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                    Text("语法与筛选")
                        .font(.custom("Avenir Next Medium", size: 11))
                    Spacer()
                    Text(store.sortMode.title)
                        .font(.custom("Avenir Next", size: 10))
                        .foregroundStyle(AgendaColor.textMuted)
                }
                .foregroundStyle(AgendaColor.textMuted)
            }
            .buttonStyle(.plain)

            if showAdvanced {
                advancedSearchContent
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(width: 390)
        .onAppear {
            // Restore draft from committed text or pending (non-committed) input
            draftSearchText = committedSearchText.isEmpty ? pendingDraft : committedSearchText
            searchScope = store.searchScope
        }
        .onChange(of: draftSearchText) { _, newValue in
            onDraftChange(newValue)
        }
        .onChange(of: searchScope) { _, newScope in
            store.searchScope = newScope
        }
        .onChange(of: committedSearchText) { _, newValue in
            if draftSearchText != newValue {
                draftSearchText = newValue
            }
            if newValue.isEmpty {
                SharedBlockNoteWebView.shared.clearSearch()
            }
        }
        .onChange(of: editorSearchRenderKey) { _, _ in
            guard !committedSearchText.isEmpty, store.searchOccurrences.count > 0 else { return }
            let q = store.library.searchHighlightText
            guard !q.isEmpty else { return }
            SharedBlockNoteWebView.shared.searchInEditor(query: q) { _ in
                SharedBlockNoteWebView.shared.navigateToMatch(index: 0) { _, _ in }
            }
        }
        .sheet(isPresented: $showSaveSheet) {
            SmartOverviewPromptSheet(
                sheet: SmartOverviewSheet(query: draftSearchText),
                onSave: { name, query in
                    store.addSmartOverview(name: name, query: query)
                }
            )
        }
    }

    // MARK: - Syntax hints & history

    private var syntaxHintRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("语法提示 — 点击填入")
                .font(.custom("Avenir Next Demi Bold", size: 10))
                .foregroundStyle(AgendaColor.textMuted)
            HStack(spacing: 4) {
                ForEach(syntaxHintTokens, id: \.self) { token in
                    Button {
                        let sep = draftSearchText.isEmpty ? "" : " "
                        draftSearchText = draftSearchText + sep + token
                    } label: {
                        Text(token)
                            .font(.custom("Avenir Next", size: 10))
                            .foregroundStyle(AgendaColor.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AgendaColor.canvasGray, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 6)
    }

    private var syntaxHintTokens: [String] {
        ["#标签", "@人员", "tag:标签", "\"精确短语\"", "NOT 排除", "status:open"]
    }

    private var recentSearchHistory: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("最近搜索")
                    .font(.custom("Avenir Next Demi Bold", size: 10))
                    .foregroundStyle(AgendaColor.textMuted)
                Spacer()
                Button {
                    store.clearSearchHistory()
                } label: {
                    Text("清除全部")
                        .font(.custom("Avenir Next", size: 10))
                        .foregroundStyle(AgendaColor.textMuted)
                }
                .buttonStyle(.plain)
            }

            ForEach(store.searchHistory) { entry in
                HStack(spacing: 4) {
                    Button {
                        draftSearchText = entry.query
                        commitDraftSearch()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AgendaColor.textMuted)
                            Text(entry.query)
                                .font(.custom("Avenir Next", size: 12))
                                .foregroundStyle(AgendaColor.textPrimary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.removeSearchHistoryEntry(id: entry.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AgendaColor.textMuted.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 6)
                }
                .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                )
            }
        }
    }

    private var searchResultsOverview: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(searchScopeTitle)
                    .font(.custom("Avenir Next Demi Bold", size: 11))
                    .foregroundStyle(AgendaColor.textMuted)
                Text(searchResultSummaryText)
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(AgendaColor.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            if !searchResultRows.isEmpty {
                Text(searchScope == .currentScope ? "范围内" : "全局")
                    .font(.custom("Avenir Next Demi Bold", size: 10))
                    .foregroundStyle(AgendaColor.amber)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AgendaColor.amber.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AgendaColor.canvasGray.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
    }

    private var searchResultList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(searchResultRows) { result in
                    Button {
                        openSearchResult(result)
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: result.field == .title ? "textformat" : "doc.text")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AgendaColor.amber)
                                .frame(width: 16, height: 16)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(result.note.title.isEmpty ? "无标题" : result.note.title)
                                        .font(.custom("Avenir Next Medium", size: 12))
                                        .foregroundStyle(AgendaColor.textPrimary)
                                        .lineLimit(1)

                                    if result.matchCount > 0 {
                                        Text("\(result.matchCount)")
                                            .font(.custom("Avenir Next Demi Bold", size: 9))
                                            .foregroundStyle(AgendaColor.amber)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(AgendaColor.amber.opacity(0.12), in: Capsule())
                                    }
                                }

                                Text(result.excerpt)
                                    .font(.custom("Avenir Next", size: 10))
                                    .foregroundStyle(AgendaColor.textMuted)
                                    .lineLimit(1)

                                Text(result.projectName)
                                    .font(.custom("Avenir Next", size: 9))
                                    .foregroundStyle(AgendaColor.textMuted.opacity(0.85))
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 8)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.05), lineWidth: 0.5))
                }
            }
        }
        .frame(maxHeight: 340)
    }

    private var advancedSearchContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("排序")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(AgendaColor.textMuted)
                Menu {
                    ForEach(SortMode.allCases, id: \.self) { mode in
                        Button(mode.title) {
                            store.setSortMode(mode)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(store.sortMode.title)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(AgendaColor.amber)
                }
                .menuStyle(.borderlessButton)

                Spacer()

                Button {
                    showSaveSheet = true
                } label: {
                    Label("保存概览", systemImage: "plus.rectangle.on.folder")
                        .font(.custom("Avenir Next Medium", size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AgendaColor.amber)
                .disabled(draftSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text("输入关键词，或点下面条件快速组合筛选：")
                .font(.custom("Avenir Next", size: 10))
                .foregroundStyle(AgendaColor.textMuted)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(searchFilterOptions) { option in
                    Button {
                        toggleSearchToken(option.token)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: containsSearchToken(option.token) ? "checkmark.circle.fill" : option.systemImage)
                                .font(.system(size: 10, weight: .medium))
                            Text(option.label)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.custom("Avenir Next", size: 10))
                    .foregroundStyle(containsSearchToken(option.token) ? AgendaColor.amber : AgendaColor.textPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AgendaColor.canvasGray, in: Capsule())
                    .help(option.token)
                }
            }

            Text("语法：tag:标签 person:人名 status:open，多个条件会同时生效")
                .font(.custom("Avenir Next", size: 10))
                .foregroundStyle(AgendaColor.textMuted)
        }
        .padding(.top, 2)
    }

    private var searchFilterOptions: [SearchFilterOption] {
        [
            SearchFilterOption(label: "简达", token: "is:brief", systemImage: "smallcircle.fill.circle"),
            SearchFilterOption(label: "关注", token: "is:focused", systemImage: "scope"),
            SearchFilterOption(label: "未完成", token: "status:open", systemImage: "circle"),
            SearchFilterOption(label: "已完成", token: "status:completed", systemImage: "checkmark.circle"),
            SearchFilterOption(label: "有待办", token: "has:tasks", systemImage: "checklist"),
            SearchFilterOption(label: "有日期", token: "has:date", systemImage: "calendar"),
            SearchFilterOption(label: "今天", token: "date:today", systemImage: "sun.max"),
            SearchFilterOption(label: "未来", token: "date:upcoming", systemImage: "calendar.badge.clock")
        ]
    }

    private var searchTerms: [String] {
        draftSearchText
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private var trimmedSearchText: String {
        draftSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasActiveSearch: Bool {
        !trimmedSearchText.isEmpty
    }

    private var draftChips: [QueryChip] {
        NoteSearchEngine.chips(for: draftSearchText)
    }

    /// Notes matching the draft search — full filter pass (structural predicates).
    private var searchResultNotes: [Note] {
        guard hasActiveSearch else { return [] }
        if searchScope == .currentScope {
            let baseNotes = store.library.currentScopeNotesForPreview(now: Date())
            let query = NoteSearchEngine.parse(draftSearchText)
            return NoteSearchEngine.filter(baseNotes, query: query)
        } else {
            return store.library.globalSearchNotes(for: draftSearchText, onlyTrash: isTrashPreview)
        }
    }

    /// Lightweight count of matching notes — reuses the filter result above.
    private var searchResultNoteCount: Int {
        searchResultNotes.count
    }

    /// Occurrences computed for all matched notes — provides match counts and
    /// excerpts for the popover result list. Debounced at 180ms by the store layer.
    private var previewOccurrences: [SearchOccurrence] {
        guard hasActiveSearch else { return [] }
        return NoteSearchEngine.occurrences(in: searchResultNotes, query: draftSearchText)
    }

    private var searchResultRows: [SearchPopoverResult] {
        let occurrencesByNote = Dictionary(grouping: previewOccurrences, by: \.noteID)
        return searchResultNotes.map { note in
            let occurrences = occurrencesByNote[note.id] ?? []
            let firstOccurrence = occurrences.first
            return SearchPopoverResult(
                note: note,
                projectName: projectPath(for: note),
                excerpt: firstOccurrence?.excerpt ?? fallbackExcerpt(for: note),
                matchCount: occurrences.count,
                field: firstOccurrence?.field
            )
        }
    }

    /// Stable key for WebView search highlight refresh — avoids stale highlights
    /// when search text changes but occurrence count stays the same.
    private var editorSearchRenderKey: String {
        [
            committedSearchText,
            store.selectedNoteID?.uuidString ?? "",
            "\(store.currentOccurrence?.globalIndex ?? -1)",
            "\(store.searchOccurrences.count)"
        ].joined(separator: "|")
    }

    private var isTrashPreview: Bool {
        store.selectedOverview == .trash
    }

    private var isCommittedDraft: Bool {
        !committedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && committedSearchText.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedSearchText
    }

    private var searchScopeTitle: String {
        if store.selectedOverview == .trash {
            return "废纸篓搜索"
        }
        if searchScope == .currentScope {
            if let projectID = store.selectedProjectID,
               let project = store.library.project(withID: projectID) {
                return "项目：\(project.name)"
            }
            if let overview = store.selectedOverview {
                return overview.title + "搜索"
            }
        }
        return "全局搜索"
    }

    private var searchResultSummaryText: String {
        if !searchResultNotes.isEmpty {
            let count = searchResultNoteCount
            return "\(count) 篇笔记匹配 — 按 Enter 查看全部命中"
        }
        return filteredSearchStatusText
    }

    private var hasSearchFilters: Bool {
        searchTerms.contains { isSearchFilterToken($0) }
    }

    private var hasPlainKeywords: Bool {
        searchTerms.contains { !isSearchFilterToken($0) }
    }

    private var filteredSearchStatusText: String {
        let count = searchResultNotes.count
        if count == 0 {
            return hasPlainKeywords ? "无匹配结果" : "没有符合条件的笔记"
        }
        if hasPlainKeywords {
            return "已筛选 \(count) 篇笔记，未找到关键词位置"
        }
        return "已筛选 \(count) 篇笔记"
    }

    private func containsSearchToken(_ token: String) -> Bool {
        searchTerms.contains(token)
    }

    private func toggleSearchToken(_ token: String) {
        var terms = searchTerms
        if let index = terms.firstIndex(of: token) {
            terms.remove(at: index)
        } else {
            terms.append(token)
        }
        draftSearchText = terms.joined(separator: " ")
    }

    private func isSearchFilterToken(_ term: String) -> Bool {
        term.hasPrefix("tag:")
            || term.hasPrefix("person:")
            || term.hasPrefix("status:")
            || term.hasPrefix("has:")
            || term.hasPrefix("is:")
            || term.hasPrefix("date:")
    }

    private func projectPath(for note: Note) -> String {
        guard let project = store.project(withID: note.projectID) else {
            return "未归属项目"
        }
        if let categoryID = project.categoryID,
           let category = store.category(withID: categoryID) {
            return "\(category.name) / \(project.name)"
        }
        return project.name
    }

    private func fallbackExcerpt(for note: Note) -> String {
        let body = note.bodyPlainText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty {
            return String(body.prefix(72))
        }
        if !note.tags.isEmpty {
            return note.tags.map { "#\($0)" }.joined(separator: " ")
        }
        return hasSearchFilters ? "符合当前筛选条件" : "标题匹配"
    }

    private func openSearchResult(_ result: SearchPopoverResult) {
        commitDraftSearch()
        store.selectNote(result.note.id)
        navigationTargetNoteID = result.note.id
        if let occurrence = store.searchOccurrences.first(where: { $0.noteID == result.note.id }) {
            prepareEditorSearchNavigation(for: occurrence)
        }
    }

    private func clearSearch() {
        draftSearchText = ""
        clearCommittedSearch()
    }

    private func commitDraftSearch() {
        store.commitSearchText(draftSearchText)
    }

    private func handleSearchReturn() {
        guard hasActiveSearch else {
            clearSearch()
            return
        }

        guard isCommittedDraft else {
            commitDraftSearch()
            return
        }

        handleNext()
    }

    private func handleNext() {
        let previousNoteID = store.selectedNoteID
        guard let occurrence = store.goToNextSearchOccurrence() else { return }
        if occurrence.noteID == previousNoteID {
            syncEditorHighlight(occurrence)
        } else {
            prepareEditorSearchNavigation(for: occurrence)
        }
    }

    private func handlePrevious() {
        let previousNoteID = store.selectedNoteID
        guard let occurrence = store.goToPreviousSearchOccurrence() else { return }
        if occurrence.noteID == previousNoteID {
            syncEditorHighlight(occurrence)
        } else {
            prepareEditorSearchNavigation(for: occurrence)
        }
    }

    /// 引擎跳转后，同步编辑器的橙色高亮到当前 occurrence。
    /// - 同笔记 body：直接 navigateToMatch
    /// - 跨笔记：handleNext/handlePrevious 会登记 pending，新编辑器的 onReady 再处理
    /// - title：编辑器里没有对应 DOM 高亮，回退到本条笔记的第一个 body 匹配
    ///   作为视觉锚点（navigateToMatch JS 会做边界检查，无 body 匹配时安全跳过）
    private func syncEditorHighlight(_ occ: SearchOccurrence? = nil) {
        guard let occ = occ ?? store.currentOccurrence else { return }
        let index: Int = occ.field == .body ? occ.bodyIndexInNote : 0
        SharedBlockNoteWebView.shared.navigateToMatch(index: index) { _, _ in }
    }

    private func prepareEditorSearchNavigation(for occ: SearchOccurrence) {
        let query = store.library.searchHighlightText
        guard !query.isEmpty else { return }
        navigationTargetNoteID = occ.noteID
        SharedBlockNoteWebView.shared.prepareSearchNavigation(
            noteID: occ.noteID,
            query: query,
            bodyIndex: occ.field == .body ? occ.bodyIndexInNote : 0
        )
    }
}
