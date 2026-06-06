import AgendadaCore
import AppKit
import SwiftUI

struct NoteStreamView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @Binding var searchText: String
    @Binding var navigationTargetNoteID: Note.ID?
    @State private var isSearching = false
    @State private var showSortPopover = false
    @State private var showMoveMenu = false
    @State private var dropAtEndTargeted = false
    @State private var showTemplatePopover = false
    @State private var navigationScrollWorkItem: DispatchWorkItem?
    @State private var streamScrollView: NSScrollView?
    @State private var localSelectionScrollLockOrigin: CGPoint?
    @State private var localSelectionScrollLockDeadline: Date = .distantPast
    @State private var localSelectionScrollLockGeneration = 0

    var body: some View {
        ZStack(alignment: .top) {
            noteStreamContent
            headerGradient
            streamHeader
        }
        .background(Color.white)
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                SharedBlockNoteWebView.shared.clearSearch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .findInNoteRequested)) { _ in
            store.requestFindInNote()
        }
    }

    // MARK: - Header

    private var streamHeader: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    if let categoryName = breadcrumbCategoryName {
                        Text(categoryName)
                            .font(AgendaFont.breadcrumbCategory)
                            .foregroundStyle(AgendaColor.textMuted)
                    }
                    Text(mainTitle)
                        .font(AgendaFont.breadcrumbTitle)
                        .foregroundStyle(Color(red: 0.173, green: 0.173, blue: 0.180))
                    if let context = breadcrumbContext {
                        Text(context)
                            .font(AgendaFont.breadcrumbContext)
                            .foregroundStyle(AgendaColor.textMuted)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                Spacer()
                if store.isInBatchMode {
                    batchActions
                } else {
                    headerActions
                }
            }
            .padding(.horizontal, 32).padding(.top, 30)
            .animation(.linear(duration: 0.1), value: store.isInBatchMode)
        }
    }

    private var headerActions: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                CapsuleIconFloatingMenuButton(
                    systemName: "line.3.horizontal.decrease",
                    help: "排序方式",
                    isPresented: $showSortPopover,
                    width: 190,
                    sections: { sortFloatingMenuSections(store: store) }
                )
                CapsuleIconButton(systemName: "sparkles", help: "复制摘要", action: {
                    copyToPasteboard(store.summaryForFilteredNotes())
                })
                CapsuleIconPopoverButton(systemName: "magnifyingglass", help: "搜索", isPresented: $isSearching, popoverContent: {
                    SearchPopoverContent(
                        committedSearchText: searchText,
                        clearCommittedSearch: { searchText = "" },
                        navigationTargetNoteID: $navigationTargetNoteID
                    )
                })
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white, in: Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)

            plusButton
        }
    }

    private var batchActions: some View {
        HStack(spacing: 12) {
            // 批量操作胶囊
            HStack(spacing: 4) {
                CapsuleIconButton(systemName: "checkmark.circle", help: "全选", hoverEffect: .scale, action: {
                    let allIDs = Set(store.filteredNotes().map(\.id))
                    if store.batchSelectedNoteIDs.count == allIDs.count && allIDs.count > 0 {
                        store.deselectAllNotes()
                    } else {
                        store.selectAllFilteredNotes()
                    }
                })
                CapsuleIconButton(systemName: "arrow.turn.up.right", help: "反选", hoverEffect: .rotate, action: {
                    store.invertBatchSelection()
                })
                if store.selectedOverview == .trash {
                    CapsuleIconButton(systemName: "arrow.counterclockwise", help: "恢复", hoverEffect: .scale, action: {
                        store.batchRestoreNotes(store.batchSelectedNoteIDs)
                    })
                    CapsuleIconButton(systemName: "xmark.bin", help: "彻底删除", role: .destructive, hoverEffect: .scale, action: {
                        store.batchPermanentlyDeleteNotes(store.batchSelectedNoteIDs)
                    })
                } else {
                    CapsuleIconButton(systemName: "trash", help: "移至废纸篓", role: .destructive, hoverEffect: .trashLid, action: {
                        store.batchDeleteNotes(store.batchSelectedNoteIDs)
                    })
                    if !store.projects.isEmpty {
                    CapsuleIconButton(systemName: "chevron.right", help: "移动到项目", hoverEffect: .scale, action: {
                            showMoveMenu.toggle()
                        })
                        .popover(isPresented: $showMoveMenu, arrowEdge: .bottom) {
                            AgendadaFloatingMenuView(
                                sections: batchMoveFloatingMenuSections(store: store, showMoveMenu: $showMoveMenu),
                                presenter: AgendadaFloatingMenuPresenter(),
                                width: 190
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white, in: Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)

            // 取消按钮独立
            HoverableCircleButton(systemName: "xmark", help: "取消", action: {
                store.deselectAllNotes()
            })
        }
    }

    private var plusButton: some View {
        Button {
            showTemplatePopover = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AgendaColor.amber)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.white, in: Circle())
        .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        .help("新建笔记")
        .keyboardShortcut("n", modifiers: [.command])
        .popover(isPresented: $showTemplatePopover, arrowEdge: .bottom) {
            templatePickerContent
        }
    }

    private var templatePickerContent: some View {
        let customTemplates = store.customNoteTemplatesList()
        return VStack(alignment: .leading, spacing: 0) {
            Text("选择模板")
                .font(.custom("Avenir Next Demi Bold", size: 11))
                .foregroundStyle(AgendaColor.textMuted)
                .padding(.horizontal, 12).padding(.vertical, 6)

            Divider()

            ForEach(NoteTemplate.allCases) { template in
                Button {
                    store.addNote(template: template)
                    showTemplatePopover = false
                    searchText = ""
                } label: {
                    HStack {
                        Text(template.defaultNoteTitle)
                            .font(.custom("Avenir Next", size: 13))
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if !customTemplates.isEmpty {
                Divider()
                Text("自定义模板")
                    .font(.custom("Avenir Next Demi Bold", size: 11))
                    .foregroundStyle(AgendaColor.textMuted)
                    .padding(.horizontal, 12).padding(.vertical, 6)

                ForEach(customTemplates) { ct in
                    Button {
                        let newID = store.addNoteReturningID(template: .blank)
                        store.updateNote(
                            noteID: newID,
                            title: ct.title.isEmpty ? ct.name : ct.title,
                            body: ct.body,
                            scheduledDate: nil,
                            tags: ct.tags,
                            people: []
                        )
                        showTemplatePopover = false
                        searchText = ""
                    } label: {
                        HStack {
                            Text(ct.name)
                                .font(.custom("Avenir Next", size: 13))
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 200)
        .agendadaGlassPopover()
    }

    private var headerGradient: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .white, location: 0.0),
                .init(color: .white.opacity(0.9), location: 0.25),
                .init(color: .white.opacity(0.8), location: 0.45),
                .init(color: .white.opacity(0.6), location: 0.60),
                .init(color: .white.opacity(0.5), location: 0.70),
                .init(color: .white.opacity(0.35), location: 0.80),
                .init(color: .white.opacity(0.20), location: 0.90),
                .init(color: .white.opacity(0.10), location: 0.95),
                .init(color: .clear, location: 1.0),
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 70)
        .allowsHitTesting(false)
    }

    private var mainTitle: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "搜索结果"
        }
        if let ov = store.selectedOverview { return ov.title }
        if let pid = store.selectedProjectID, let proj = store.project(withID: pid) { return proj.name }
        return store.activeTitle
    }

    private var breadcrumbCategoryName: String? {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        if store.selectedOverview != nil { return nil }
        if let pid = store.selectedProjectID, let proj = store.project(withID: pid),
           let cid = proj.categoryID, let cat = store.category(withID: cid) { return cat.name }
        return nil
    }

    private var breadcrumbContext: String? {
        if store.isInBatchMode { return "已选 \(store.batchSelectedNoteIDs.count) 项" }
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let scope = store.selectedOverview == .trash ? "废纸篓" : "全局"
            return "\(scope) · \(store.filteredNotes().count) 条笔记"
        }
        if store.selectedOverview != nil { return "\(store.filteredNotes().count) 条笔记" }
        if let note = store.selectedNoteID.flatMap({ store.note(withID: $0) }) { return note.title }
        return nil
    }

    // MARK: - Stream

    private var noteStreamContent: some View {
        let notes = store.filteredNotes()
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCommittedSearch = !trimmedSearch.isEmpty && !store.searchOccurrences.isEmpty
        let isNoResultsSearch = !trimmedSearch.isEmpty && store.searchOccurrences.isEmpty
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if isCommittedSearch {
                        SearchResultsContentView(
                            navigationTargetNoteID: $navigationTargetNoteID
                        )
                    } else if isNoResultsSearch {
                        SearchNoResultsView(searchText: trimmedSearch)
                    } else {
                        ForEach(notes, id: \.id) { note in
                            StreamNoteRow(
                                note: note,
                                cancelPendingNavigation: cancelPendingNavigation,
                                performLocalSelection: preserveScrollDuringLocalSelection,
                                preserveLocalScrollPosition: restoreLocalSelectionScrollPosition,
                                onNavigateToNote: { targetID in
                                    navigationTargetNoteID = targetID
                                }
                            )
                                .padding(.bottom, AgendaSpacing.cardGap)
                        }
                    }
                // Bottom terminal drop zone
                Rectangle()
                    .fill(dropAtEndTargeted ? AgendaColor.amber.opacity(0.1) : Color.clear)
                    .frame(height: 80)
                    .overlay(alignment: .top) {
                        if dropAtEndTargeted {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AgendaColor.amber)
                                .frame(height: 3)
                                .padding(.horizontal, 40)
                        }
                    }
                    .dropDestination(for: DragPayload.self) { items, _ in
                        guard let payload = items.first else { return false }
                        guard let lastNote = notes.last, lastNote.id != payload.noteID else {
                            return false
                        }
                        guard let draggedNote = store.note(withID: payload.noteID) else { return false }
                        guard draggedNote.projectID == lastNote.projectID else { return false }
                        guard notes.contains(where: { $0.id == draggedNote.id }) || draggedNote.projectID == (notes.first?.projectID) else { return false }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            store.insertNoteAfter(payload.noteID, targetID: lastNote.id)
                        }
                        return true
                    } isTargeted: { targeted in
                        dropAtEndTargeted = targeted
                    }
            }
            .padding(.horizontal, 12).padding(.top, 100).padding(.bottom, 80)
        }
        .background {
            EnclosingScrollViewResolver { scrollView in
                if streamScrollView !== scrollView {
                    streamScrollView = scrollView
                }
            }
        }
        .background {
            Button("") {
                if store.isInBatchMode { store.deselectAllNotes() }
            }
            .keyboardShortcut(.escape, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)
        }
        .onChange(of: navigationTargetNoteID) { _, targetID in
            navigationScrollWorkItem?.cancel()
            guard let id = targetID else { return }
            clearLocalSelectionScrollLock()
            let workItem = DispatchWorkItem {
                guard store.selectedNoteID == id else { return }
                proxy.scrollTo(id, anchor: .center)
                navigationTargetNoteID = nil
            }
            navigationScrollWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: workItem)
        }
    }
    }

    private func cancelPendingNavigation() {
        navigationScrollWorkItem?.cancel()
        navigationTargetNoteID = nil
    }

    /// Lock duration: WebView editor expansion settles within ~200ms.
    /// Longer locks make scroll feel unresponsive ("硬").
    private static let scrollLockDelays: [TimeInterval] = [0.0, 0.016, 0.05, 0.10, 0.18, 0.25]
    private static let scrollLockDuration: TimeInterval = 0.28

    private func preserveScrollDuringLocalSelection(_ update: @escaping () -> Void) {
        let scrollView = streamScrollView
        let originalOrigin = scrollView?.contentView.bounds.origin

        guard let scrollView, let originalOrigin else {
            update()
            return
        }

        localSelectionScrollLockGeneration += 1
        let generation = localSelectionScrollLockGeneration
        localSelectionScrollLockOrigin = originalOrigin
        localSelectionScrollLockDeadline = Date().addingTimeInterval(Self.scrollLockDuration)

        update()

        restoreScrollOrigin(originalOrigin, in: scrollView)
        for delay in Self.scrollLockDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard generation == localSelectionScrollLockGeneration else { return }
                restoreLocalSelectionScrollPosition()
                if delay >= Self.scrollLockDelays.last! {
                    clearLocalSelectionScrollLock(generation: generation)
                }
            }
        }
    }

    private func restoreLocalSelectionScrollPosition() {
        guard Date() <= localSelectionScrollLockDeadline,
              let origin = localSelectionScrollLockOrigin,
              let scrollView = streamScrollView else { return }
        restoreScrollOrigin(origin, in: scrollView)
    }

    private func clearLocalSelectionScrollLock(generation: Int? = nil) {
        if let generation, generation != localSelectionScrollLockGeneration { return }
        localSelectionScrollLockOrigin = nil
        localSelectionScrollLockDeadline = .distantPast
    }
}

