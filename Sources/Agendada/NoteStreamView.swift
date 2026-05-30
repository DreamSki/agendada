import AgendadaCore
import AppKit
import SwiftUI

struct NoteStreamView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @Binding var searchText: String
    @State private var isSearching = false
    @State private var showSortPopover = false

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
        }
    }

    private var headerActions: some View {
        HStack(spacing: 12) {
            sortButton
            glassIconButton(systemName: "sparkles", action: { copyToPasteboard(store.summaryForFilteredNotes()) }, help: "复制摘要")
            searchButton
            plusButton
        }
    }

    private var batchActions: some View {
        HStack(spacing: 12) {
            if store.selectedOverview == .trash {
                glassTextButton("恢复", action: { store.batchRestoreNotes(store.batchSelectedNoteIDs) })
                glassTextButton("彻底删除", role: .destructive, action: { store.batchPermanentlyDeleteNotes(store.batchSelectedNoteIDs) })
            } else {
                glassTextButton("废纸篓", role: .destructive, action: { store.batchDeleteNotes(store.batchSelectedNoteIDs) })
                if !store.projects.isEmpty {
                    Menu {
                        ForEach(store.projects) { project in
                            Button(project.name) {
                                store.moveNotes(store.batchSelectedNoteIDs, toProject: project.id)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("移动到")
                                .font(.custom("Avenir Next", size: 14))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(Color(red: 0.118, green: 0.118, blue: 0.118))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                    }
                    .menuStyle(.borderlessButton)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                }
            }
            glassTextButton("取消", action: { store.deselectAllNotes() })
        }
    }

    private var sortButton: some View {
        Button { showSortPopover = true } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(red: 0.118, green: 0.118, blue: 0.118))
        .background(.ultraThinMaterial, in: Circle())
        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
        .help("排序方式")
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
        }
    }

    private var searchButton: some View {
        Button { isSearching = true } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSearching ? AgendaColor.amber : Color(red: 0.118, green: 0.118, blue: 0.118))
        .background(.ultraThinMaterial, in: Circle())
        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
        .help("搜索")
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
            .background(.regularMaterial)
        }
    }

    private var plusButton: some View {
        Button {
            store.addNote(template: .blank)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AgendaColor.amber)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: Circle())
        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
        .help("新建笔记")
        .keyboardShortcut("n", modifiers: [.command])
    }

    private func glassIconButton(systemName: String, action: @escaping () -> Void, help: String) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(red: 0.118, green: 0.118, blue: 0.118))
        .background(.ultraThinMaterial, in: Circle())
        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
        .help(help)
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
            VStack(alignment: .leading, spacing: 0) {
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
    @State private var showSettingsPopover = false

    init(note: Note) {
        self.note = note
        let d = StreamNoteDraft(note: note)
        _draft = State(initialValue: d)
        _initialDraft = State(initialValue: d)
    }

    private var isSelected: Bool { store.selectedNoteID == note.id }
    private let bulletCol: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    if !dateLabel.isEmpty {
                        Button { showDatePicker = true } label: {
                            Text(dateLabel)
                                .font(.custom(dateFontName, size: 13))
                                .foregroundStyle(dateColor)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showDatePicker, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) {
                            DateAgendaPanelView(noteID: note.id) {
                                if let updated = store.note(withID: note.id) {
                                    draft = StreamNoteDraft(note: updated)
                                    initialDraft = draft
                                }
                                showDatePicker = false
                            }
                        }
                    } else if isSelected {
                        Button { showDatePicker = true } label: {
                            Image(systemName: "calendar")
                                .font(.system(size: 13))
                                .foregroundStyle(AgendaColor.textMuted)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showDatePicker, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) {
                            DateAgendaPanelView(noteID: note.id) {
                                if let updated = store.note(withID: note.id) {
                                    draft = StreamNoteDraft(note: updated)
                                    initialDraft = draft
                                }
                                showDatePicker = false
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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
        .onHover { isHovering = $0 }
        .onTapGesture {
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
        .onChange(of: draft.title) { scheduleSaveDraft() }
        .onChange(of: draft.hasScheduledDate) { scheduleSaveDraft() }
        .onChange(of: draft.scheduledDate) { scheduleSaveDraft() }
        .onChange(of: draft.tagsText) { scheduleSaveDraft() }
        .onChange(of: draft.peopleText) { scheduleSaveDraft() }
        .onChange(of: draft.status) { scheduleSaveDraft() }
        .onChange(of: store.selectedNoteID) { oldValue, newValue in
            if oldValue == note.id && newValue != note.id {
                flushDraft()
            } else if newValue == note.id {
                resetDraft()
                prepareEditorOverlayForSelection()
            }
        }
        .onChange(of: note.id) { resetDraft() }
        .onDisappear { flushDraft() }
    }

    // MARK: - Body

    private var bodyContent: some View {
        let cardHeight = max(capturedPreviewHeight, editorHeight)

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

        return ZStack {
            if inBatch {
                Image(systemName: isBatchSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isBatchSelected ? AgendaColor.amber : AgendaColor.textMuted)
            } else {
                if isHovering || isSelected {
                    Circle()
                        .stroke(color, lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
                if note.bodyPlainText.isEmpty {
                    Circle().fill(color).frame(width: 10, height: 10)
                } else {
                    Circle().stroke(color, lineWidth: 1).frame(width: 14, height: 14)
                }
            }
        }
        .frame(width: bulletCol, height: 24)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isHovering || isSelected)
        .contentShape(Rectangle())
        .onTapGesture {
            store.toggleBatchSelection(noteID: note.id)
            skipNextCardTap = true
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
                showSettingsPopover = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AgendaColor.amber)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .popover(isPresented: $showSettingsPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Picker("状态", selection: $draft.status) {
                        ForEach(NoteStatus.allCases, id: \.self) { s in Text(s.title).tag(s) }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    Divider()
                    Button(action: {
                        store.setStarred(!note.isStarred, noteID: note.id)
                        showSettingsPopover = false
                    }) {
                        HStack { Text(note.isStarred ? "取消标星" : "标星"); Spacer() }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    Menu("颜色标记") {
                        Button("无") { store.setNoteColor(nil, noteID: note.id); showSettingsPopover = false }
                        ForEach(NoteColor.allCases, id: \.self) { c in
                            Button(c.title) { store.setNoteColor(c, noteID: note.id); showSettingsPopover = false }
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    Menu("置顶/置底") {
                        Button(note.pinState == .pinnedTop ? "取消置顶" : "置顶") {
                            store.setPinState(note.pinState == .pinnedTop ? .none : .pinnedTop, noteID: note.id)
                            showSettingsPopover = false
                        }
                        Button(note.pinState == .pinnedBottom ? "取消置底" : "置底") {
                            store.setPinState(note.pinState == .pinnedBottom ? .none : .pinnedBottom, noteID: note.id)
                            showSettingsPopover = false
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    Menu("日期") {
                        Button("指定到今天") { store.scheduleToday(noteID: note.id); resetDraft(); showSettingsPopover = false }
                        if note.scheduledDate != nil {
                            Button("移除日期") {
                                store.updateNote(noteID: note.id, title: note.title, body: note.body, scheduledDate: nil, tags: note.tags, people: note.people, status: note.status)
                                resetDraft()
                                showSettingsPopover = false
                            }
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    Button(action: {
                        if let s = store.summary(for: note.id) { copyToPasteboard(s) }
                        showSettingsPopover = false
                    }) {
                        HStack { Text("复制摘要"); Spacer() }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    Divider()
                    Button(role: .destructive, action: {
                        store.deleteNote(note.id)
                        showSettingsPopover = false
                    }) {
                        HStack { Text("删除笔记"); Spacer() }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                }
                .font(.custom("Avenir Next", size: 13))
                .frame(width: 200)
                .padding(.vertical, 4)
            }
        }.foregroundStyle(AgendaColor.amber)
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
        print("[TAP-DEBUG] selectNote called note=\(note.id.uuidString.prefix(6)) currentSelected=\(store.selectedNoteID?.uuidString.prefix(6) ?? "nil")")
        guard store.selectedNoteID != note.id else { print("[TAP-DEBUG]   -> already selected, skip"); return }

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
                print("[TAP-DEBUG]   -> selecting note \(note.id.uuidString.prefix(6))")
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
