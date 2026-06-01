import AgendadaCore
import AppKit
import SwiftUI

struct NoteStreamView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @Binding var searchText: String
    @State private var isSearching = false
    @State private var showSortPopover = false
    @State private var showMoveMenu = false

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

    private var searchButton: some View {
        HoverableCircleButton(systemName: "magnifyingglass", help: "搜索", action: { isSearching = true })
            .popover(isPresented: $isSearching, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AgendaColor.textMuted)
                    TextField("搜索标题、正文、标签或人员", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.custom("Avenir Next", size: 13))
                        .frame(width: 220)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            SharedBlockNoteWebView.shared.clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AgendaColor.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
            }
            .frame(width: 300)
            .agendadaGlassPopover()
        }
    }

    private var plusButton: some View {
        Button {
            store.addNote(template: .blank)
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
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(notes) { note in
                    StreamNoteRow(note: note)
                        .id(note.id).padding(.bottom, AgendaSpacing.cardGap)
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
    }

}

// MARK: - Card Title

private struct AgendadaCardTitle: View {
    let title: String
    @Binding var draftTitle: String
    let isSelected: Bool
    let isDimmed: Bool

    private var fgColor: Color {
        isDimmed ? .secondary : Color(red: 0.102, green: 0.102, blue: 0.102)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Preview — always in layout, determines HStack height & baseline.
            Text(title.isEmpty ? "无标题" : title)
                .font(AgendaFont.cardTitle)
                .foregroundStyle(fgColor)
                .lineLimit(1)
                .opacity(isSelected ? 0 : 1)
                .allowsHitTesting(false)
            // Editor — custom NSTextField that never shifts on focus.
            StableTextField(
                text: $draftTitle,
                placeholder: "无标题",
                font: NSFont(name: "Avenir Next", size: 20) ?? .systemFont(ofSize: 20),
                textColor: isDimmed ? .secondaryLabelColor : NSColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1),
                isEnabled: isSelected
            )
            .opacity(isSelected ? 1 : 0)
        }
    }
}

// MARK: - Stable TextField (no focus-ring baseline shift)