@MainActor
private func restoreScrollOrigin(_ origin: CGPoint, in scrollView: NSScrollView) {
    scrollView.contentView.scroll(to: origin)
    scrollView.reflectScrolledClipView(scrollView.contentView)
}

private struct EnclosingScrollViewResolver: NSViewRepresentable {
    let onResolve: (NSScrollView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        resolve(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        resolve(from: nsView)
    }

    private func resolve(from view: NSView) {
        DispatchQueue.main.async {
            if let scrollView = view.enclosingScrollView {
                onResolve(scrollView)
            }
        }
    }
}

// MARK: - Card Title

private struct AgendadaCardTitle: View {
    let title: String
    @Binding var draftTitle: String
    let isSelected: Bool
    let isDimmed: Bool
    var highlightText: String = ""
    /// The UTF-16 range of the *current* search occurrence in this title, if any.
    /// Highlighted in orange to distinguish from other matches (yellow).
    var activeTitleRange: NSRange? = nil

    private var fgColor: Color {
        isDimmed ? .secondary : Color(red: 0.102, green: 0.102, blue: 0.102)
    }

    var body: some View {
        let showHighlight = !highlightText.isEmpty
        let nsHighlighted = showHighlight ? nsHighlightedTitle : nil

        return ZStack(alignment: .leading) {
            // Preview — shown when not selected; carries search highlights.
            if showHighlight {
                Text(highlightedTitle)
                    .font(AgendaFont.cardTitle)
                    .lineLimit(1)
                    .opacity(isSelected ? 0 : 1)
                    .allowsHitTesting(false)
            } else {
                Text(title.isEmpty ? "无标题" : title)
                    .font(AgendaFont.cardTitle)
                    .foregroundStyle(fgColor)
                    .lineLimit(1)
                    .opacity(isSelected ? 0 : 1)
                    .allowsHitTesting(false)
            }
            // Editor — shown when selected. When search is active, the text field
            // itself carries the yellow/orange highlight backgrounds.
            StableTextField(
                text: $draftTitle,
                placeholder: "无标题",
                font: NSFont(name: "Avenir Next", size: 20) ?? .systemFont(ofSize: 20),
                textColor: isDimmed ? .secondaryLabelColor : NSColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1),
                isEnabled: isSelected,
                highlightedText: nsHighlighted
            )
            .opacity(isSelected ? 1 : 0)
        }
    }

    /// 带搜索高亮的标题（预览模式）。
    /// All matches get yellow background; the current/active occurrence gets orange.
    private var highlightedTitle: AttributedString {
        let display = title.isEmpty ? "无标题" : title
        var attributed = AttributedString(display)
        attributed.foregroundColor = fgColor

        let keywords = highlightText
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !keywords.isEmpty else { return attributed }

        let nsDisplay = display as NSString
        let chars = String(attributed.characters)

        for keyword in keywords {
            var searchRange = NSRange(location: 0, length: nsDisplay.length)
            while searchRange.location < nsDisplay.length {
                let found = nsDisplay.range(of: keyword, options: .caseInsensitive, range: searchRange)
                guard found.location != NSNotFound else { break }

                let strStart = String.Index(utf16Offset: found.location, in: chars)
                let strEnd = String.Index(utf16Offset: found.location + found.length, in: chars)

                guard let attrStart = AttributedString.Index(strStart, within: attributed),
                      let attrEnd = AttributedString.Index(strEnd, within: attributed) else { break }

                // Orange for the current occurrence, yellow for others.
                let isActive = activeTitleRange.map { NSEqualRanges(found, $0) } ?? false
                attributed[attrStart..<attrEnd].backgroundColor = isActive
                    ? AgendaColor.amber.opacity(0.45)
                    : Color.yellow.opacity(0.4)

                searchRange.location = found.location + found.length
                searchRange.length = nsDisplay.length - searchRange.location
            }
        }
        return attributed
    }

    /// AppKit version of highlightedTitle — builds NSAttributedString with NSColor
    /// directly so NSTextField renders yellow/orange backgrounds correctly.
    private var nsHighlightedTitle: NSAttributedString {
        let display = title.isEmpty ? "无标题" : title
        let nsFg = isDimmed
            ? NSColor.secondaryLabelColor
            : NSColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1)

        let attr = NSMutableAttributedString(string: display, attributes: [
            .foregroundColor: nsFg,
            .font: NSFont(name: "Avenir Next", size: 20) ?? .systemFont(ofSize: 20)
        ])

        let keywords = highlightText.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !keywords.isEmpty else { return attr }

        let nsOrange = NSColor(red: 0.961, green: 0.651, blue: 0.137, alpha: 0.45)
        let nsYellow = NSColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.4)

        let nsDisplay = display as NSString
        for keyword in keywords {
            var searchRange = NSRange(location: 0, length: nsDisplay.length)
            while searchRange.location < nsDisplay.length {
                let found = nsDisplay.range(of: keyword, options: .caseInsensitive, range: searchRange)
                guard found.location != NSNotFound else { break }
                let isActive = activeTitleRange.map { NSEqualRanges(found, $0) } ?? false
                attr.addAttribute(.backgroundColor, value: isActive ? nsOrange : nsYellow, range: found)
                searchRange.location = found.location + found.length
                searchRange.length = nsDisplay.length - searchRange.location
            }
        }
        return attr
    }
}

// MARK: - Stable TextField (no focus-ring baseline shift)

private struct StableTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let font: NSFont
    let textColor: NSColor
    let isEnabled: Bool
    var highlightedText: NSAttributedString? = nil  // nil = plain text, non-nil = search highlights active

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.isBezeled = false
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.font = font
        tf.textColor = textColor
        tf.placeholderString = placeholder
        tf.lineBreakMode = .byTruncatingTail
        tf.cell?.isScrollable = false  // 禁止滚动，防止推宽布局
        tf.cell?.wraps = false
        // 降低水平抗压缩优先级，确保长标题不会撑宽卡片（卡片宽度由外层容器决定）
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tf.delegate = context.coordinator
        return tf
    }

    func updateNSView(_ tf: NSTextField, context: Context) {
        // When highlights are active, use attributedStringValue so the
        // yellow/orange backgrounds are visible in the text field itself.
        if let h = highlightedText {
            if !tf.attributedStringValue.isEqual(to: h) {
                tf.attributedStringValue = h
            }
        } else {
            if tf.stringValue != text || hasBackgroundHighlight(tf.attributedStringValue) {
                tf.stringValue = text
            }
        }
        tf.font = font
        tf.textColor = textColor
        tf.isEnabled = isEnabled
        tf.isSelectable = isEnabled
        tf.isEditable = isEnabled
    }

    private func hasBackgroundHighlight(_ attributedString: NSAttributedString) -> Bool {
        let fullRange = NSRange(location: 0, length: attributedString.length)
        var found = false
        attributedString.enumerateAttribute(.backgroundColor, in: fullRange) { value, _, stop in
            if value != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            let newValue = tf.stringValue
            guard newValue != text.wrappedValue else { return }
            text.wrappedValue = newValue
        }
    }
}

// MARK: - Search Results Mode

/// Renders search results as grouped snippets instead of full note cards.
private struct SearchResultsContentView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @Binding var navigationTargetNoteID: Note.ID?

    var body: some View {
        let groups = store.searchResultGroups()
        let summary = store.searchSummary
        let scopeLabel = searchScopeLabel

        VStack(alignment: .leading, spacing: 0) {
            // Summary header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("搜索结果：\(store.library.searchHighlightText)")
                        .font(AgendaFont.breadcrumbTitle)
                        .foregroundStyle(Color(red: 0.173, green: 0.173, blue: 0.180))
                    Spacer()
                    Text("\(summary.totalMatchedNotes) 篇笔记 · \(summary.totalOccurrences) 个命中")
                        .font(AgendaFont.cardMeta)
                        .foregroundStyle(AgendaColor.textMuted)
                }

                HStack(spacing: 8) {
                    Text(scopeLabel)
                        .font(AgendaFont.panelMicro)
                        .foregroundStyle(AgendaColor.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AgendaColor.sidebarBg, in: Capsule())

                    Spacer()

                    Button {
                        store.searchText = ""
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .semibold))
                            Text("退出搜索")
                                .font(AgendaFont.panelMicro)
                        }
                        .foregroundStyle(AgendaColor.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlColor), in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AgendaSpacing.cardPaddingH)
            .padding(.bottom, 14)

            ForEach(groups) { group in
                SearchResultGroupRow(
                    group: group,
                    highlightTerms: highlightTerms,
                    onSelectOccurrence: { occurrence in
                        selectOccurrence(occurrence)
                    }
                )
                .padding(.bottom, AgendaSpacing.cardGap)
            }
        }
    }

    private var searchScopeLabel: String {
        if let pid = store.selectedProjectID, let proj = store.project(withID: pid) {
            return "项目：\(proj.name)"
        }
        if store.selectedOverview == .trash { return "废纸篓" }
        if store.selectedOverview == .all { return "全部笔记" }
        if let ov = store.selectedOverview { return ov.title }
        return "当前范围"
    }

    private var highlightTerms: [String] {
        let raw = store.library.searchHighlightText
        return raw.split(separator: " ").map(String.init)
    }

    private func selectOccurrence(_ occurrence: SearchOccurrence) {
        store.selectNote(occurrence.noteID)
        navigationTargetNoteID = occurrence.noteID

        let query = store.library.searchHighlightText
        guard !query.isEmpty else { return }
        SharedBlockNoteWebView.shared.prepareSearchNavigation(
            noteID: occurrence.noteID,
            query: query,
            bodyIndex: occurrence.field == .body ? occurrence.bodyIndexInNote : 0
        )
    }
}

