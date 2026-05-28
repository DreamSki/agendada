import AgendadaCore
import AppKit
import SwiftUI

struct NoteStreamView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @Binding var searchText: String
    @State private var isSearching = false
    @State private var editorHeight: CGFloat = 180
    @State private var capturedPreviewHeight: CGFloat = 180
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            streamHeader
            noteStreamContent
        }
        .background(Color.white)
    }

    // MARK: - Header

    private var streamHeader: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    if let categoryName = breadcrumbCategoryName {
                        Text(categoryName)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(AgendaColor.textMuted)
                    }
                    Text(mainTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 0.173, green: 0.173, blue: 0.180))
                    if let context = breadcrumbContext {
                        Text(context)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(AgendaColor.textMuted)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                Spacer()
                HStack(spacing: 16) {
                    Button {
                        copyToPasteboard(store.summaryForFilteredNotes())
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .buttonStyle(.plain).foregroundStyle(AgendaColor.textMuted).help("复制摘要")
                    Button { withAnimation(.easeInOut(duration: 0.16)) { isSearching.toggle() } } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .buttonStyle(.plain).foregroundStyle(AgendaColor.textMuted).help("搜索")
                    Button {
                        store.addNote(template: .blank)
                    } label: {
                        Circle()
                            .fill(AgendaColor.amber).frame(width: 28, height: 28)
                            .overlay { Image(systemName: "plus").font(.system(size: 18, weight: .heavy)).foregroundStyle(.white) }
                            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain).help("新建笔记").keyboardShortcut("n", modifiers: [.command])
                }
            }
            .padding(.horizontal, 32).padding(.top, 16)

            if isSearching {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AgendaColor.textMuted)
                    TextField("搜索标题、正文、标签或人员", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AgendaColor.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.045)))
                .padding(.horizontal, 32)
                .padding(.top, 10)
            }
        }
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
                        .id(note.id).padding(.bottom, 32)
                }
            }
            .padding(.horizontal, 12).padding(.top, 16).padding(.bottom, 80)
        }
    }
}

// MARK: - Note Row

private struct StreamNoteRow: View {
    @Environment(ObservableLibraryStore.self) private var store
    let note: Note

    @State private var draft: StreamNoteDraft
    @State private var showDatePicker = false
    @State private var calendarMonth = Date()
    @State private var saveTask: Task<Void, Never>?
    @State private var editorHeight: CGFloat = 180
    @State private var capturedPreviewHeight: CGFloat = 180
    @State private var isHovering = false

    init(note: Note) {
        self.note = note
        _draft = State(initialValue: StreamNoteDraft(note: note))
    }