private struct StableTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let font: NSFont
    let textColor: NSColor
    let isEnabled: Bool

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
        if tf.stringValue != text {
            tf.stringValue = text
        }
        tf.font = font
        tf.textColor = textColor
        // isEnabled controls whether it can become first responder
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
    @State private var isHovering = false
    @State private var editorIsVisible = false
    @State private var initialBlockJSON: Data?
    @State private var skipNextCardTap = false
    @State private var showDatePicker = false
    @State private var datePickerDismissedAt = Date.distantPast
    @State private var showBulletMenu = false
    @State private var bulletMenuSections: [AgendadaFloatingMenuSection] = []
    @State private var bulletMenuPresenter = AgendadaFloatingMenuPresenter()
    @State private var bulletMenuDismissedAt = Date.distantPast
    @State private var showSettingsPopover = false
    @State private var settingsMenuOpenPending = false
    @State private var settingsMenuDismissedAt = Date.distantPast
    @State private var settingsMenuSections: [AgendadaFloatingMenuSection] = []
    @State private var settingsMenuPresenter = AgendadaFloatingMenuPresenter()

    init(note: Note) {
        self.note = note
        let d = StreamNoteDraft(note: note)
        _draft = State(initialValue: d)
        _initialDraft = State(initialValue: d)
    }

    private var isSelected: Bool { store.selectedNoteID == note.id }
    private let bulletCol: CGFloat = 24

    private var datePickerPanel: some View {
        DateAgendaPanelView(noteID: note.id) {
            if let updated = store.note(withID: note.id) {
                draft = StreamNoteDraft(note: updated)
                initialDraft = draft
            }
            showDatePicker = false
        }
        .agendadaGlassPopover(cornerRadius: 18)
    }

    private var settingsPopoverContent: some View {
        AgendadaFloatingMenuView(
            sections: settingsMenuSections.isEmpty ? settingsFloatingMenuSections() : settingsMenuSections,
            presenter: settingsMenuPresenter,
            width: 214
        )
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 10) {
            bulletIcon.frame(width: bulletCol, alignment: .leading).padding(.top, 1)
            HStack(alignment: .firstTextBaseline) {
                AgendadaCardTitle(
                    title: note.title,
                    draftTitle: $draft.title,
                    isSelected: isSelected,
                    isDimmed: isNoteDimmed
                )
                Spacer(minLength: 8)
                dateControl
            }
        }
    }

    @ViewBuilder
    private var dateControl: some View {
        if !dateLabel.isEmpty {
            Button { toggleDatePicker() } label: {
                Text(dateLabel)
                    .font(.custom(dateFontName, size: 13))
                    .foregroundStyle(dateColor)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDatePicker, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) {
                datePickerPanel
            }
        } else if isSelected {
            Button { toggleDatePicker() } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundStyle(AgendaColor.textMuted)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDatePicker, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) {
                datePickerPanel
            }
            .buttonStyle(.plain)
        }
    }

    private var cardBase: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            bodyContent.padding(.top, 6)
            }
        .padding(.horizontal, 20).padding(.vertical, 16).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? AgendaColor.cardActiveFill : .clear))
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
            if isSelected {
                RoundedRectangle(cornerRadius: 1).fill(AgendaColor.cardDragHandle).frame(width: 24, height: 3).padding(.top, 6)
            }
        }
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
        .shadow(color: isSelected ? .black.opacity(0.04) : .clear, radius: 4, x: 0, y: 2)
        .padding(.horizontal, 20).contentShape(Rectangle())
        .contextMenu { contextMenuContent }
    }

    var body: some View {
        cardBase
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            showDatePicker = false
            settingsMenuOpenPending = false
            showSettingsPopover = false
        }
        .onChange(of: showDatePicker) { _, isPresented in
            if !isPresented {
                datePickerDismissedAt = Date()
            }
        }
        .onChange(of: showSettingsPopover) { _, isPresented in
            if !isPresented {
                settingsMenuDismissedAt = Date()
            }
        }
        .onHover { isHovering = $0 }
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
                // Reset editor height when deselected to prevent it from affecting other notes
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
        // Always use preview height to avoid height jumping. Editor height is only used internally.
        let cardHeight = capturedPreviewHeight

        return ZStack(alignment: .topLeading) {
            // Preview — always present, measures its natural height for card sizing.
            BlockNotePreviewView(note: note)
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
                    if h > 0 { capturedPreviewHeight = h }
                }

            // Editor
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
                    onReady: { editorIsVisible = true }
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: cardHeight, alignment: .top)
                .opacity(editorIsVisible ? (isNoteDimmed ? 0.58 : 1) : 0)
            }
        }
        .frame(height: cardHeight, alignment: .top)
        .padding(.bottom, 60)
    }

    // MARK: - Bullet

    private var bulletIcon: some View {
        let color = noteColorValue(note.noteColor)
        let inBatch = store.isInBatchMode
        let isBatchSelected = store.batchSelectedNoteIDs.contains(note.id)
        let isCompleted = note.status == .completed
        let isBrief = note.isBrief

        return ZStack {
            if inBatch {
                Image(systemName: isBatchSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isBatchSelected ? AgendaColor.amber : AgendaColor.textMuted)
                    .transition(.scale.combined(with: .opacity))
            } else {
                // Outer hover ring
                if isHovering || isSelected {
                    Circle()
                        .stroke(color, lineWidth: 1)
                        .frame(width: 20, height: 20)
                        .transition(.scale.combined(with: .opacity))
                }

                // Main bullet icon based on status
                if isBrief {
                    // Brief (简达) = solid circle
                    if isCompleted {
                        // Brief + Completed = solid circle with white checkmark
                        ZStack {
                            Circle().fill(color).frame(width: 14, height: 14)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    } else {
                        Circle().fill(color).frame(width: 14, height: 14)
                    }
                } else {
                    // Normal note = stroke circle
                    Circle().stroke(color, lineWidth: 1).frame(width: 14, height: 14)
                    if isCompleted {
                        // Completed = checkmark in circle
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(color)
                    }
                }
            }
        }
        .frame(width: bulletCol, height: 24)
        .contentShape(Rectangle())
        .onTapGesture {
            skipNextCardTap = true
            if inBatch {
                store.toggleBatchSelection(noteID: note.id)
            } else {
                toggleBulletMenu()
            }
        }
        .popover(isPresented: $showBulletMenu, attachmentAnchor: .point(.trailing), arrowEdge: .trailing) {
            AgendadaFloatingMenuView(
                sections: bulletMenuSections,
                presenter: bulletMenuPresenter,
                width: 214
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            showBulletMenu = false
        }
        .onChange(of: showBulletMenu) { _, isPresented in
            if !isPresented {
                bulletMenuDismissedAt = Date()
            }
        }
        .animation(.easeOut(duration: 0.15), value: inBatch)
        .animation(.easeOut(duration: 0.15), value: isBatchSelected)
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }

    private func toggleDatePicker() {
        if showDatePicker {
            showDatePicker = false
            return
        }
        guard Date().timeIntervalSince(datePickerDismissedAt) > 0.18 else { return }

        showDatePicker = true
    }

    private func handleCardTap() {
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

    private func toggleBulletMenu() {
        if showBulletMenu {
            showBulletMenu = false
            return
        }
        guard Date().timeIntervalSince(bulletMenuDismissedAt) > 0.18 else { return }

        // Reset presenter state to ensure clean start
        bulletMenuPresenter.reset()

        bulletMenuPresenter.configure(
            dismiss: { showBulletMenu = false },
            showSubmenu: { _ in },
            popToRoot: {}
        )
        bulletMenuSections = bulletFloatingMenuSections()
        showBulletMenu = true
    }

    private func toggleSettingsMenu() {
        if showSettingsPopover || settingsMenuOpenPending {
            settingsMenuOpenPending = false
            showSettingsPopover = false
            return
        }
        guard Date().timeIntervalSince(settingsMenuDismissedAt) > 0.18 else { return }

        // Reset presenter state to ensure clean start
        settingsMenuPresenter.reset()

        settingsMenuOpenPending = true
        settingsMenuPresenter.configure(
            dismiss: {
                settingsMenuOpenPending = false
                showSettingsPopover = false
            },
            showSubmenu: { _ in },
            popToRoot: {}
        )
        settingsMenuSections = settingsFloatingMenuSections()
        DispatchQueue.main.async {
            guard settingsMenuOpenPending else { return }
            settingsMenuOpenPending = false
            showSettingsPopover = true
        }
    }

    private func settingsFloatingMenuSections() -> [AgendadaFloatingMenuSection] {
        [
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "circle",
                    title: "标记",
                    showsSubmenuIndicator: true,
                    dismissesAfterAction: false
                ) { presenter in
                    presenter.showSubmenu(sections: markFloatingMenuSections(), title: "标记")
                }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "doc.on.clipboard",
                    title: "拷贝为...",
                    showsSubmenuIndicator: true,
                    dismissesAfterAction: false
                ) { presenter in
                    presenter.showSubmenu(sections: copyAsFloatingMenuSections(), title: "拷贝为:")
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "folder.badge.arrow.right",
                    title: "移动到...",
                    showsSubmenuIndicator: true,
                    dismissesAfterAction: false
                ) { presenter in
                    presenter.showSubmenu(sections: moveProjectFloatingMenuSections(), title: "移动笔记到:")
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "plus.square.on.square",
                    title: "复制"
                ) { _ in
                    store.duplicateNote(note.id)
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "arrow.branch",
                    title: "开始新笔记"
                ) { _ in
                    let noteID = store.addNoteReturningID()
                    store.selectNote(noteID)
                }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "square.and.arrow.up",
                    title: "分享...",
                    showsSubmenuIndicator: true,
                    dismissesAfterAction: false
                ) { presenter in
                    presenter.showSubmenu(sections: shareAsFloatingMenuSections(), title: "分享为:")
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "printer",
                    title: "打印..."
                ) { _ in
                    printNote()
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "rectangle.dashed",
                    title: "存储为模板..."
                ) { _ in
                    // Template management has a dedicated UI planned; keep the entry visible for layout parity.
                }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "info.circle",
                    title: "显示信息...",
                    subtitle: editedAtInfoSubtitle,
                    showsSubmenuIndicator: true,
                    dismissesAfterAction: false
                ) { presenter in
                    presenter.showSubmenu(sections: noteInfoFloatingMenuSections(), title: "显示信息...")
                }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "trash",
                    title: "移到废纸篓",
                    role: .destructive
                ) { _ in
                    store.deleteNote(note.id)
                }
            ])
        ]
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

    private func statusFloatingMenuSections() -> [AgendadaFloatingMenuSection] {
        [
            AgendadaFloatingMenuSection(items: NoteStatus.allCases.map { status in
                AgendadaFloatingMenuItem(
                    iconSystemName: draft.status == status ? "checkmark.circle.fill" : "circle",
                    title: status.title
                ) { _ in
                    draft.status = status
                    store.setStatus(status, noteID: note.id)
                }
            })
        ]
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

    private func dateFloatingMenuSections() -> [AgendadaFloatingMenuSection] {
        var items = [
            AgendadaFloatingMenuItem(
                iconSystemName: "calendar.badge.clock",
                title: "指定到今天"
            ) { _ in
                store.scheduleToday(noteID: note.id)
                resetDraft()
            }
        ]

        if note.scheduledDate != nil {
            items.append(
                AgendadaFloatingMenuItem(
                    iconSystemName: "calendar.badge.minus",
                    title: "移除日期"
                ) { _ in
                    store.clearScheduledDate(noteID: note.id)
                    resetDraft()
                }
            )
        }

        return [AgendadaFloatingMenuSection(items: items)]
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

    private func bulletFloatingMenuSections() -> [AgendadaFloatingMenuSection] {
        markFloatingMenuSections() + [
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "gearshape",
                    title: "其他操作",
                    showsSubmenuIndicator: true,
                    dismissesAfterAction: false
                ) { presenter in
                    presenter.showSubmenu(sections: moreActionsFloatingMenuSections())
                }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "checklist",
                    title: "批量选择..."
                ) { _ in
                    store.toggleBatchSelection(noteID: note.id)
                }
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

    private func moreActionsFloatingMenuSections() -> [AgendadaFloatingMenuSection] {
        var firstSection: [AgendadaFloatingMenuItem] = [
            AgendadaFloatingMenuItem(
                iconSystemName: "doc.on.doc",
                title: "拷贝笔记"
            ) { _ in
                store.duplicateNote(note.id)
            }
        ]

        if !store.projects.isEmpty {
            firstSection.append(
                AgendadaFloatingMenuItem(
                    iconSystemName: "folder",
                    title: "移动到项目",
                    showsSubmenuIndicator: true,
                    dismissesAfterAction: false
                ) { presenter in
                    presenter.showSubmenu(sections: moveProjectFloatingMenuSections(), title: "移动笔记到:")
                }
            )
        }

        firstSection.append(contentsOf: [
            AgendadaFloatingMenuItem(
                iconSystemName: "square.and.arrow.up",
                title: "分享...",
                showsSubmenuIndicator: true,
                dismissesAfterAction: false
            ) { presenter in
                presenter.showSubmenu(sections: shareAsFloatingMenuSections(), title: "分享为:")
            },
            AgendadaFloatingMenuItem(
                iconSystemName: "printer",
                title: "打印..."
            ) { _ in
                printNote()
            }
        ])

        return [
            AgendadaFloatingMenuSection(items: firstSection),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "trash",
                    title: "移到废纸篓",
                    role: .destructive
                ) { _ in
                    store.deleteNote(note.id)
                }
            ])
        ]
    }

    private func moveProjectFloatingMenuSections() -> [AgendadaFloatingMenuSection] {
        var sections: [AgendadaFloatingMenuSection] = [
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "arrow.up",
                    title: "上一条笔记前",
                    isEnabled: false
                ) { _ in },
                AgendadaFloatingMenuItem(
                    iconSystemName: "arrow.down",
                    title: "下一条笔记后",
                    isEnabled: false
                ) { _ in }
            ]),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "arrow.up.to.line",
                    title: "第一条笔记前",
                    isEnabled: false
                ) { _ in },
                AgendadaFloatingMenuItem(
                    iconSystemName: "arrow.down.to.line",
                    title: "最后一条笔记后",
                    isEnabled: false
                ) { _ in }
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

    private var dateColor: Color {
        (isSelected || isHovering || isToday) ? AgendaColor.amber : AgendaColor.textMuted
    }

    private var dateFontName: String {
        (isSelected || isHovering || isToday) ? "Avenir Next Medium" : "Avenir Next"
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
            Button {
                skipNextCardTap = true
                toggleSettingsMenu()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AgendaColor.amber)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("更多操作")
            .popover(isPresented: $showSettingsPopover, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                settingsPopoverContent
            }
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
        AgendadaFloatingMenuSection(items: NoteSortOrder.allCases.map { order in
            AgendadaFloatingMenuItem(
                iconSystemName: store.sortOrder == order ? "checkmark" : "circle",
                title: order.title
            ) { _ in
                store.sortOrder = order
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

// MARK: - Search Popover Content

private struct SearchPopoverContent: View {
    @Binding var searchText: String
    @Environment(ObservableLibraryStore.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AgendaColor.textMuted)
            TextField("搜索标题、正文、标签或人员", text: $searchText)
                .textFieldStyle(.plain)
                .font(.custom("Avenir Next", size: 13))
                .frame(width: 220)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    SharedBlockNoteWebView.shared.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AgendaColor.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(width: 300)
    }
}

// MARK: - Bullet Menu State