/// Zero-results state when committed search yields no matches.
private struct SearchNoResultsView: View {
    @Environment(ObservableLibraryStore.self) private var store
    let searchText: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AgendaColor.textMuted.opacity(0.5))

            Text("没有找到「\(searchText)」")
                .font(AgendaFont.panelSectionTitle)
                .foregroundStyle(AgendaColor.textMuted)

            VStack(spacing: 4) {
                Text("试试：")
                    .font(AgendaFont.panelCaption)
                    .foregroundStyle(AgendaColor.textMuted)
                if store.searchScope != .all {
                    Button {
                        store.searchScope = .all
                    } label: {
                        Text("搜索全部笔记")
                            .font(AgendaFont.panelCaption)
                            .foregroundStyle(AgendaColor.amber)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

private struct SearchResultGroupRow: View {
    @Environment(ObservableLibraryStore.self) private var store
    let group: SearchResultGroup
    let highlightTerms: [String]
    let onSelectOccurrence: (SearchOccurrence) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Note title + match count badge
            Button {
                if let first = group.occurrences.first {
                    onSelectOccurrence(first)
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(group.note.title.isEmpty ? "无标题" : group.note.title)
                        .font(AgendaFont.cardTitle)
                        .foregroundStyle(Color(red: 0.102, green: 0.102, blue: 0.102))
                        .lineLimit(1)

                    Text("\(group.occurrences.count)")
                        .font(.custom("Avenir Next Demi Bold", size: 9))
                        .foregroundStyle(AgendaColor.amber)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(AgendaColor.amber.opacity(0.12), in: Capsule())

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // Snippets (up to 3)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(group.snippets.prefix(3))) { snippet in
                    Button {
                        onSelectOccurrence(snippet.occurrence)
                    } label: {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: snippet.occurrence.field == .title ? "textformat" : "doc.text")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AgendaColor.amber)
                                .frame(width: 14)
                                .padding(.top, 1)

                            HighlightedText(
                                text: snippet.occurrence.excerpt,
                                terms: highlightTerms,
                                baseFont: AgendaFont.cardBodyCompact,
                                baseColor: AgendaColor.textMuted,
                                highlightColor: AgendaColor.amber
                            )
                            .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 28)
        }
        .padding(AgendaSpacing.cardPaddingV)
        .padding(.horizontal, AgendaSpacing.cardPaddingH)
        .background(Color.white, in: RoundedRectangle(cornerRadius: AgendaSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AgendaSpacing.cardRadius)
                .stroke(AgendaColor.cardBorder, lineWidth: 0.5)
        )
        .shadow(color: AgendaColor.cardShadow, radius: 4, y: 2)
        .padding(.horizontal, 12)
    }
}

/// Renders text with case-insensitive term highlighting using AttributedString.
private struct HighlightedText: View {
    let text: String
    let terms: [String]
    let baseFont: Font
    let baseColor: Color
    let highlightColor: Color

    var body: some View {
        if terms.isEmpty {
            Text(text)
                .font(baseFont)
                .foregroundStyle(baseColor)
        } else {
            Text(attributedText)
        }
    }

    private var attributedText: AttributedString {
        let nsString = text as NSString
        var result = AttributedString(text)
        result.font = baseFont
        result.foregroundColor = baseColor

        for term in terms {
            guard let regex = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: term), options: .caseInsensitive) else { continue }
            let fullRange = NSRange(location: 0, length: nsString.length)
            for match in regex.matches(in: text, range: fullRange) {
                guard match.range.lowerBound < nsString.length,
                      match.range.upperBound <= nsString.length else { continue }
                let lower = String.Index(utf16Offset: match.range.lowerBound, in: text)
                let upper = String.Index(utf16Offset: match.range.upperBound, in: text)
                if let range = Range(lower..<upper, in: result) {
                    result[range].backgroundColor = highlightColor.opacity(0.25)
                    result[range].foregroundColor = Color(red: 0.2, green: 0.2, blue: 0.2)
                }
            }
        }
        return result
    }
}

// MARK: - Note Row

private struct StreamNoteRow: View {
    @Environment(ObservableLibraryStore.self) private var store
    let note: Note
    let cancelPendingNavigation: () -> Void
    let performLocalSelection: (@escaping () -> Void) -> Void
    let preserveLocalScrollPosition: () -> Void
    var onNavigateToNote: ((Note.ID) -> Void)?

    @State private var draft: StreamNoteDraft
    @State private var initialDraft: StreamNoteDraft
    @State private var saveTask: Task<Void, Never>?
    @State private var editorHeight: CGFloat = 0
    @State private var capturedPreviewHeight: CGFloat = 0
    @State private var editorHasUserChanges = false
    @State private var editorIsVisible = false
    @State private var initialBlockJSON: Data?
    @State private var skipNextCardTap = false

    /// Local mirror of selection state so only the two affected cards
    /// re-render when selection changes, instead of every visible card
    /// re-reading store.selectedNoteID via observeRevision().
    @State private var isLocalSelected: Bool

    init(
        note: Note,
        cancelPendingNavigation: @escaping () -> Void = {},
        performLocalSelection: @escaping (@escaping () -> Void) -> Void = { update in update() },
        preserveLocalScrollPosition: @escaping () -> Void = {},
        onNavigateToNote: ((Note.ID) -> Void)? = nil
    ) {
        self.note = note
        self.cancelPendingNavigation = cancelPendingNavigation
        self.performLocalSelection = performLocalSelection
        self.preserveLocalScrollPosition = preserveLocalScrollPosition
        self.onNavigateToNote = onNavigateToNote
        let d = StreamNoteDraft(note: note)
        _draft = State(initialValue: d)
        _initialDraft = State(initialValue: d)
        _isLocalSelected = State(initialValue: false)
    }

    private var isSelected: Bool { isLocalSelected }

    /// Sync local selection state when store.selectedNoteID changes.
    /// This lets us avoid reading store.selectedNoteID in body (which would
    /// force every visible card to re-render via observeRevision).
    private func syncSelectionFromStore() {
        let shouldBeSelected = store.selectedNoteID == note.id
        if isLocalSelected != shouldBeSelected {
            isLocalSelected = shouldBeSelected
        }
    }
    private let bulletCol: CGFloat = 24