    private var isSelected: Bool { store.selectedNoteID == note.id }
    private let bulletCol: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                bulletIcon.frame(width: bulletCol, alignment: .leading)
                HStack(alignment: .center) {
                    Text(note.title.isEmpty ? "无标题" : note.title)
                        .font(.system(size: 18, weight: note.bodyPlainText.isEmpty ? .semibold : .bold))
                        .foregroundStyle(isNoteDimmed ? .secondary : Color(red: 0.102, green: 0.102, blue: 0.102))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if !dateLabel.isEmpty {
                        Text(dateLabel)
                            .font(.system(size: 13, weight: isToday ? .medium : .regular))
                            .foregroundStyle(isToday ? AgendaColor.amber : AgendaColor.textMuted)
                    }
                }
            }
            bodyContent.padding(.top, 16)
        }
        .padding(24).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? AgendaColor.cardActiveFill : .clear))
        .overlay(alignment: .top) {
            if isSelected {
                RoundedRectangle(cornerRadius: 1).fill(AgendaColor.cardDragHandle).frame(width: 24, height: 3).padding(.top, 6)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isSelected || isHovering { actionMenu.padding(16) }
        }
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? AgendaColor.cardActiveBorder : .clear, lineWidth: 1.5))
        .shadow(color: isSelected ? .black.opacity(0.04) : .clear, radius: 4, x: 0, y: 2)
        .padding(.horizontal, 20).contentShape(Rectangle())
        .contextMenu { contextMenuContent }
        .onHover { isHovering = $0 }
        .onTapGesture { selectNoteAfterSavingActiveEditor() }
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
            }
        }
        .onChange(of: note.id) { resetDraft() }
        .onDisappear { flushDraft() }
    }

    // MARK: - Body

    @ViewBuilder
    private var bodyContent: some View {
        if isSelected {
            BlockNoteCardEditor(
                noteID: note.id,
                blockJSON: draft.blockJSON,
                editorHeight: $editorHeight,
                onChange: { content in
                    applyEditorContent(content)
                },
                onDebouncedSave: { content in
                    applyEditorContent(content)
                    saveDraft()
                }
            )
            .frame(height: max(capturedPreviewHeight, editorHeight))
        } else {
            BlockNotePreviewView(note: note)
                .opacity(isNoteDimmed ? 0.58 : 1)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: PreviewHeightKey.self, value: geo.size.height)
                    }
                )
                .onPreferenceChange(PreviewHeightKey.self) { h in
                    capturedPreviewHeight = h
                }
        }
    }

    // MARK: - Bullet

    private var bulletIcon: some View {
        let color = noteColorValue(note.noteColor)
        return ZStack {
            if isSelected {
                Image(systemName: "target").font(.system(size: 18, weight: .medium)).foregroundStyle(color)
            } else if note.bodyPlainText.isEmpty {
                Circle().fill(color).frame(width: 9, height: 9)
            } else {
                Circle().stroke(color, lineWidth: 1.5).frame(width: 12, height: 12)
            }
        }.frame(width: bulletCol, height: 16)
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

    // MARK: - Action Menu

    private var actionMenu: some View {
        HStack(spacing: 12) {
            Button { store.duplicateNote(note.id) } label: {
                Image(systemName: "doc.on.doc").font(.system(size: 16, weight: .medium))
            }.buttonStyle(.plain).help("复制笔记")
            Menu {
                Picker("状态", selection: $draft.status) {
                    ForEach(NoteStatus.allCases, id: \.self) { s in Text(s.title).tag(s) }
                }
                Divider()
                Button(note.isStarred ? "取消标星" : "标星") { store.setStarred(!note.isStarred, noteID: note.id) }
                Menu("颜色标记") {
                    Button("无") { store.setNoteColor(nil, noteID: note.id) }
                    ForEach(NoteColor.allCases, id: \.self) { c in Button(c.title) { store.setNoteColor(c, noteID: note.id) } }
                }
                Menu("置顶/置底") {
                    Button(note.pinState == .pinnedTop ? "取消置顶" : "置顶") {
                        store.setPinState(note.pinState == .pinnedTop ? .none : .pinnedTop, noteID: note.id)
                    }
                    Button(note.pinState == .pinnedBottom ? "取消置底" : "置底") {
                        store.setPinState(note.pinState == .pinnedBottom ? .none : .pinnedBottom, noteID: note.id)
                    }
                }
                Menu("日期") {
                    Button("指定到今天") { store.scheduleToday(noteID: note.id); resetDraft() }
                    if note.scheduledDate != nil {
                        Button("移除日期") {
                            store.updateNote(noteID: note.id, title: note.title, body: note.body, scheduledDate: nil, tags: note.tags, people: note.people, status: note.status); resetDraft()
                        }
                    }
                }
                Button("复制摘要") { if let s = store.summary(for: note.id) { copyToPasteboard(s) } }
                Divider()
                Button("删除笔记", role: .destructive) { store.deleteNote(note.id) }
            } label: {
                Image(systemName: "gearshape").font(.system(size: 16, weight: .medium))
            }
            .menuStyle(.borderlessButton).frame(width: 24, height: 24)
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

    // MARK: - Date

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

    // MARK: - Date Panel

    private var customDatePanel: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selectedDate = draft.hasScheduledDate ? (draft.scheduledDate ?? today) : (note.scheduledDate ?? today)
        let days = daysInMonth(calendarMonth, calendar: calendar)
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: calendarMonth))!
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingEmpties = firstWeekday - 1

        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text(monthYearString(calendarMonth)).font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary)
                    Spacer()
                    Button { calendarMonth = today } label: {
                        Text("今天").font(.system(size: 11, weight: .medium)).foregroundStyle(AgendaColor.amber)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 4).fill(AgendaColor.amber.opacity(0.08)))
                    }.buttonStyle(.plain)
                    Button { if let prev = calendar.date(byAdding: .month, value: -1, to: calendarMonth) { calendarMonth = prev } }
                        label: { Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold)).frame(width: 24, height: 24) }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                    Button { if let next = calendar.date(byAdding: .month, value: 1, to: calendarMonth) { calendarMonth = next } }
                        label: { Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).frame(width: 24, height: 24) }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }.padding(.bottom, 12)
                HStack(spacing: 0) {
                    ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { d in
                        Text(d).font(.system(size: 11)).foregroundStyle(AgendaColor.textMuted).frame(width: 34, height: 22)
                    }
                }.padding(.bottom, 2)
                let totalCells = leadingEmpties + days
                let rows = Int(ceil(Double(totalCells) / 7.0))
                let notesOnDates = noteDatesInMonth(startOfMonth, days: days, calendar: calendar)
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let cellIndex = row * 7 + col
                            if cellIndex < leadingEmpties || cellIndex >= totalCells {
                                Color.clear.frame(width: 34, height: 32)
                            } else {
                                let day = cellIndex - leadingEmpties + 1
                                let cellDate = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)!
                                let isSel = calendar.isDate(cellDate, inSameDayAs: selectedDate)
                                let isTodayCell = calendar.isDate(cellDate, inSameDayAs: today)
                                let hasNotes = notesOnDates.contains(day)
                                Button {
                                    draft.hasScheduledDate = true; draft.scheduledDate = calendar.startOfDay(for: cellDate)
                                    scheduleSaveDraft(); showDatePicker = false
                                } label: {
                                    ZStack {
                                        if isSel { Circle().fill(AgendaColor.amber).frame(width: 24, height: 24) }
                                        Text("\(day)").font(.system(size: 13, weight: isSel ? .semibold : (isTodayCell ? .medium : .regular)))
                                            .foregroundStyle(isSel ? .white : (isTodayCell ? AgendaColor.amber : .primary))
                                    }.frame(width: 34, height: 32)
                                    .overlay(alignment: .bottom) {
                                        if hasNotes && !isSel { Circle().fill(AgendaColor.amber.opacity(0.6)).frame(width: 4, height: 4).padding(.bottom, 2) }
                                    }
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }.padding(18)
            Divider()
            HStack(spacing: 0) {
                if dateLabel.isEmpty == false {
                    Button { draft.hasScheduledDate = false; draft.scheduledDate = nil; scheduleSaveDraft(); showDatePicker = false }
                        label: { Text("清除日期").font(.system(size: 12)) }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") { draft.hasScheduledDate = note.scheduledDate != nil; draft.scheduledDate = note.scheduledDate; showDatePicker = false }
                    .buttonStyle(.plain).font(.system(size: 13)).foregroundStyle(.secondary).padding(.trailing, 12)
                Button("指定日期") { scheduleSaveDraft(); showDatePicker = false }
                    .buttonStyle(.plain).font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 5).fill(AgendaColor.amber))
            }.padding(.horizontal, 18).padding(.vertical, 10)
        }.frame(width: 272)
    }

    private func noteDatesInMonth(_ startOfMonth: Date, days: Int, calendar: Calendar) -> Set<Int> {
        guard let range = calendar.range(of: .day, in: .month, for: startOfMonth) else { return [] }
        var result = Set<Int>()
        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) else { continue }
            if store.filteredNotes().contains(where: { note in
                guard let d = note.scheduledDate else { return false }
                return calendar.isDate(d, inSameDayAs: date)
            }) { result.insert(day) }
        }
        return result
    }

    private func daysInMonth(_ date: Date, calendar: Calendar) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private func monthYearString(_ date: Date) -> String {
        let fm = DateFormatter(); fm.locale = Locale(identifier: "zh_CN"); fm.dateFormat = "yyyy年M月"
        return fm.string(from: date)
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
    }

    private func scheduleSaveDraft() {
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
        if let refreshed = store.note(withID: note.id) { draft = StreamNoteDraft(note: refreshed) }
    }

    private func applyEditorContent(_ content: BlockNoteEditorContent) {
        guard content.noteID == note.id else { return }
        draft.blockJSON = content.blockJSON
        draft.plainTextPreview = content.plainTextPreview
        draft.previewHTML = content.previewHTML
        draft.body = content.previewHTML ?? content.plainTextPreview
    }

    private func selectNoteAfterSavingActiveEditor() {
        guard store.selectedNoteID != note.id else { return }

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

            withAnimation(.easeInOut(duration: 0.12)) {
                store.selectNote(note.id)
            }
        }
    }

    private func splitList(_ text: String) -> [String] { splitCommaList(text) }
}

private struct PreviewHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 180
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
