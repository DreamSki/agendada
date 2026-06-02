import AgendadaCore
import AppKit
import SwiftUI

struct NoteStreamView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @Binding var searchText: String
    @State private var isSearching = false
    @State private var showSortPopover = false
    @State private var showMoveMenu = false
    @State private var dropAtEndTargeted = false
    @State private var showTemplatePopover = false

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
                    SearchPopoverContent(searchText: $searchText)
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

    private var sortButton: some View {
        HoverableCircleButton(systemName: "line.3.horizontal.decrease", help: "排序方式", action: { showSortPopover = true })
            .popover(isPresented: $showSortPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(NoteSortOrder.allCases, id: \.self) { order in
                    Button {
                        store.sortOrder = order
                        showSortPopover = false
                    } label: {
                        HStack {
                            Text(order.title)
                            Spacer()
                            if store.sortOrder == order {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AgendaColor.amber)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.custom("Avenir Next", size: 13))
            .padding(.vertical, 4)
            .frame(width: 180)
            .agendadaGlassPopover()
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

    private func glassIconButton(systemName: String, action: @escaping () -> Void, help: String) -> some View {
        HoverableCircleButton(systemName: systemName, help: help, action: action)
    }

    private func glassTextButton(_ label: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Text(label)
                .font(.custom("Avenir Next", size: 14))
                .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? .red : Color(red: 0.118, green: 0.118, blue: 0.118))
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
    }

    private func glassIconCircleButton(systemName: String, help: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        HoverableCircleButton(systemName: systemName, help: help, role: role, action: action)
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
        if let ov = store.selectedOverview { return ov.title }
        if let pid = store.selectedProjectID, let proj = store.project(withID: pid) { return proj.name }
        return store.activeTitle
    }

    private var breadcrumbCategoryName: String? {
        if store.selectedOverview != nil { return nil }
        if let pid = store.selectedProjectID, let proj = store.project(withID: pid),
           let cid = proj.categoryID, let cat = store.category(withID: cid) { return cat.name }
        return nil
    }

    private var breadcrumbContext: String? {
        if store.isInBatchMode { return "已选 \(store.batchSelectedNoteIDs.count) 项" }
        if store.selectedOverview != nil { return "\(store.filteredNotes().count) 条笔记" }
        if let note = store.selectedNoteID.flatMap({ store.note(withID: $0) }) { return note.title }
        return nil
    }

    // MARK: - Stream

    private var noteStreamContent: some View {
        let notes = store.filteredNotes()
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(notes) { note in
                        StreamNoteRow(note: note)
                            .id(note.id).padding(.bottom, AgendaSpacing.cardGap)
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
            Button("") {
                if store.isInBatchMode { store.deselectAllNotes() }
            }
            .keyboardShortcut(.escape, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)
        }
        .onChange(of: store.selectedNoteID) { _, newID in
            if let id = newID {
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
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
        tf.cell?.isScrollable = true
        tf.cell?.wraps = false
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
            if tf.stringValue != text {
                tf.stringValue = text
            }
        }
        tf.font = font
        tf.textColor = textColor
        tf.isEnabled = isEnabled
        tf.isSelectable = isEnabled
        tf.isEditable = isEnabled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            text.wrappedValue = tf.stringValue
        }
    }
}

// MARK: - Note Row

private struct StreamNoteRow: View {
    @Environment(ObservableLibraryStore.self) private var store
    let note: Note

    @State private var draft: StreamNoteDraft
    @State private var initialDraft: StreamNoteDraft
    @State private var saveTask: Task<Void, Never>?
    @State private var editorHeight: CGFloat = 0
    @State private var capturedPreviewHeight: CGFloat = 0
    @State private var editorHasUserChanges = false
    @State private var editorIsVisible = false
    @State private var initialBlockJSON: Data?
    @State private var skipNextCardTap = false

    init(note: Note) {
        self.note = note
        let d = StreamNoteDraft(note: note)
        _draft = State(initialValue: d)
        _initialDraft = State(initialValue: d)
    }

    private var isSelected: Bool { store.selectedNoteID == note.id }
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
            onBeforeDrop: { flushDraft() }
        ) {
            cardBase
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            // Subviews (bullet menu, action menu) handle their own dismiss on resign.
        }
        .onTapGesture {
            handleCardTap()
        }
        .onChange(of: draft.title) { scheduleSaveDraft() }
        .onChange(of: draft.hasScheduledDate) { scheduleSaveDraft() }
        .onChange(of: draft.scheduledDate) { scheduleSaveDraft() }
        .onChange(of: draft.tagsText) { scheduleSaveDraft() }
        .onChange(of: draft.peopleText) { scheduleSaveDraft() }
        .onChange(of: draft.status) { scheduleSaveDraft() }
        .onChange(of: store.selectedNoteID) { oldValue, newValue in
            if oldValue == note.id && newValue != note.id {
                flushDraft()
                editorHeight = 0
                editorIsVisible = false
            } else if newValue == note.id {
                resetDraft()
                prepareEditorOverlayForSelection()
            }
        }
        .onChange(of: note.id) {
            resetDraft()
        }
        .onDisappear { flushDraft() }
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
                        let q = store.library.searchHighlightText
                        if !q.isEmpty {
                            SharedBlockNoteWebView.shared.searchInEditor(query: q) { _ in
                                if let occ = store.currentOccurrence,
                                   occ.field == .body,
                                   occ.noteID == note.id {
                                    SharedBlockNoteWebView.shared.navigateToMatch(
                                        index: occ.bodyIndexInNote
                                    ) { _, _ in }
                                }
                            }
                        }
                    }
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(minHeight: minH, alignment: .top)
                .opacity(editorIsVisible ? (isNoteDimmed ? 0.58 : 1) : 0)
            }
        }
        .frame(minHeight: minH, alignment: .top)
        .animation(.easeInOut(duration: 0.15), value: capturedPreviewHeight)
        .padding(.bottom, 60)
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
                    store.moveNote(note.id, to: .afterNext)
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
                    store.moveNote(note.id, to: .toLast)
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
        case .blue:
            return Color(red: 0.26, green: 0.74, blue: 0.75)
        case .green:
            return Color(red: 0.32, green: 0.72, blue: 0.45)
        case .orange:
            return AgendaColor.amber
        case .pink:
            return Color(red: 0.93, green: 0.36, blue: 0.62)
        case .gray:
            return Color(red: 0.55, green: 0.55, blue: 0.60)
        }
    }

    private var isNoteDimmed: Bool { note.status == .completed || note.status == .closed }

    // MARK: - Date

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
        let fm = DateFormatter(); fm.locale = Locale(identifier: "zh_CN"); fm.dateFormat = "M月d日 EEEE"
        return fm.string(from: d)
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
        let fm = DateFormatter(); fm.locale = Locale(identifier: "zh_CN"); fm.dateFormat = "M月d日"
        return fm.string(from: note.editedAt)
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

    private func printNote() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
        textView.string = "\(note.title)\n\n\(note.bodyPlainText)"
        let printInfo = NSPrintInfo.shared
        printInfo.topMargin = 36; printInfo.bottomMargin = 36
        printInfo.leftMargin = 36; printInfo.rightMargin = 36
        let printOp = NSPrintOperation(view: textView, printInfo: printInfo)
        printOp.runModal(for: NSApp.keyWindow ?? NSWindow(), delegate: nil, didRun: nil, contextInfo: nil)
    }

    private func saveAsTemplate() {
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

    private func moveWithPinCheck(_ move: PositionMove) {
        guard store.wouldCrossPinnedTopBoundary(note.id, move: move) else {
            store.moveNote(note.id, to: move)
            return
        }

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

    @ViewBuilder
    private var contextMenuContent: some View {
        Button(note.isStarred ? "取消标星" : "标星") { store.setStarred(!note.isStarred, noteID: note.id) }
        Button("指定到今天") { store.scheduleToday(noteID: note.id) }
        Button("复制笔记") { store.duplicateNote(note.id) }
        Divider()
        Button("复制摘要") { if let s = store.summary(for: note.id) { copyToPasteboard(s) } }
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
    }

    private func selectNoteAfterSavingActiveEditor() {
        guard store.selectedNoteID != note.id else { return }

        let hadChanges = SharedBlockNoteWebView.shared.hasContentChanges
        SharedBlockNoteWebView.shared.saveCurrentContentNow { content in
            if hadChanges, let content, let activeNote = store.note(withID: content.noteID) {
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

            withAnimation(.easeInOut(duration: 0.12)) {
                prepareEditorOverlayForSelection()
                store.selectNote(note.id)
            }
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

// MARK: - Menu Folder Icon (with hover)

private struct MenuFolderIcon: View {
    @State private var isHovering = false

    var body: some View {
        Image(systemName: "folder")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(isHovering ? AgendaColor.amber : Color(red: 0.118, green: 0.118, blue: 0.118))
            .frame(width: 36, height: 36)
            .background(Color.white, in: Circle())
            .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
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

@MainActor
private func sortPopoverContent(store: ObservableLibraryStore, showSortPopover: Binding<Bool>) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        ForEach(NoteSortOrder.allCases, id: \.self) { order in
            Button {
                store.sortOrder = order
                showSortPopover.wrappedValue = false
            } label: {
                HStack {
                    Text(order.title)
                    Spacer()
                    if store.sortOrder == order {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AgendaColor.amber)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    .font(.custom("Avenir Next", size: 13))
    .padding(.vertical, 4)
    .frame(width: 180)
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
            text = tf.stringValue
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

private struct SearchPopoverContent: View {
    @Binding var searchText: String
    @Environment(ObservableLibraryStore.self) private var store

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
                    text: $searchText,
                    placeholder: "搜索标题、正文、标签或人员",
                    onReturn: { handleNext() }
                )
                .frame(width: 180, height: 20)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AgendaColor.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 导航和计数行
            if summary.totalOccurrences > 0 {
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

                    Text("笔记 \(summary.currentNoteIndex)/\(summary.totalMatchedNotes)")
                        .font(.custom("Avenir Next", size: 11))
                        .foregroundStyle(AgendaColor.textMuted)
                }
            } else if !searchText.isEmpty {
                Text("无匹配结果")
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(AgendaColor.textMuted)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(width: 320)
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                SharedBlockNoteWebView.shared.clearSearch()
            }
        }
        .onChange(of: store.searchOccurrences.count) { _, newCount in
            // Fire searchInEditor only after calculateSearchOccurrences
            // completes (180ms debounced in ObservableLibraryStore).
            // This avoids the double-debounce race where the old 250ms
            // timer could fire before occurrences were ready.
            guard !searchText.isEmpty, newCount > 0 else { return }
            let q = store.library.searchHighlightText
            guard !q.isEmpty else { return }
            SharedBlockNoteWebView.shared.searchInEditor(query: q) { _ in }
        }
    }

    // MARK: - Navigation helpers

    private func handleNext() {
        store.goToNextSearchOccurrence()
        syncEditorHighlight()
    }

    private func handlePrevious() {
        store.goToPreviousSearchOccurrence()
        syncEditorHighlight()
    }

    /// 引擎跳转后，同步编辑器的橙色高亮到当前 occurrence。
    /// - 同笔记 body：直接 navigateToMatch
    /// - 跨笔记：新编辑器的 onReady 会在 searchInEditor 完成后 navigateToMatch
    /// - title：编辑器里没有对应 DOM 高亮，回退到本条笔记的第一个 body 匹配
    ///   作为视觉锚点（navigateToMatch JS 会做边界检查，无 body 匹配时安全跳过）
    private func syncEditorHighlight() {
        guard let occ = store.currentOccurrence else { return }
        let index: Int = occ.field == .body ? occ.bodyIndexInNote : 0
        SharedBlockNoteWebView.shared.navigateToMatch(index: index) { _, _ in }
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
                    RoundedRectangle(cornerRadius: 1)
                        .fill(AgendaColor.cardDragHandle)
                        .frame(width: 24, height: 3)
                        .padding(.top, 6)
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
                    .draggable(DragPayload(noteID: note.id)) {
                        CardDragPreview(note: note)
                    }
                    .dropDestination(for: DragPayload.self) { items, location in
                        handleDrop(items: items, location: location)
                    } isTargeted: { targeted in
                        isDropTargeted = targeted
                    }
            }
            .onHover { isHovering = $0 }
            .onTapGesture { onTap() }
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

        onBeforeDrop()

        let insertBefore = location.y < cardHeight / 2
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
            AgendadaFloatingMenuItem(iconSystemName: "printer", title: "打印...") { _ in printNote() }
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

    private func printNote() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
        textView.string = "\(note.title)\n\n\(note.bodyPlainText)"
        let printInfo = NSPrintInfo.shared
        printInfo.topMargin = 36; printInfo.bottomMargin = 36
        printInfo.leftMargin = 36; printInfo.rightMargin = 36
        let printOp = NSPrintOperation(view: textView, printInfo: printInfo)
        printOp.runModal(for: NSApp.keyWindow ?? NSWindow(), delegate: nil, didRun: nil, contextInfo: nil)
    }
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
                ) { _ in printNote() },
                AgendadaFloatingMenuItem(iconSystemName: "rectangle.dashed", title: "存储为模板..."
                ) { _ in saveAsTemplate() }
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

    private func printNote() {
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
        tv.string = "\(note.title)\n\n\(note.bodyPlainText)"
        let pi = NSPrintInfo.shared; pi.topMargin = 36; pi.bottomMargin = 36
        pi.leftMargin = 36; pi.rightMargin = 36
        NSPrintOperation(view: tv, printInfo: pi).runModal(for: NSApp.keyWindow ?? NSWindow(), delegate: nil, didRun: nil, contextInfo: nil)
    }

    private func saveAsTemplate() {
        let alert = NSAlert()
        alert.messageText = "存储为模板"
        alert.informativeText = "保存当前笔记为可复用的模板"
        alert.alertStyle = .informational
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        tf.placeholderString = "模板名称"; tf.stringValue = note.title
        alert.accessoryView = tf
        alert.addButton(withTitle: "保存"); alert.addButton(withTitle: "取消")
        guard let win = NSApp.keyWindow else { return }
        alert.beginSheetModal(for: win) { resp in
            if resp == .alertFirstButtonReturn {
                let name = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                store.addCustomNoteTemplate(name: name, from: note)
            }
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