    /// The active (orange) match range for this note's title, if the current
    /// search occurrence is a title match in this note.
    private var activeTitleRange: NSRange? {
        guard let occ = store.currentOccurrence,
              occ.noteID == note.id,
              occ.field == .title else { return nil }
        return NSRange(location: occ.matchPosition, length: occ.matchLength)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 10) {
            bulletIcon.frame(width: bulletCol, alignment: .leading).padding(.top, 1)
            HStack(alignment: .firstTextBaseline) {
                AgendadaCardTitle(
                    title: note.title,
                    draftTitle: $draft.title,
                    isSelected: isSelected,
                    isDimmed: isNoteDimmed,
                    highlightText: store.library.searchHighlightText,
                    activeTitleRange: activeTitleRange
                )
                Spacer(minLength: 8)
                dateControl
            }
            .frame(maxWidth: .infinity)  // 确保整个 HStack 不超过容器宽度
        }
    }

    @ViewBuilder
    private var dateControl: some View {
        StreamNoteDateControlView(
            note: note,
            isSelected: isSelected,
            dateLabel: dateLabel,
            dateFontName: dateFontName,
            dateColor: dateColor
        )
    }

    /// Core card content without hover/drop decorations.
    /// Hover overlays, drag handle, drop indicators, draggable/dropDestination
    /// are applied by CardInteractionLayer which owns isHovering/isDropTargeted
    /// to avoid invalidating the full row on mouse events.
    var cardBase: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            bodyContent.padding(.top, 6)
            }
        .padding(.horizontal, 20).padding(.vertical, 16).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? AgendaColor.cardActiveFill : .clear))
        .overlay(alignment: .bottomTrailing) {
            if isSelected {
                actionMenu.padding(12)
            } else if !store.isInBatchMode {
                Text(relativeEditedAt)
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(AgendaColor.textMuted)
                    .padding(12)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? AgendaColor.cardActiveBorder : .clear, lineWidth: 0.75))
        .shadow(color: isSelected ? .black.opacity(0.04) : .clear, radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20).contentShape(Rectangle())
        .contextMenu { contextMenuContent }
    }

    private var dragPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title.isEmpty ? "无标题" : note.title)
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(Color(red: 0.102, green: 0.102, blue: 0.102))
                .lineLimit(1)
            Text(note.bodyPlainText)
                .font(.custom("Avenir Next", size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 240)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        )
    }



    var body: some View {
        CardInteractionLayer(
            note: note,
            isSelected: isSelected,
            canDrag: !store.isInBatchMode && store.selectedOverview != .trash,
            onTap: handleCardTap,
            onBeforeDrop: { flushDraft() },
            onPinBoundaryCrossing: { draggedID, targetID, insertBefore in
                handlePinBoundaryCrossing(draggedNoteID: draggedID, targetNoteID: targetID, insertBefore: insertBefore)
            }
        ) {
            cardBase
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            // Subviews (bullet menu, action menu) handle their own dismiss on resign.
        }
        .onChange(of: draft.title) { scheduleSaveDraft() }
        .onChange(of: draft.hasScheduledDate) { scheduleSaveDraft() }
        .onChange(of: draft.scheduledDate) { scheduleSaveDraft() }
        .onChange(of: draft.tagsText) { scheduleSaveDraft() }
        .onChange(of: draft.peopleText) { scheduleSaveDraft() }
        .onChange(of: draft.status) { scheduleSaveDraft() }
        .onChange(of: editorHeight) { _, _ in
            if isSelected { preserveLocalScrollPosition() }
        }
        .onChange(of: store.selectedNoteID) { oldValue, newValue in
            syncSelectionFromStore()
            if oldValue == note.id && newValue != note.id {
                flushDraft()
                editorHeight = 0
                editorIsVisible = false
            } else if newValue == note.id {
                resetDraft()
                prepareEditorOverlayForSelection()
                preserveLocalScrollPosition()
            }
        }
        .onAppear {
            syncSelectionFromStore()
        }
        .onChange(of: note.id) {
            resetDraft()
        }
        .onDisappear {
            flushDraft()
        }
    }

    // MARK: - Body

    private var bodyContent: some View {
        // Use minHeight to prevent clipping content when preview hasn't been
        // measured yet (capturedPreviewHeight = 0). The preview always renders
        // at its natural height via .fixedSize, and the ZStack expands to fit.
        // Once measured, minHeight locks the card size to prevent the editor
        // from shrinking below the preview height during the transition.
        let minH: CGFloat? = capturedPreviewHeight > 0 ? capturedPreviewHeight : nil

        return ZStack(alignment: .topLeading) {
            // Preview — always present, measures its natural height for card sizing.
            BlockNotePreviewView(note: note, highlightText: store.library.searchHighlightText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .opacity(isSelected && editorIsVisible ? 0 : (isNoteDimmed ? 0.58 : 1))
                .allowsHitTesting(false)
                .when(isSelected) { view in
                    view
                        .overlay(
                            GeometryReader { geo in
                                Color.clear
                                    .allowsHitTesting(false)
                                    .preference(key: PreviewHeightKey.self, value: geo.size.height)
                            }
                        )
                        .onPreferenceChange(PreviewHeightKey.self) { h in
                            if h > 0, abs(capturedPreviewHeight - h) > 0.5 {
                                capturedPreviewHeight = h
                            }
                        }
                }

            // Editor — only rendered when selected to skip WKWebView layout.
            if isSelected {
                BlockNoteCardEditor(
                    noteID: note.id,
                    blockJSON: draft.blockJSON,
                    editorHeight: $editorHeight,
                    onChange: { content in applyEditorContent(content) },
                    onDebouncedSave: { content in
                        applyEditorContent(content)
                        if editorHasUserChanges { saveDraft() }
                    },
                    onReady: {
                        editorIsVisible = true
                        preserveLocalScrollPosition()
                        SharedBlockNoteWebView.shared.focusEditor()
                        // Find in Note 优先于 List Search
                        if let findPending = store.library.consumeFindInNoteNavigation(for: note.id) {
                            SharedBlockNoteWebView.shared.clearSearch()
                            let hlText = NoteSearchEngine.highlightText(for: findPending.query)
                            guard !hlText.isEmpty else { return }
                            SharedBlockNoteWebView.shared.searchInEditor(query: hlText) { _ in
                                SharedBlockNoteWebView.shared.navigateToMatch(index: findPending.bodyIndex) { _, _ in }
                            }
                        } else if let pending = SharedBlockNoteWebView.shared.consumeSearchNavigation(for: note.id),
                           !pending.query.isEmpty {
                            SharedBlockNoteWebView.shared.searchInEditor(query: pending.query) { _ in
                                SharedBlockNoteWebView.shared.navigateToMatch(index: pending.bodyIndex) { _, _ in }
                            }
                        }
                    },
                    onNoteLinkSearch: { query, excludeNoteID in
                        let allNotes = store.filteredNotes()
                        let filtered = allNotes.filter { note in
                            if let excludeID = excludeNoteID, note.id == excludeID { return false }
                            return note.title.localizedCaseInsensitiveContains(query)
                                || note.bodyPlainText.localizedCaseInsensitiveContains(query)
                        }
                        return Array(filtered.prefix(8).map { note in
                            let projectName = store.project(withID: note.projectID)?.name ?? ""
                            return NoteLinkSearchResult(id: note.id, title: note.title, project: projectName)
                        })
                    },
                    onNoteLinkNavigate: { targetNoteID in
                        store.selectNote(targetNoteID)
                        onNavigateToNote?(targetNoteID)
                    }
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(minHeight: minH, alignment: .top)
                .opacity(editorIsVisible ? (isNoteDimmed ? 0.58 : 1) : 0)
                .overlay(alignment: .top) {
                    if store.isFindInNoteBarVisible && note.id == store.selectedNoteID {
                        FindInNoteBar()
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: store.isFindInNoteBarVisible)
            }
        }
        .frame(minHeight: minH, alignment: .top)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .padding(.bottom, 60)
        .onChange(of: editorFindRenderKey) { _, _ in
            guard note.id == store.selectedNoteID else { return }
            let findText = store.findInNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !findText.isEmpty, store.findInNoteOccurrences.count > 0 else {
                SharedBlockNoteWebView.shared.clearSearch()
                return
            }
            let q = NoteSearchEngine.highlightText(for: findText)
            guard !q.isEmpty else { return }
            SharedBlockNoteWebView.shared.searchInEditor(query: q) { _ in
                let idx = store.currentFindInNoteIndex ?? 0
                SharedBlockNoteWebView.shared.navigateToMatch(index: idx) { _, _ in }
            }
        }
    }

    /// Stable key for Find in Note WebView highlight refresh.
    /// Lives here in the editor row so it fires regardless of
    /// whether SearchPopoverContent is mounted.
    private var editorFindRenderKey: String {
        [
            store.findInNoteText,
            store.selectedNoteID?.uuidString ?? "",
            "\(store.currentFindInNoteIndex ?? -1)",
            "\(store.findInNoteOccurrences.count)"
        ].joined(separator: "|")
    }

    // MARK: - Bullet

    private var bulletIcon: some View {
        StreamNoteBulletMenuView(
            note: note,
            isSelected: isSelected,
            noteColor: noteColorValue(note.noteColor),
            onMenuAction: { skipNextCardTap = true }
        )
    }


    func handleCardTap() {
        cancelPendingNavigation()
        SharedBlockNoteWebView.shared.clearPendingSearchNavigation()

        if skipNextCardTap {
            skipNextCardTap = false
            return
        }
        if store.isInBatchMode {
            store.toggleBatchSelection(noteID: note.id)
        } else if store.selectedOverview != .trash {
            selectNoteAfterSavingActiveEditor()
        }
    }



    private func copyAsFloatingMenuSections() -> [AgendadaFloatingMenuSection] {
        [
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconText: "RTF",
                    title: "笔记文本"
                ) { _ in
                    copyToPasteboard(fullNoteText)
                },
                AgendadaFloatingMenuItem(
                    iconText: "M↓",
                    title: "Markdown"
                ) { _ in
                    copyToPasteboard(markdownNoteText)
                },
                AgendadaFloatingMenuItem(
                    iconText: "<>",
                    title: "HTML"
                ) { _ in
                    copyToPasteboard(htmlNoteText)
                },
                AgendadaFloatingMenuItem(
                    iconText: "txt",
                    title: "纯文本"
                ) { _ in
                    copyToPasteboard(fullNoteText)
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "doc.text",
                    title: "摘要"
                ) { _ in
                    copyToPasteboard(store.summary(for: note.id) ?? note.bodyPlainText)
                }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "link",
                    title: "Agenda 链接"
                ) { _ in
                    copyToPasteboard(agendaNoteLink)
                }
            ])
        ]
    }

    private func shareAsFloatingMenuSections() -> [AgendadaFloatingMenuSection] {
        [
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "dot.radiowaves.left.and.right",
                    title: "隔空投送"
                ) { _ in
                    shareNote()
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "envelope.fill",
                    title: "通过邮件发送"
                ) { _ in
                    shareNote()
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "message.fill",
                    title: "通过“信息”App 发送"
                ) { _ in
                    shareNote()
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "note.text",
                    title: "添加到“备忘录”"
                ) { _ in
                    shareNote()
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "folder",
                    title: "另存为"
                ) { _ in
                    shareNote()
                }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "iphone",
                    title: "Simulator"
                ) { _ in
                    shareNote()
                },
                AgendadaFloatingMenuItem(
                    iconText: "微",
                    title: "发送到微信"
                ) { _ in
                    shareNote()
                },
                AgendadaFloatingMenuItem(
                    iconText: "手",
                    title: "手记"
                ) { _ in
                    shareNote()
                },
                AgendadaFloatingMenuItem(
                    iconText: "无",
                    title: "无边记"
                ) { _ in
                    shareNote()
                }
            ])
        ]
    }

    private func noteInfoFloatingMenuSections() -> [AgendadaFloatingMenuSection] {
        [
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    title: "统计:",
                    subtitle: noteStatisticsText,
                    isHeader: true,
                    dismissesAfterAction: false
                ) { _ in },
                AgendadaFloatingMenuItem(
                    title: "阅读时间:",
                    subtitle: noteReadingTimeText,
                    isHeader: true,
                    dismissesAfterAction: false
                ) { _ in }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    title: "创建于:",
                    subtitle: noteCreatedAtText,
                    isHeader: true,
                    dismissesAfterAction: false
                ) { _ in }
            ])
        ]
    }

    private var editedAtInfoSubtitle: String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "zh_CN")
        timeFormatter.dateFormat = "HH:mm"
        let timeText = timeFormatter.string(from: note.editedAt)

        if calendar.isDateInToday(note.editedAt) {
            return "最近编辑时间： 今天 \(timeText)"
        }
        if calendar.isDateInYesterday(note.editedAt) {
            return "最近编辑时间： 昨天 \(timeText)"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "M月d日"
        return "最近编辑时间： \(dateFormatter.string(from: note.editedAt)) \(timeText)"
    }

    private var fullNoteText: String {
        [note.title, note.bodyPlainText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private var markdownNoteText: String {
        let body = note.bodyPlainText.trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? "# \(note.title)" : "# \(note.title)\n\n\(body)"
    }

    private var htmlNoteText: String {
        let title = escapedHTML(note.title)
        let body = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty {
            return "<h1>\(title)</h1><p>\(escapedHTML(note.bodyPlainText))</p>"
        }
        return "<h1>\(title)</h1>\n\(body)"
    }

    private var agendaNoteLink: String {
        "agendada://note/\(note.id.uuidString)"
    }

    private var noteStatisticsText: String {
        let text = note.bodyPlainText.trimmingCharacters(in: .whitespacesAndNewlines)
        let characterCount = text.count
        let withoutSpaces = text.filter { !$0.isWhitespace }.count
        let paragraphs = text
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
        return "\(withoutSpaces)个字、\(characterCount)个字符 (\(withoutSpaces) without spaces)、\(max(paragraphs, text.isEmpty ? 0 : 1))个段落"
    }

    private var noteReadingTimeText: String {
        let characters = note.bodyPlainText.filter { !$0.isWhitespace }.count
        let minutes = Int(ceil(Double(characters) / 500.0))
        return minutes <= 1 ? "不足一分钟" : "约 \(minutes) 分钟"
    }

    private var noteCreatedAtText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm:ss"
        return formatter.string(from: note.createdAt)
    }

    private func escapedHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func pinFloatingMenuSections() -> [AgendadaFloatingMenuSection] {
        [
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: note.pinState == .pinnedTop ? "pin.slash" : "pin",
                    title: note.pinState == .pinnedTop ? "取消置顶" : "置顶"
                ) { _ in
                    store.setPinState(note.pinState == .pinnedTop ? .none : .pinnedTop, noteID: note.id)
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: note.pinState == .pinnedBottom ? "arrow.up.to.line" : "arrow.down.to.line",
                    title: note.pinState == .pinnedBottom ? "取消置底" : "置底"
                ) { _ in
                    store.setPinState(note.pinState == .pinnedBottom ? .none : .pinnedBottom, noteID: note.id)
                }
            ])
        ]
    }

    private func markFloatingMenuSections() -> [AgendadaFloatingMenuSection] {
        [
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: note.isBrief ? "circle" : "smallcircle.fill.circle",
                    title: note.isBrief ? "取消“简达”" : "标记为“简达”"
                ) { _ in
                    store.setBrief(!note.isBrief, noteID: note.id)
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: note.status == .completed ? "arrow.uturn.left" : "checkmark",
                    title: note.status == .completed ? "标记为未完成" : "标记为已完成"
                ) { _ in
                    store.setStatus(note.status == .completed ? .open : .completed, noteID: note.id)
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "square.fill",
                    title: "使用颜色标记",
                    showsSubmenuIndicator: true,
                    dismissesAfterAction: false
                ) { presenter in
                    presenter.showSubmenu(sections: colorFloatingMenuSections())
                }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: note.pinState == .pinnedTop ? "pin.slash" : "pin",
                    title: note.pinState == .pinnedTop ? "取消置顶" : "置顶"
                ) { _ in
                    store.setPinState(note.pinState == .pinnedTop ? .none : .pinnedTop, noteID: note.id)
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: note.pinState == .pinnedBottom ? "arrow.up.to.line" : "arrow.down.to.line",
                    title: note.pinState == .pinnedBottom ? "取消置底" : "置底"
                ) { _ in
                    store.setPinState(note.pinState == .pinnedBottom ? .none : .pinnedBottom, noteID: note.id)
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: note.isCollapsed ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left",
                    title: note.isCollapsed ? "展开笔记" : "折叠笔记"
                ) { _ in
                    store.setCollapsed(!note.isCollapsed, noteID: note.id)
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "lock.fill",
                    title: "锁定笔记...",
                    isEnabled: false
                ) { _ in }
            ])
        ]
    }

    private func colorFloatingMenuSections() -> [AgendadaFloatingMenuSection] {
        let colorItems = [AgendadaFloatingMenuItem(
            iconColor: nil,
            title: "无颜色"
        ) { _ in
            store.setNoteColor(nil, noteID: note.id)
        }] + NoteColor.allCases.map { color in
            AgendadaFloatingMenuItem(
                iconColor: noteColorValue(color),
                title: color.title
            ) { _ in
                store.setNoteColor(color, noteID: note.id)
            }
        }

        return [AgendadaFloatingMenuSection(items: colorItems)]
    }

    private func moveProjectFloatingMenuSections() -> [AgendadaFloatingMenuSection] {
        var sections: [AgendadaFloatingMenuSection] = [
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "arrow.up",
                    title: "上一条笔记前"
                ) { _ in
                    moveWithPinCheck(.beforePrevious)
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "arrow.down",
                    title: "下一条笔记后"
                ) { _ in
                    moveWithPinCheck(.afterNext)
                }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "arrow.up.to.line",
                    title: "第一条笔记前"
                ) { _ in
                    moveWithPinCheck(.toFirst)
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "arrow.down.to.line",
                    title: "最后一条笔记后"
                ) { _ in
                    moveWithPinCheck(.toLast)
                }
            ])
        ]

        var projectItems: [AgendadaFloatingMenuItem] = [
            AgendadaFloatingMenuItem(
                title: "其他项目:",
                isHeader: true,
                dismissesAfterAction: false
            ) { _ in }
        ]

        for category in store.categories {
            let projects = store.projects(in: category.id).filter { !$0.isArchived }
            guard !projects.isEmpty else { continue }
            projectItems.append(
                AgendadaFloatingMenuItem(
                    title: category.name,
                    isEnabled: false,
                    dismissesAfterAction: false
                ) { _ in }
            )
            projectItems.append(contentsOf: projects.map(projectMoveMenuItem))
        }

        let uncategorizedProjects = store.projects
            .filter { $0.categoryID == nil && !$0.isArchived }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if !uncategorizedProjects.isEmpty {
            projectItems.append(
                AgendadaFloatingMenuItem(
                    title: "其他项目",
                    isEnabled: false,
                    dismissesAfterAction: false
                ) { _ in }
            )
            projectItems.append(contentsOf: uncategorizedProjects.map(projectMoveMenuItem))
        }

        if projectItems.count > 1 {
            sections.append(AgendadaFloatingMenuSection(items: projectItems))
        }

        sections.append(
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "folder.badge.plus",
                    title: "新建项目..."
                ) { _ in
                    store.addProject(name: "新项目", categoryID: nil)
                }
            ])
        )

        return sections
    }

    private func projectMoveMenuItem(_ project: Project) -> AgendadaFloatingMenuItem {
        AgendadaFloatingMenuItem(
            iconColor: projectColorValue(project.color),
            title: project.name
        ) { _ in
            store.moveNotes([note.id], toProject: project.id)
        }
    }

    private var isNoteDimmed: Bool { note.status == .completed || note.status == .closed }

    // MARK: - Date

    // MARK: - Static DateFormatters (avoid per-render allocation)
    private static let dateLabelFormatter: DateFormatter = {
        let fm = DateFormatter()
        fm.locale = Locale(identifier: "zh_CN")
        fm.dateFormat = "M月d日 EEEE"
        return fm
    }()

    private static let editedAtFormatter: DateFormatter = {
        let fm = DateFormatter()
        fm.locale = Locale(identifier: "zh_CN")
        fm.dateFormat = "M月d日"
        return fm
    }()

    /// Date label color. Hover sensitivity is handled inside StreamNoteDateControlView.
    private var dateColor: Color {
        (isSelected || isToday) ? AgendaColor.amber : AgendaColor.textMuted
    }

    /// Date label font. Hover sensitivity is handled inside StreamNoteDateControlView.
    private var dateFontName: String {
        (isSelected || isToday) ? "Avenir Next Medium" : "Avenir Next"
    }

    private var dateLabel: String {
        guard let d = draft.hasScheduledDate ? draft.scheduledDate : note.scheduledDate else { return "" }
        if Calendar.current.isDateInToday(d) { return "今天" }
        if Calendar.current.isDateInTomorrow(d) { return "明天" }
        if Calendar.current.isDateInYesterday(d) { return "昨天" }
        return Self.dateLabelFormatter.string(from: d)
    }
    private var isToday: Bool {
        guard let d = draft.hasScheduledDate ? draft.scheduledDate : note.scheduledDate else { return false }
        return Calendar.current.isDateInToday(d)
    }

    // MARK: - Edited At

    private var relativeEditedAt: String {
        let interval = Date().timeIntervalSince(note.editedAt)
        if interval < 0 { return "刚刚" }
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60)) 分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600)) 小时前" }
        if interval < 172800 { return "昨天" }
        if interval < 604800 { return "\(Int(interval / 86400)) 天前" }
        return Self.editedAtFormatter.string(from: note.editedAt)
    }

    // MARK: - Action Menu

    private var actionMenu: some View {
        HStack(spacing: 12) {
            Button { store.duplicateNote(note.id) } label: {
                Image(systemName: "doc.on.doc").font(.system(size: 16, weight: .medium))
            }.buttonStyle(.plain).help("复制笔记")
            StreamNoteActionMenuView(
                note: note,
                isSelected: isSelected,
                onMenuWillOpen: { skipNextCardTap = true }
            )
        }.foregroundStyle(AgendaColor.amber)
    }

    private func shareNote() {
        let content = "\(note.title)\n\n\(note.bodyPlainText)"
        let picker = NSSharingServicePicker(items: [content])
        if let contentView = NSApp.keyWindow?.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }

    private func moveWithPinCheck(_ move: PositionMove) {
        // Check: non-pinned note trying to enter pinned-top territory
        if store.wouldCrossPinnedTopBoundary(note.id, move: move) {
            showPinAndMoveAlert(move)
            return
        }

        // Check: pinned-top note trying to leave pinned territory
        if store.wouldLeavePinnedTopBoundary(note.id, move: move) {
            showUnpinAndMoveAlert(move)
            return
        }

        store.moveNote(note.id, to: move)
    }

    private func showPinAndMoveAlert(_ move: PositionMove) {
        let alert = NSAlert()
        alert.messageText = "是否要将当前笔记置顶？"
        alert.informativeText = "该笔记上方有置顶笔记，需要先将当前笔记置顶才能移动到此位置。"
        alert.alertStyle = .informational

        alert.addButton(withTitle: "置顶并移动")
        if move == .toFirst {
            alert.addButton(withTitle: "除置顶外的第一条前")
        }
        alert.addButton(withTitle: "取消")

        guard let window = NSApp.keyWindow else { return }
        alert.beginSheetModal(for: window) { response in
            switch response {
            case .alertFirstButtonReturn:
                store.pinAndMoveNote(note.id, to: move)
            case .alertSecondButtonReturn:
                if move == .toFirst {
                    store.moveToFirstNonPinned(note.id)
                }
            default:
                break
            }
        }
    }

    private func showUnpinAndMoveAlert(_ move: PositionMove) {
        let alert = NSAlert()
        alert.messageText = "是否取消置顶？"
        alert.informativeText = "该笔记当前置顶，需要先取消置顶才能移动到此位置。"
        alert.alertStyle = .informational

        alert.addButton(withTitle: "取消置顶并移动")
        alert.addButton(withTitle: "取消")

        guard let window = NSApp.keyWindow else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            store.setPinState(.none, noteID: note.id)
            store.moveNote(note.id, to: move)
        }
    }

    /// Handle a pin boundary crossing detected during drag-and-drop.
    private func handlePinBoundaryCrossing(draggedNoteID: Note.ID, targetNoteID: Note.ID, insertBefore: Bool) {
        let crossing = store.pinBoundaryCrossing(draggedNoteID: draggedNoteID, targetNoteID: targetNoteID)
        guard crossing != .none else { return }

        let alert = NSAlert()
        alert.alertStyle = .informational

        switch crossing {
        case .intoPinnedTop:
            alert.messageText = "是否要将当前笔记置顶？"
            alert.informativeText = "该笔记将被置顶并移动到此位置。"
            alert.addButton(withTitle: "置顶并移动")
        case .outOfPinnedTop:
            alert.messageText = "是否取消置顶？"
            alert.informativeText = "该笔记将取消置顶并移动到此位置。"
            alert.addButton(withTitle: "取消置顶并移动")
        case .none:
            return
        }
        alert.addButton(withTitle: "取消")

        guard let window = NSApp.keyWindow else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            switch crossing {
            case .intoPinnedTop:
                store.setPinState(.pinnedTop, noteID: draggedNoteID)
            case .outOfPinnedTop:
                store.setPinState(.none, noteID: draggedNoteID)
            case .none:
                break
            }
            if insertBefore {
                store.insertNoteBefore(draggedNoteID, targetID: targetNoteID)
            } else {
                store.insertNoteAfter(draggedNoteID, targetID: targetNoteID)
            }
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button("复制链接") {
            copyToPasteboard(agendaNoteLink)
        }
        Button("复制为 Markdown") {
            flushDraft()
            copyToPasteboard(markdownNoteText)
        }
        Button("复制为纯文本") {
            flushDraft()
            copyToPasteboard(fullNoteText)
        }
        Button("复制摘要") {
            if let s = store.summary(for: note.id) { copyToPasteboard(s) }
        }
        Divider()
        Button("保存为模板...") {
            flushDraft()
            saveAsTemplate(from: note, store: store)
        }
        Button("复制笔记") { store.duplicateNote(note.id) }
        Button("指定到今天") { store.scheduleToday(noteID: note.id) }
        Divider()
        Button(note.status == .completed ? "标记为未完成" : "标记为已完成") {
            store.setStatus(note.status == .completed ? .open : .completed, noteID: note.id)
        }
        Button(note.status == .closed ? "取消归档" : "归档笔记") {
            store.setStatus(note.status == .closed ? .open : .closed, noteID: note.id)
        }
        Button(note.isBrief ? "取消简达" : "标记为简达") {
            store.setBrief(!note.isBrief, noteID: note.id)
        }
        Button(note.pinState == .pinnedTop ? "取消置顶" : "置顶") {
            store.setPinState(note.pinState == .pinnedTop ? .none : .pinnedTop, noteID: note.id)
        }
        Button(note.pinState == .pinnedBottom ? "取消置底" : "置底") {
            store.setPinState(note.pinState == .pinnedBottom ? .none : .pinnedBottom, noteID: note.id)
        }
        Divider()
        Button("删除笔记", role: .destructive) { store.deleteNote(note.id) }
    }

    // MARK: - Save/Draft

    private func saveDraft() {
        saveTask?.cancel(); saveTask = nil
        let sd = draft.hasScheduledDate ? draft.scheduledDate : nil
        store.updateNote(noteID: note.id, title: draft.title, body: draft.body,
                         blockJSON: draft.blockJSON,
                         plainTextPreview: draft.plainTextPreview,
                         previewHTML: draft.previewHTML,
                         scheduledDate: sd, tags: splitList(draft.tagsText),
                         people: splitList(draft.peopleText), status: draft.status)
        initialDraft = draft
        initialBlockJSON = draft.blockJSON
        editorHasUserChanges = false
        SharedBlockNoteWebView.shared.hasContentChanges = false
    }

    private func scheduleSaveDraft() {
        if draft == initialDraft { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { saveDraft() }
        }
    }

    private func flushDraft() { if saveTask != nil { saveDraft() } }

    private func resetDraft() {
        saveTask?.cancel(); saveTask = nil
        if let refreshed = store.note(withID: note.id) {
            draft = StreamNoteDraft(note: refreshed)
            initialDraft = draft
        }
    }

    private func prepareEditorOverlayForSelection() {
        editorHasUserChanges = false
        editorIsVisible = false
        initialBlockJSON = draft.blockJSON
        // Do NOT reset heights - let them be updated naturally
    }

    private func applyEditorContent(_ content: BlockNoteEditorContent) {
        guard content.noteID == note.id else { return }
        if content.blockJSON != initialBlockJSON {
            editorHasUserChanges = true
        }
        SharedBlockNoteWebView.shared.hasContentChanges = true
        draft.blockJSON = content.blockJSON
        draft.plainTextPreview = content.plainTextPreview
        draft.previewHTML = content.previewHTML
        draft.body = content.previewHTML ?? content.plainTextPreview
        scheduleSaveDraft()
    }

    private func selectNoteAfterSavingActiveEditor() {
        guard store.selectedNoteID != note.id else { return }

        let selectionGeneration = SharedBlockNoteWebView.shared.beginSelectionRequest()
        let commitSelection = {
            guard SharedBlockNoteWebView.shared.isCurrentSelectionRequest(selectionGeneration) else { return }
            cancelPendingNavigation()
            performLocalSelection {
                prepareEditorOverlayForSelection()
                store.selectNote(note.id)
            }
        }

        guard SharedBlockNoteWebView.shared.hasContentChanges else {
            commitSelection()
            return
        }

        SharedBlockNoteWebView.shared.saveCurrentContentNow { content in
            if let content, let activeNote = store.note(withID: content.noteID) {
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
            }

            commitSelection()
        }
    }

    private func splitList(_ text: String) -> [String] { splitCommaList(text) }
}

private struct PreviewHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Supporting Types

private struct StreamNoteDraft: Equatable {
    var title: String
    var body: String
    var blockJSON: Data
    var plainTextPreview: String
    var previewHTML: String?
    var hasScheduledDate: Bool
    var scheduledDate: Date?
    var tagsText: String
    var peopleText: String
    var status: NoteStatus

    init(note: Note) {
        title = note.title
        body = note.body
        blockJSON = note.blockJSON
        plainTextPreview = note.plainTextPreview
        previewHTML = note.previewHTML
        hasScheduledDate = note.scheduledDate != nil
        scheduledDate = note.scheduledDate ?? Date()
        tagsText = note.tags.joined(separator: ", ")
        peopleText = note.people.joined(separator: ", ")
        status = note.status
    }
}

// MARK: - Hoverable Circle Button

private struct HoverableCircleButton: View {
    let systemName: String
    let help: String
    let role: ButtonRole?
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let action: () -> Void
    @State private var isHovering = false

    init(systemName: String, help: String = "", role: ButtonRole? = nil, fontSize: CGFloat = 16, fontWeight: Font.Weight = .medium, action: @escaping () -> Void) {
        self.systemName = systemName
        self.help = help
        self.role = role
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.system(size: fontSize, weight: fontWeight))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovering ? AgendaColor.amber : (role == .destructive ? .red : Color(red: 0.118, green: 0.118, blue: 0.118)))
        .background(Color.white, in: Circle())
        .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        .help(help)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Capsule Icon Button (for grouped buttons)

private struct CapsuleIconButton: View {
    let systemName: String
    let help: String
    let role: ButtonRole?
    let action: () -> Void
    let hoverEffect: HoverEffect
    @State private var isHovering = false
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1

    init(systemName: String, help: String = "", role: ButtonRole? = nil, hoverEffect: HoverEffect = .none, action: @escaping () -> Void) {
        self.systemName = systemName
        self.help = help
        self.role = role
        self.hoverEffect = hoverEffect
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            ZStack {
                if hoverEffect == .trashLid {
                    // 垃圾桶开盖效果 - 悬浮时从 outline 变 fill
                    Image(systemName: isHovering ? "trash.fill" : "trash")
                        .font(.system(size: 16, weight: .medium))
                        .transition(.opacity)
                } else if hoverEffect == .scale {
                    Image(systemName: systemName)
                        .font(.system(size: 16, weight: .medium))
                        .scaleEffect(scale)
                } else if hoverEffect == .rotate {
                    Image(systemName: systemName)
                        .font(.system(size: 16, weight: .medium))
                        .rotationEffect(.degrees(rotation))
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovering ? AgendaColor.amber : (role == .destructive ? .red : Color(red: 0.118, green: 0.118, blue: 0.118)))
        .help(help)
        .onHover { hovering in
            isHovering = hovering
            switch hoverEffect {
            case .rotate:
                withAnimation(.easeInOut(duration: 0.3)) {
                    rotation = hovering ? 180 : 0
                }
            case .scale:
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = hovering ? 1.15 : 1
                }
            case .trashLid, .none:
                break
            }
        }
    }

    enum HoverEffect {
        case none
        case rotate
        case scale
        case trashLid
    }
}

// MARK: - Hoverable Menu Button

private struct HoverableMenuButton<MenuContent: View>: View {
    let systemName: String
    let help: String
    let hoverEffect: CapsuleIconButton.HoverEffect
    let menuContent: () -> MenuContent
    @State private var isHovering = false
    @State private var scale: CGFloat = 1

    init(systemName: String, help: String = "", hoverEffect: CapsuleIconButton.HoverEffect = .none, @ViewBuilder menuContent: @escaping () -> MenuContent) {
        self.systemName = systemName
        self.help = help
        self.hoverEffect = hoverEffect
        self.menuContent = menuContent
    }

    var body: some View {
        Menu {
            menuContent()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .scaleEffect(scale)
                .foregroundStyle(isHovering ? AgendaColor.amber : Color(red: 0.118, green: 0.118, blue: 0.118))
                .onHover { hovering in
                    isHovering = hovering
                    if hoverEffect == .scale {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            scale = hovering ? 1.15 : 1
                        }
                    }
                }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help(help)
    }
}

// MARK: - Capsule Icon Button with Popover

private struct CapsuleIconFloatingMenuButton: View {
    let systemName: String
    let help: String
    @Binding var isPresented: Bool
    let width: CGFloat
    let sections: () -> [AgendadaFloatingMenuSection]
    @State private var presenter = AgendadaFloatingMenuPresenter()
    @State private var isHovering = false

    init(
        systemName: String,
        help: String = "",
        isPresented: Binding<Bool>,
        width: CGFloat = 214,
        sections: @escaping () -> [AgendadaFloatingMenuSection]
    ) {
        self.systemName = systemName
        self.help = help
        self._isPresented = isPresented
        self.width = width
        self.sections = sections
    }

    var body: some View {
        Button {
            if isPresented {
                isPresented = false
            } else {
                presenter.configure(dismiss: { isPresented = false }, showSubmenu: { _ in })
                isPresented = true
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovering ? AgendaColor.amber : Color(red: 0.118, green: 0.118, blue: 0.118))
        .help(help)
        .onHover { isHovering = $0 }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            isPresented = false
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            AgendadaFloatingMenuView(sections: sections(), presenter: presenter, width: width)
        }
    }
}

private struct CapsuleIconPopoverButton<PopoverContent: View>: View {
    let systemName: String
    let help: String
    @Binding var isPresented: Bool
    let popoverContent: () -> PopoverContent
    @State private var isHovering = false

    init(systemName: String, help: String = "", isPresented: Binding<Bool>, popoverContent: @escaping () -> PopoverContent) {
        self.systemName = systemName
        self.help = help
        self._isPresented = isPresented
        self.popoverContent = popoverContent
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovering ? AgendaColor.amber : Color(red: 0.118, green: 0.118, blue: 0.118))
        .help(help)
        .onHover { isHovering = $0 }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            popoverContent()
                .agendadaGlassPopover()
        }
    }
}

// MARK: - Sort Popover Content

@MainActor
private func sortFloatingMenuSections(store: ObservableLibraryStore) -> [AgendadaFloatingMenuSection] {
    [
        AgendadaFloatingMenuSection(items: SortMode.allCases.map { mode in
            AgendadaFloatingMenuItem(
                iconSystemName: store.sortMode == mode ? "checkmark" : "circle",
                title: mode.title
            ) { _ in
                store.setSortMode(mode)
            }
        })
    ]
}

@MainActor
private func batchMoveFloatingMenuSections(
    store: ObservableLibraryStore,
    showMoveMenu: Binding<Bool>
) -> [AgendadaFloatingMenuSection] {
    [
        AgendadaFloatingMenuSection(items: store.projects.map { project in
            AgendadaFloatingMenuItem(
                iconSystemName: "folder",
                title: project.name
            ) { _ in
                store.moveNotes(store.batchSelectedNoteIDs, toProject: project.id)
                showMoveMenu.wrappedValue = false
            }
        })
    ]
}

// MARK: - Enter-intercepting TextField for Search Popover

private struct ReturnKeyTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var onReturn: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.isBezeled = false
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.font = NSFont(name: "Avenir Next", size: 13)
        tf.placeholderString = placeholder
        tf.lineBreakMode = .byTruncatingTail
        tf.cell?.isScrollable = true
        tf.cell?.wraps = false
        tf.delegate = context.coordinator
        return tf
    }

    func updateNSView(_ tf: NSTextField, context: Context) {
        if tf.stringValue != text { tf.stringValue = text }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onReturn: onReturn)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        let onReturn: () -> Void

        init(text: Binding<String>, onReturn: @escaping () -> Void) {
            _text = text
            self.onReturn = onReturn
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            // Only write to binding if value actually changed — prevents
            // unnecessary publishChange → re-render → binding writeback cycles
            let newValue = tf.stringValue
            guard newValue != text else { return }
            text = newValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onReturn()
                return true  // 拦截回车，不再传给系统
            }
            return false
        }
    }
}

// MARK: - Search Popover Content

private struct SearchFilterOption: Identifiable {
    let label: String
    let token: String
    let systemImage: String

    var id: String { token }
}

private struct SearchPopoverResult: Identifiable {
    let note: Note
    let projectName: String
    let excerpt: String
    let matchCount: Int
    let field: SearchField?

    var id: Note.ID { note.id }
}

private struct SearchPopoverContent: View {
    let committedSearchText: String
    let clearCommittedSearch: () -> Void
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
                ReturnKeyTextField(
                    text: $draftSearchText,
                    placeholder: "搜索标题、正文、标签或人员",
                    onReturn: { handleSearchReturn() }
                )
                .frame(width: 180, height: 20)
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
            draftSearchText = committedSearchText
            searchScope = store.searchScope
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

    // MARK: - Navigation helpers

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

    private var searchResultNotes: [Note] {
        guard hasActiveSearch else { return [] }
        if searchScope == .currentScope {
            // 当前范围预览：从 store 的 base scope notes 直接用 draftText 过滤
            let baseNotes = store.library.currentScopeNotesForPreview(now: Date())
            let query = NoteSearchEngine.parse(draftSearchText)
            return NoteSearchEngine.filter(baseNotes, query: query)
        } else {
            return store.library.globalSearchNotes(for: draftSearchText, onlyTrash: isTrashPreview)
        }
    }

    private var searchResultRows: [SearchPopoverResult] {
        let occurrencesByNote = Dictionary(grouping: previewOccurrences, by: \.noteID)
        return searchResultNotes.prefix(5).map { note in
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

    private var previewOccurrences: [SearchOccurrence] {
        guard hasActiveSearch else { return [] }
        if searchScope == .currentScope {
            let notes = searchResultNotes
            return NoteSearchEngine.occurrences(in: notes, query: draftSearchText)
        } else {
            return store.library.globalSearchOccurrences(for: draftSearchText, onlyTrash: isTrashPreview)
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
        if !previewOccurrences.isEmpty {
            return "\(searchResultNotes.count) 篇笔记，\(previewOccurrences.count) 处命中"
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



// MARK: - Card Interaction Layer

/// Wraps card content and owns hover/drop interaction state.
/// Isolates high-frequency isHovering changes from the heavy editor/preview content,
/// so mouse movement only invalidates this lightweight overlay view.
private struct CardInteractionLayer<Content: View>: View {
    @Environment(ObservableLibraryStore.self) private var store
    let note: Note
    let isSelected: Bool
    let canDrag: Bool
    let onTap: () -> Void
    let onBeforeDrop: () -> Void
    /// Called when a drag crosses a pin boundary. Parameters: (draggedNoteID, targetNoteID, insertBefore).
    let onPinBoundaryCrossing: (Note.ID, Note.ID, Bool) -> Void
    @ViewBuilder let content: Content

    @State private var isHovering = false
    @State private var isDropTargeted = false
    @State private var cardHeight: CGFloat = 0

    var body: some View {
        content
            .overlay(alignment: .leading) {
                if isHovering && !store.isInBatchMode && !isSelected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.black.opacity(0.07))
                        .frame(width: 3)
                        .padding(.vertical, 16)
                        .offset(x: -11)
                }
            }
            .overlay(alignment: .top) {
                if isSelected || isHovering {
                    ZStack(alignment: .top) {
                        Color.clear
                            .frame(width: 80, height: 24)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(AgendaColor.cardDragHandle)
                            .frame(width: 24, height: 3)
                            .padding(.top, 6)
                    }
                    .contentShape(Rectangle())
                    .when(canDrag) { view in
                        view.draggable(DragPayload(noteID: note.id)) {
                            CardDragPreview(note: note)
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AgendaColor.amber)
                        .frame(height: 3)
                        .padding(.horizontal, 16)
                }
            }
            .shadow(
                color: isDropTargeted ? AgendaColor.amber.opacity(0.15)
                    : (isSelected ? .black.opacity(0.04) : .clear),
                radius: 8, x: 0, y: 2
            )
            .when(canDrag) { view in
                view
                    .dropDestination(for: DragPayload.self) { items, location in
                        handleDrop(items: items, location: location)
                    } isTargeted: { targeted in
                        isDropTargeted = targeted
                    }
            }
            .onHover { isHovering = $0 }
            .onTapGesture {
                if !isSelected || store.isInBatchMode {
                    onTap()
                }
            }
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear { cardHeight = geo.size.height }
                }
            )
    }

    private func handleDrop(items: [DragPayload], location: CGPoint) -> Bool {
        guard let payload = items.first else { return false }
        guard payload.noteID != note.id else { return false }
        guard let draggedNote = store.note(withID: payload.noteID) else { return false }
        guard draggedNote.projectID == note.projectID else { return false }

        let insertBefore = location.y < cardHeight / 2

        // Detect pin boundary crossing — delegate to parent for alert handling.
        let crossing = store.pinBoundaryCrossing(draggedNoteID: payload.noteID, targetNoteID: note.id)
        if crossing != .none {
            onPinBoundaryCrossing(payload.noteID, note.id, insertBefore)
            return true  // Accept the drop visually; parent will handle the operation.
        }

        onBeforeDrop()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if insertBefore {
                store.insertNoteBefore(payload.noteID, targetID: note.id)
            } else {
                store.insertNoteAfter(payload.noteID, targetID: note.id)
            }
        }
        return true
    }
}

/// Lightweight drag preview shown during drag operations.
private struct CardDragPreview: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title.isEmpty ? "无标题" : note.title)
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(Color(red: 0.102, green: 0.102, blue: 0.102))
                .lineLimit(1)
            Text(note.bodyPlainText)
                .font(.custom("Avenir Next", size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 240)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        )
    }
}

// MARK: - StreamNote Bullet Menu

/// Owns bullet-menu state so toggling the menu does not invalidate the full card row.
private struct StreamNoteBulletMenuView: View {
    @Environment(ObservableLibraryStore.self) private var store
    let note: Note
    let isSelected: Bool
    let noteColor: Color
    /// Called before menu action to set skipNextCardTap on parent.
    var onMenuAction: () -> Void

    @State private var showMenu = false
    @State private var menuSections: [AgendadaFloatingMenuSection] = []
    @State private var menuPresenter = AgendadaFloatingMenuPresenter()
    @State private var menuDismissedAt = Date.distantPast
    @State private var isHovering = false

    private var isCompleted: Bool { note.status == .completed }
    private var isBrief: Bool { note.isBrief }
    private var isInBatch: Bool { store.isInBatchMode }
    private var isBatchSelected: Bool { store.batchSelectedNoteIDs.contains(note.id) }

    var body: some View {
        ZStack {
            if isInBatch {
                Image(systemName: isBatchSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isBatchSelected ? AgendaColor.amber : AgendaColor.textMuted)
            } else {
                if isHovering || isSelected {
                    Circle()
                        .stroke(noteColor, lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
                bulletShape
            }
        }
        .frame(width: 24, height: 24)
        .contentShape(Rectangle())
        .onTapGesture {
            onMenuAction()
            if isInBatch {
                store.toggleBatchSelection(noteID: note.id)
            } else {
                toggleMenu()
            }
        }
        .popover(isPresented: $showMenu, attachmentAnchor: .point(.trailing), arrowEdge: .trailing) {
            AgendadaFloatingMenuView(sections: menuSections, presenter: menuPresenter, width: 214)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            showMenu = false
        }
        .onChange(of: showMenu) { _, isPresented in
            if !isPresented { menuDismissedAt = Date() }
        }
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isInBatch)
        .animation(.easeOut(duration: 0.15), value: isBatchSelected)
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }

    @ViewBuilder
    private var bulletShape: some View {
        if isBrief {
            if isCompleted {
                ZStack {
                    Circle().fill(noteColor).frame(width: 14, height: 14)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                }
            } else {
                Circle().fill(noteColor).frame(width: 14, height: 14)
            }
        } else {
            Circle().stroke(noteColor, lineWidth: 1).frame(width: 14, height: 14)
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(noteColor)
            }
        }
    }

    private func toggleMenu() {
        if showMenu { showMenu = false; return }
        guard Date().timeIntervalSince(menuDismissedAt) > 0.18 else { return }
        menuPresenter.reset()
        menuPresenter.configure(dismiss: { showMenu = false }, showSubmenu: { _ in }, popToRoot: {})
        menuSections = buildMenuSections()
        showMenu = true
    }

    private func buildMenuSections() -> [AgendadaFloatingMenuSection] {
        markSection + [
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(iconSystemName: "gearshape", title: "其他操作", showsSubmenuIndicator: true, dismissesAfterAction: false
                ) { presenter in
                    presenter.showSubmenu(sections: moreActionsSections)
                }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(iconSystemName: "checklist", title: "批量选择..."
                ) { _ in store.toggleBatchSelection(noteID: note.id) }
            ])
        ]
    }

    private var markSection: [AgendadaFloatingMenuSection] {
        [
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: note.isBrief ? "circle" : "smallcircle.fill.circle",
                    title: note.isBrief ? "取消“简达”" : "标记为“简达”"
                ) { _ in store.setBrief(!note.isBrief, noteID: note.id) },
                AgendadaFloatingMenuItem(
                    iconSystemName: note.status == .completed ? "arrow.uturn.left" : "checkmark",
                    title: note.status == .completed ? "标记为未完成" : "标记为已完成"
                ) { _ in
                    store.setStatus(note.status == .completed ? .open : .completed, noteID: note.id)
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "square.fill", title: "使用颜色标记",
                    showsSubmenuIndicator: true, dismissesAfterAction: false
                ) { presenter in presenter.showSubmenu(sections: colorSections) }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: note.pinState == .pinnedTop ? "pin.slash" : "pin",
                    title: note.pinState == .pinnedTop ? "取消置顶" : "置顶"
                ) { _ in store.setPinState(note.pinState == .pinnedTop ? .none : .pinnedTop, noteID: note.id) },
                AgendadaFloatingMenuItem(
                    iconSystemName: note.pinState == .pinnedBottom ? "arrow.up.to.line" : "arrow.down.to.line",
                    title: note.pinState == .pinnedBottom ? "取消置底" : "置底"
                ) { _ in store.setPinState(note.pinState == .pinnedBottom ? .none : .pinnedBottom, noteID: note.id) },
                AgendadaFloatingMenuItem(
                    iconSystemName: note.isCollapsed ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left",
                    title: note.isCollapsed ? "展开笔记" : "折叠笔记"
                ) { _ in store.setCollapsed(!note.isCollapsed, noteID: note.id) },
                AgendadaFloatingMenuItem(iconSystemName: "lock.fill", title: "锁定笔记...", isEnabled: false) { _ in }
            ])
        ]
    }

    private var colorSections: [AgendadaFloatingMenuSection] {
        let items = [AgendadaFloatingMenuItem(iconColor: nil, title: "无颜色") { _ in
            store.setNoteColor(nil, noteID: note.id)
        }] + NoteColor.allCases.map { color in
            AgendadaFloatingMenuItem(iconColor: noteColorValue(color), title: color.title) { _ in
                store.setNoteColor(color, noteID: note.id)
            }
        }
        return [AgendadaFloatingMenuSection(items: items)]
    }

    private var moreActionsSections: [AgendadaFloatingMenuSection] {
        var firstSection: [AgendadaFloatingMenuItem] = [
            AgendadaFloatingMenuItem(iconSystemName: "doc.on.doc", title: "拷贝笔记") { _ in
                store.duplicateNote(note.id)
            }
        ]
        if !store.projects.isEmpty {
            firstSection.append(
                AgendadaFloatingMenuItem(iconSystemName: "folder", title: "移动到项目",
                    showsSubmenuIndicator: true, dismissesAfterAction: false
                ) { presenter in
                    presenter.showSubmenu(sections: moveProjectSections, title: "移动笔记到:")
                }
            )
        }
        firstSection.append(contentsOf: [
            AgendadaFloatingMenuItem(iconSystemName: "square.and.arrow.up", title: "分享...",
                showsSubmenuIndicator: true, dismissesAfterAction: false
            ) { presenter in presenter.showSubmenu(sections: shareSections, title: "分享为:") },
            AgendadaFloatingMenuItem(iconSystemName: "printer", title: "打印...") { _ in printNote(note) }
        ])
        return [
            AgendadaFloatingMenuSection(items: firstSection),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(iconSystemName: "trash", title: "移到废纸篓", role: .destructive
                ) { _ in store.deleteNote(note.id) }
            ])
        ]
    }

    private var moveProjectSections: [AgendadaFloatingMenuSection] { buildMoveProjectSections() }
    private var shareSections: [AgendadaFloatingMenuSection] { buildShareSections() }
}

// MARK: - StreamNote Date Control

/// Owns date-picker state so opening the date picker does not invalidate the full card row.
private struct StreamNoteDateControlView: View {
    @Environment(ObservableLibraryStore.self) private var store
    let note: Note
    let isSelected: Bool
    let dateLabel: String
    let dateFontName: String
    let dateColor: Color

    @State private var showDatePicker = false
    @State private var datePickerDismissedAt = Date.distantPast
    @State private var isHovering = false

    var body: some View {
        let color = (isSelected || isHovering || isToday) ? AgendaColor.amber : dateColor
        let font = (isSelected || isHovering || isToday) ? "Avenir Next Medium" : dateFontName

        Group {
            if !dateLabel.isEmpty {
                Button { togglePicker() } label: {
                    Text(dateLabel)
                        .font(.custom(font, size: 13))
                        .foregroundStyle(color)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDatePicker, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) {
                    datePickerPanel
                }
            } else if isSelected {
                Button { togglePicker() } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                        .foregroundStyle(AgendaColor.textMuted)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDatePicker, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) {
                    datePickerPanel
                }
            }
        }
        .onHover { isHovering = $0 }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            showDatePicker = false
        }
        .onChange(of: showDatePicker) { _, isPresented in
            if !isPresented { datePickerDismissedAt = Date() }
        }
    }

    private var isToday: Bool {
        guard let d = note.scheduledDate else { return false }
        return Calendar.current.isDateInToday(d)
    }

    private func togglePicker() {
        if showDatePicker { showDatePicker = false; return }
        guard Date().timeIntervalSince(datePickerDismissedAt) > 0.18 else { return }
        showDatePicker = true
    }

    private var datePickerPanel: some View {
        DateAgendaPanelView(noteID: note.id) { showDatePicker = false }
            .agendadaGlassPopover(cornerRadius: 18)
    }
}

// MARK: - StreamNote Action Menu

/// Owns settings-menu state so opening the gear menu does not invalidate the full card row.
private struct StreamNoteActionMenuView: View {
    @Environment(ObservableLibraryStore.self) private var store
    let note: Note
    let isSelected: Bool
    /// Called before menu opens to set skipNextCardTap on parent.
    var onMenuWillOpen: () -> Void

    @State private var showPopover = false
    @State private var menuOpenPending = false
    @State private var menuDismissedAt = Date.distantPast
    @State private var menuSections: [AgendadaFloatingMenuSection] = []
    @State private var menuPresenter = AgendadaFloatingMenuPresenter()

    var body: some View {
        Button {
            onMenuWillOpen()
            toggleMenu()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AgendaColor.amber)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help("更多操作")
        .popover(isPresented: $showPopover, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
            AgendadaFloatingMenuView(
                sections: menuSections.isEmpty ? buildMenuSections() : menuSections,
                presenter: menuPresenter,
                width: 214
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            showPopover = false; menuOpenPending = false
        }
        .onChange(of: showPopover) { _, isPresented in
            if !isPresented { menuDismissedAt = Date() }
        }
    }

    private func toggleMenu() {
        if showPopover || menuOpenPending { menuOpenPending = false; showPopover = false; return }
        guard Date().timeIntervalSince(menuDismissedAt) > 0.18 else { return }
        menuPresenter.reset()
        menuOpenPending = true
        menuPresenter.configure(
            dismiss: { menuOpenPending = false; showPopover = false },
            showSubmenu: { _ in },
            popToRoot: {}
        )
        menuSections = buildMenuSections()
        DispatchQueue.main.async {
            guard menuOpenPending else { return }
            menuOpenPending = false
            showPopover = true
        }
    }

    private func buildMenuSections() -> [AgendadaFloatingMenuSection] {
        [
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(iconSystemName: "circle", title: "标记", showsSubmenuIndicator: true, dismissesAfterAction: false
                ) { presenter in presenter.showSubmenu(sections: markSections, title: "标记") }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(iconSystemName: "doc.on.clipboard", title: "拷贝为...", showsSubmenuIndicator: true, dismissesAfterAction: false
                ) { presenter in presenter.showSubmenu(sections: copyAsSections, title: "拷贝为:") },
                AgendadaFloatingMenuItem(iconSystemName: "folder.badge.arrow.right", title: "移动到...", showsSubmenuIndicator: true, dismissesAfterAction: false
                ) { presenter in presenter.showSubmenu(sections: moveProjectSections, title: "移动笔记到:") },
                AgendadaFloatingMenuItem(iconSystemName: "plus.square.on.square", title: "复制"
                ) { _ in store.duplicateNote(note.id) },
                AgendadaFloatingMenuItem(iconSystemName: "arrow.branch", title: "开始新笔记"
                ) { _ in
                    let nid = store.addNoteReturningID()
                    store.selectNote(nid)
                }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(iconSystemName: "square.and.arrow.up", title: "分享...", showsSubmenuIndicator: true, dismissesAfterAction: false
                ) { presenter in presenter.showSubmenu(sections: shareSections, title: "分享为:") },
                AgendadaFloatingMenuItem(iconSystemName: "printer", title: "打印..."
                ) { _ in printNote(note) },
                AgendadaFloatingMenuItem(iconSystemName: "rectangle.dashed", title: "存储为模板..."
                ) { _ in saveAsTemplate(from: note, store: store) }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(iconSystemName: "info.circle", title: "显示信息...",
                    subtitle: editedAtSubtitle, showsSubmenuIndicator: true, dismissesAfterAction: false
                ) { presenter in presenter.showSubmenu(sections: infoSections, title: "显示信息...") }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(iconSystemName: "trash", title: "移到废纸篓", role: .destructive
                ) { _ in store.deleteNote(note.id) }
            ])
        ]
    }

    private var markSections: [AgendadaFloatingMenuSection] {
        [
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: note.isBrief ? "circle" : "smallcircle.fill.circle",
                    title: note.isBrief ? "取消“简达”" : "标记为“简达”"
                ) { _ in store.setBrief(!note.isBrief, noteID: note.id) },
                AgendadaFloatingMenuItem(
                    iconSystemName: note.status == .completed ? "arrow.uturn.left" : "checkmark",
                    title: note.status == .completed ? "标记为未完成" : "标记为已完成"
                ) { _ in store.setStatus(note.status == .completed ? .open : .completed, noteID: note.id) },
                AgendadaFloatingMenuItem(iconSystemName: "square.fill", title: "使用颜色标记",
                    showsSubmenuIndicator: true, dismissesAfterAction: false
                ) { presenter in presenter.showSubmenu(sections: colorSections) }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: note.pinState == .pinnedTop ? "pin.slash" : "pin",
                    title: note.pinState == .pinnedTop ? "取消置顶" : "置顶"
                ) { _ in store.setPinState(note.pinState == .pinnedTop ? .none : .pinnedTop, noteID: note.id) },
                AgendadaFloatingMenuItem(
                    iconSystemName: note.pinState == .pinnedBottom ? "arrow.up.to.line" : "arrow.down.to.line",
                    title: note.pinState == .pinnedBottom ? "取消置底" : "置底"
                ) { _ in store.setPinState(note.pinState == .pinnedBottom ? .none : .pinnedBottom, noteID: note.id) },
                AgendadaFloatingMenuItem(
                    iconSystemName: note.isCollapsed ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left",
                    title: note.isCollapsed ? "展开笔记" : "折叠笔记"
                ) { _ in store.setCollapsed(!note.isCollapsed, noteID: note.id) },
                AgendadaFloatingMenuItem(iconSystemName: "lock.fill", title: "锁定笔记...", isEnabled: false) { _ in }
            ])
        ]
    }

    private var colorSections: [AgendadaFloatingMenuSection] {
        let items = [AgendadaFloatingMenuItem(iconColor: nil, title: "无颜色") { _ in
            store.setNoteColor(nil, noteID: note.id)
        }] + NoteColor.allCases.map { color in
            AgendadaFloatingMenuItem(iconColor: noteColorValue(color), title: color.title) { _ in
                store.setNoteColor(color, noteID: note.id)
            }
        }
        return [AgendadaFloatingMenuSection(items: items)]
    }

    private var copyAsSections: [AgendadaFloatingMenuSection] { buildCopyAsSections() }
    private var moveProjectSections: [AgendadaFloatingMenuSection] { buildMoveProjectSections() }
    private var shareSections: [AgendadaFloatingMenuSection] { buildShareSections() }

    private var infoSections: [AgendadaFloatingMenuSection] {
        [
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(title: "统计:", subtitle: noteStatsText, isHeader: true, dismissesAfterAction: false) { _ in },
                AgendadaFloatingMenuItem(title: "阅读时间:", subtitle: readingTimeText, isHeader: true, dismissesAfterAction: false) { _ in }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(title: "创建于:", subtitle: createdAtText, isHeader: true, dismissesAfterAction: false) { _ in }
            ])
        ]
    }

    private var editedAtSubtitle: String {
        let cal = Calendar.current
        let tf = DateFormatter(); tf.locale = Locale(identifier: "zh_CN"); tf.dateFormat = "HH:mm"
        let timeText = tf.string(from: note.editedAt)
        if cal.isDateInToday(note.editedAt) { return "最近编辑时间： 今天 \(timeText)" }
        if cal.isDateInYesterday(note.editedAt) { return "最近编辑时间： 昨天 \(timeText)" }
        let df = DateFormatter(); df.locale = Locale(identifier: "zh_CN"); df.dateFormat = "M月d日"
        return "最近编辑时间： \(df.string(from: note.editedAt)) \(timeText)"
    }

    private var noteStatsText: String {
        let text = note.bodyPlainText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cc = text.count
        let wws = text.filter { !$0.isWhitespace }.count
        let paras = max(text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count, text.isEmpty ? 0 : 1)
        return "\(wws)个字、\(cc)个字符 (\(wws) without spaces)、\(paras)个段落"
    }

    private var readingTimeText: String {
        let chars = note.bodyPlainText.filter { !$0.isWhitespace }.count
        let mins = Int(ceil(Double(chars) / 500.0))
        return mins <= 1 ? "不足一分钟" : "约 \(mins) 分钟"
    }

    private var createdAtText: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy年M月d日 HH:mm:ss"
        return f.string(from: note.createdAt)
    }
}

// MARK: - Shared Utilities

@MainActor
private func printNote(_ note: Note) {
    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
    textView.string = "\(note.title)\n\n\(note.bodyPlainText)"
    let printInfo = NSPrintInfo.shared
    printInfo.topMargin = 36; printInfo.bottomMargin = 36
    printInfo.leftMargin = 36; printInfo.rightMargin = 36
    let printOp = NSPrintOperation(view: textView, printInfo: printInfo)
    printOp.runModal(for: NSApp.keyWindow ?? NSWindow(), delegate: nil, didRun: nil, contextInfo: nil)
}

@MainActor
private func saveAsTemplate(from note: Note, store: ObservableLibraryStore) {
    let alert = NSAlert()
    alert.messageText = "存储为模板"
    alert.informativeText = "保存当前笔记为可复用的模板"
    alert.alertStyle = .informational
    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
    textField.placeholderString = "模板名称"
    textField.stringValue = note.title
    alert.accessoryView = textField
    alert.addButton(withTitle: "保存")
    alert.addButton(withTitle: "取消")
    guard let window = NSApp.keyWindow else { return }
    alert.beginSheetModal(for: window) { response in
        if response == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            store.addCustomNoteTemplate(name: name, from: note)
        }
    }
}

// MARK: - Shared Menu Builders

private func noteColorValue(_ c: NoteColor?) -> Color {
    guard let c else { return AgendaColor.amber }
    return switch c {
    case .accent: AgendaColor.amber
    case .red: Color(red: 0.95, green: 0.35, blue: 0.35)
    case .green: Color(red: 0.28, green: 0.68, blue: 0.45)
    case .blue: Color(red: 0.26, green: 0.56, blue: 0.95)
    case .yellow: Color(red: 0.95, green: 0.80, blue: 0.15)
    case .brown: Color(red: 0.65, green: 0.45, blue: 0.30)
    case .pink: Color(red: 0.93, green: 0.36, blue: 0.62)
    case .purple: Color(red: 0.62, green: 0.35, blue: 0.85)
    case .gray: Color(red: 0.55, green: 0.55, blue: 0.60)
    }
}

private func projectColorValue(_ color: ProjectColor) -> Color {
    switch color {
    case .blue: Color(red: 0.26, green: 0.74, blue: 0.75)
    case .green: Color(red: 0.32, green: 0.72, blue: 0.45)
    case .orange: AgendaColor.amber
    case .pink: Color(red: 0.93, green: 0.36, blue: 0.62)
    case .gray: Color(red: 0.55, green: 0.55, blue: 0.60)
    }
}

private func buildCopyAsSections() -> [AgendadaFloatingMenuSection] {
    // Note: needs note for content — caller must capture note in closure.
    // For simple sharing items, placeholders are returned.
    [
        AgendadaFloatingMenuSection(items: [
            AgendadaFloatingMenuItem(iconText: "RTF", title: "笔记文本") { _ in },
            AgendadaFloatingMenuItem(iconText: "M↓", title: "Markdown") { _ in },
            AgendadaFloatingMenuItem(iconText: "<>", title: "HTML") { _ in },
            AgendadaFloatingMenuItem(iconText: "txt", title: "纯文本") { _ in },
            AgendadaFloatingMenuItem(iconSystemName: "doc.text", title: "摘要") { _ in }
        ]),
        AgendadaFloatingMenuSection(items: [
            AgendadaFloatingMenuItem(iconSystemName: "link", title: "Agenda 链接") { _ in }
        ])
    ]
}

private func buildShareSections() -> [AgendadaFloatingMenuSection] {
    [
        AgendadaFloatingMenuSection(items: [
            AgendadaFloatingMenuItem(iconSystemName: "dot.radiowaves.left.and.right", title: "隔空投送") { _ in },
            AgendadaFloatingMenuItem(iconSystemName: "envelope.fill", title: "通过邮件发送") { _ in },
            AgendadaFloatingMenuItem(iconSystemName: "message.fill", title: "通过“信息”App 发送") { _ in },
            AgendadaFloatingMenuItem(iconSystemName: "note.text", title: "添加到“备忘录”") { _ in },
            AgendadaFloatingMenuItem(iconSystemName: "folder", title: "另存为") { _ in }
        ]),
        AgendadaFloatingMenuSection(items: [
            AgendadaFloatingMenuItem(iconSystemName: "iphone", title: "Simulator") { _ in },
            AgendadaFloatingMenuItem(iconText: "微", title: "发送到微信") { _ in },
            AgendadaFloatingMenuItem(iconText: "手", title: "手记") { _ in },
            AgendadaFloatingMenuItem(iconText: "无", title: "无边记") { _ in }
        ])
    ]
}

private func buildMoveProjectSections() -> [AgendadaFloatingMenuSection] {
    // Placeholder — real implementation needs store context.
    // The caller (inside a View) can customize with store access.
    []
}

// MARK: - Bullet Menu State
