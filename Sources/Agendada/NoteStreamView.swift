import AgendadaCore
import SwiftUI

struct NoteStreamView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @State private var smartOverviewSheet: SmartOverviewSheet?
    @State private var isSearchVisible = false
    @State private var showTagManager = false
    @Binding var searchText: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            noteStreamContent
                .padding(.top, 72)

            streamHeaderOverlay
        }
        .navigationTitle("")
        .background(Color.white)
        .sheet(item: $smartOverviewSheet) { sheet in
            SmartOverviewPromptSheet(sheet: sheet) { name, query in
                store.addSmartOverview(name: name, query: query)
                smartOverviewSheet = nil
            }
        }
        .sheet(isPresented: $showTagManager) {
            TagManagerView()
        }
    }

    // MARK: - Header

    private var streamHeaderOverlay: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                headerTitleBlock
                Spacer()
                toolbarCapsule
            }
            .padding(.horizontal, 32)
            .padding(.top, 14)

            if isSearchVisible || !searchText.isEmpty {
                VStack(spacing: 8) {
                    TextField("搜索", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    quickFilters
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
        }
    }

    private var headerTitleBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let categoryName = breadcrumbCategoryName {
                Text(categoryName)
                    .font(AgendaFont.breadcrumbCategory)
                    .foregroundStyle(AgendaColor.textMuted)
            }
            Text(mainTitle)
                .font(AgendaFont.breadcrumbTitle)
                .foregroundStyle(.primary)
            if let context = breadcrumbContext {
                Text(context)
                    .font(AgendaFont.breadcrumbContext)
                    .foregroundStyle(AgendaColor.textMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private var mainTitle: String {
        if let sid = store.selectedSmartOverviewID,
           let so = store.smartOverview(withID: sid) { return so.name }
        if let ov = store.selectedOverview { return ov.title }
        if let pid = store.selectedProjectID,
           let proj = store.project(withID: pid) { return proj.name }
        return store.activeTitle
    }

    private var breadcrumbCategoryName: String? {
        if store.selectedSmartOverviewID != nil { return nil }
        if store.selectedOverview != nil { return nil }
        if let pid = store.selectedProjectID,
           let proj = store.project(withID: pid),
           let cid = proj.categoryID,
           let cat = store.category(withID: cid) { return cat.name }
        return nil
    }

    private var breadcrumbContext: String? {
        if store.selectedSmartOverviewID != nil { return nil }
        if store.selectedOverview != nil { return "\(store.filteredNotes().count) 条笔记" }
        if let note = store.selectedNoteID.flatMap({ store.note(withID: $0) }) { return note.title }
        return nil
    }

    private var toolbarCapsule: some View {
        HStack(spacing: 0) {
            Button {
                copyToPasteboard(store.summaryMarkdownForFilteredNotes())
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 32, height: 32)
            }
            .help("复制摘要")

            Button {
                showTagManager = true
            } label: {
                Image(systemName: "tag")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 32, height: 32)
            }
            .help("标签管理")

            Button {
                withAnimation(.easeInOut(duration: 0.14)) { isSearchVisible.toggle() }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 32, height: 32)
            }
            .help("搜索")

            Button {
                store.addNote(template: .blank)
            } label: {
                ZStack {
                    Circle()
                        .fill(AgendaColor.amber)
                        .frame(width: 28, height: 28)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .help("新建笔记")
            .keyboardShortcut("n", modifiers: [.command])
        }
        .buttonStyle(.plain)
        .foregroundStyle(AgendaColor.textMuted)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial.opacity(0.4), in: Capsule())
    }

    // MARK: - Quick Filters

    @ViewBuilder
    private var quickFilters: some View {
        if !store.allTags.isEmpty || !store.allPeople.isEmpty || !searchText.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if !searchText.isEmpty {
                        Button { smartOverviewSheet = SmartOverviewSheet(query: searchText) } label: {
                            Label("保存为智能概览", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        Button { searchText = "" } label: {
                            Label("清除筛选", systemImage: "xmark.circle")
                        }
                    }
                    ForEach(store.allTags, id: \.self) { t in
                        Button { searchText = "tag:\(t)" } label: { Label(t, systemImage: "tag") }
                    }
                    ForEach(store.allPeople, id: \.self) { p in
                        Button { searchText = "person:\(p)" } label: { Label(p, systemImage: "person") }
                    }
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Stream

    private var noteStreamContent: some View {
        let notes = store.filteredNotes()

        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(notes) { note in
                        StreamNoteRow(note: note)
                            .id(note.id)
                            .padding(.bottom, 32)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 12)
                .padding(.bottom, 80)
            }
            .onChange(of: store.selectedNoteID) {
                if let id = store.selectedNoteID {
                    withAnimation(.easeInOut(duration: 0.16)) { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
    }
}

// MARK: - Note Row

private struct StreamNoteRow: View {
    @Environment(ObservableLibraryStore.self) private var store
    let note: Note

    @State private var draft: StreamNoteDraft
    @State private var isHovering = false
    @State private var showDatePicker = false
    @State private var calendarMonth = Date()
    @State private var saveTask: Task<Void, Never>?

    init(note: Note) {
        self.note = note
        _draft = State(initialValue: StreamNoteDraft(note: note))
    }

    private var isSelected: Bool { store.selectedNoteID == note.id }
    private let bulletCol: CGFloat = 24

    var body: some View {
        Group {
            if isSelected {
                expandedRow
            } else {
                compactRow
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.12)) { store.selectNote(note.id) } }
        .onHover { isHovering = $0 }
        .onChange(of: draft) { scheduleSaveDraft() }
        .onChange(of: note.id) { resetDraft() }
        .onDisappear { flushDraft() }
    }

    // MARK: - Expanded (Selected)

    private var expandedRow: some View {
        VStack(spacing: 0) {
            // Drag handle
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 1)
                    .fill(AgendaColor.cardDragHandle)
                    .frame(width: 24, height: 3)
                Spacer()
            }
            .padding(.bottom, 14)

            // Date navigation
            if note.scheduledDate != nil {
                dateNavigationBar
                    .padding(.bottom, 10)
            }

            HStack(alignment: .top, spacing: 0) {
                // Bullet
                Image(systemName: "target")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(noteColorValue(note.noteColor))
                    .frame(width: bulletCol, alignment: .leading)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 0) {
                    // Title row with date and person indicator
                    HStack(alignment: .center) {
                        if note.pinState == .pinnedTop {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(AgendaColor.amber)
                        }
                        TextField("标题", text: $draft.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isNoteDimmed ? .secondary : Color(red: 0.173, green: 0.173, blue: 0.180))
                            .textFieldStyle(.plain)
                            .onSubmit { saveDraft() }

                        Spacer(minLength: 16)

                        if !dateLabel.isEmpty {
                            Button {
                                showDatePicker = true
                            } label: {
                                Text(dateLabel)
                                    .font(.system(size: 13, weight: isToday ? .medium : .regular))
                                    .foregroundStyle(isToday ? AgendaColor.amber : AgendaColor.textMuted)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showDatePicker, arrowEdge: .top) {
                                customDatePanel
                            }
                        }
                    }

                    // Tags
                    if !note.tags.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(note.tags, id: \.self) { t in
                                Text("#\(t)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AgendaColor.tagCyan)
                            }
                        }
                        .padding(.top, 8)
                    }

                    // Body
                    TextField("笔记正文", text: $draft.body, axis: .vertical)
                        .font(.system(size: 14))
                        .foregroundStyle(isNoteDimmed ? .secondary : AgendaColor.textBody)
                        .lineSpacing(6)
                        .textFieldStyle(.plain)
                        .lineLimit(1...30)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 40, alignment: .topLeading)
                        .padding(.top, 10)
                        .padding(.bottom, 28)

                    // Checklist
                    let summary = note.checklistSummary
                    if summary.totalCount > 0 {
                        checklistSummaryRow(summary)
                            .padding(.top, 2)
                    }
                }
            }

            // Action bar
            HStack {
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        store.duplicateNote(note.id)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .help("复制笔记")

                    Menu {
                        Picker("状态", selection: $draft.status) {
                            ForEach(NoteStatus.allCases, id: \.self) { s in Text(s.title).tag(s) }
                        }
                        Divider()
                        Button(note.isStarred ? "取消标星" : "标星") { store.setStarred(!note.isStarred, noteID: note.id) }
                        Menu("颜色标记") {
                            Button("无") { store.setNoteColor(nil, noteID: note.id) }
                            ForEach(NoteColor.allCases, id: \.self) { c in
                                Button(c.title) { store.setNoteColor(c, noteID: note.id) }
                            }
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
                                    store.updateNote(noteID: note.id, title: note.title, body: note.body,
                                                     scheduledDate: nil, tags: note.tags, people: note.people, status: note.status)
                                    resetDraft()
                                }
                            }
                        }
                        Button("复制摘要") { if let s = store.summaryMarkdown(for: note.id) { copyToPasteboard(s) } }
                        Divider()
                        Button("删除笔记", role: .destructive) { store.deleteNote(note.id) }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24, height: 24)
                }
                .foregroundStyle(AgendaColor.amber)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AgendaColor.cardActiveFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AgendaColor.cardActiveBorder, lineWidth: 1)
        )
        .shadow(color: AgendaColor.amber.opacity(0.06), radius: 12, x: 0, y: 2)
        .padding(-20)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    // MARK: - Compact Row

    private var compactRow: some View {
        HStack(alignment: .top, spacing: 0) {
            bulletIcon(expanded: false)
                .frame(width: bulletCol, alignment: .leading)
                .padding(.top, note.body.isEmpty ? 7 : 4)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    if note.pinState == .pinnedTop {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AgendaColor.amber.opacity(0.7))
                    }
                    Text(note.title)
                        .font(.system(size: 18, weight: note.body.isEmpty ? .semibold : .bold))
                        .foregroundStyle(isNoteDimmed ? .secondary : .primary)
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    if isHovering {
                        HStack(spacing: 8) {
                            if note.isStarred {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.yellow.opacity(0.7))
                            }
                            if !dateLabel.isEmpty {
                                Text(dateLabel)
                                    .font(.system(size: 13, weight: isToday ? .medium : .regular))
                                    .foregroundStyle(isToday ? AgendaColor.amber : AgendaColor.textMuted)
                            }
                            hoverActions
                        }
                    }
                }

                if !note.body.isEmpty {
                    Text(note.body)
                        .font(.system(size: 13))
                        .foregroundStyle(isNoteDimmed ? .secondary : AgendaColor.textBody)
                        .lineLimit(2)
                        .lineSpacing(6)
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Bullet Icon

    private func bulletIcon(expanded: Bool) -> some View {
        let color = noteColorValue(note.noteColor)

        return ZStack {
            if expanded {
                Image(systemName: "target")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
            } else if note.isFocused {
                Circle()
                    .stroke(color, lineWidth: 2.5)
                    .frame(width: 14, height: 14)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
            }
        }
        .frame(width: bulletCol, height: 16)
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

    private var isNoteDimmed: Bool {
        note.status == .completed || note.status == .closed
    }

    // MARK: - Shared subviews

    private func checklistSummaryRow(_ summary: ChecklistSummary) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "checklist")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.4))
            Text(summary.title)
                .font(.system(size: 12, weight: .medium))
            Text("· \(summary.openCount) 项未完成")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var hoverActions: some View {
        Menu {
            Button(note.isStarred ? "取消标星" : "标星") {
                store.setStarred(!note.isStarred, noteID: note.id)
            }
            Button("指定到今天") { store.scheduleToday(noteID: note.id) }
            Button("复制笔记") { store.duplicateNote(note.id) }
            Divider()
            Menu("颜色标记") {
                Button("无") { store.setNoteColor(nil, noteID: note.id) }
                ForEach(NoteColor.allCases, id: \.self) { c in
                    Button(c.title) { store.setNoteColor(c, noteID: note.id) }
                }
            }
            Menu("置顶/置底") {
                Button(note.pinState == .pinnedTop ? "取消置顶" : "置顶") {
                    store.setPinState(note.pinState == .pinnedTop ? .none : .pinnedTop, noteID: note.id)
                }
                Button(note.pinState == .pinnedBottom ? "取消置底" : "置底") {
                    store.setPinState(note.pinState == .pinnedBottom ? .none : .pinnedBottom, noteID: note.id)
                }
            }
            Menu("状态") {
                ForEach(NoteStatus.allCases, id: \.self) { s in
                    Button(s.title) { store.setStatus(s, noteID: note.id) }
                }
            }
            Divider()
            Button("删除笔记", role: .destructive) { store.deleteNote(note.id) }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 13))
                .foregroundStyle(AgendaColor.textMuted.opacity(0.6))
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Date Navigation

    private var dateNavigationBar: some View {
        let hasPrev = store.navigateToPreviousScheduledNote(from: note.id) != nil
        let hasNext = store.navigateToNextScheduledNote(from: note.id) != nil
        let hasTodayNote = store.navigateToTodayNote() != nil
        let isTodayNote: Bool = {
            guard let d = note.scheduledDate else { return false }
            return Calendar.current.isDateInToday(d)
        }()

        return HStack(spacing: 0) {
            Button {
                if let prevID = store.navigateToPreviousScheduledNote(from: note.id) {
                    store.selectNote(prevID)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(hasPrev ? AgendaColor.amber : AgendaColor.textMuted.opacity(0.3))
            .disabled(!hasPrev)

            Spacer()

            if !isTodayNote && hasTodayNote {
                Button {
                    if let todayID = store.navigateToTodayNote() {
                        store.selectNote(todayID)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AgendaColor.amber)
                            .frame(width: 6, height: 6)
                        Text("今天")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(AgendaColor.amber)
            } else {
                Spacer()
            }

            Button {
                if let nextID = store.navigateToNextScheduledNote(from: note.id) {
                    store.selectNote(nextID)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(hasNext ? AgendaColor.amber : AgendaColor.textMuted.opacity(0.3))
            .disabled(!hasNext)
        }
    }

    // MARK: - Date

    private var dateLabel: String {
        guard let d = draft.hasScheduledDate ? draft.scheduledDate : note.scheduledDate else { return "" }
        if Calendar.current.isDateInToday(d) { return "今天" }
        if Calendar.current.isDateInTomorrow(d) { return "明天" }
        if Calendar.current.isDateInYesterday(d) { return "昨天" }
        let fm = DateFormatter()
        fm.locale = Locale(identifier: "zh_CN")
        fm.dateFormat = "M月d日 EEEE"
        return fm.string(from: d)
    }

    private var isToday: Bool {
        guard let d = draft.hasScheduledDate ? draft.scheduledDate : note.scheduledDate else { return false }
        return Calendar.current.isDateInToday(d)
    }

    // MARK: - Custom Date Panel

    private var customDatePanel: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selectedDate = draft.hasScheduledDate ? (draft.scheduledDate ?? today) : (note.scheduledDate ?? today)
        let days = daysInMonth(calendarMonth, calendar: calendar)
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: calendarMonth))!
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingEmpties = firstWeekday - 1

        return VStack(spacing: 0) {
            // Calendar grid
            VStack(spacing: 0) {
                // Month navigation
                HStack(spacing: 0) {
                    Text(monthYearString(calendarMonth))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        calendarMonth = today
                    } label: {
                        Text("今天")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AgendaColor.amber)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AgendaColor.amber.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                    Button {
                        if let prev = calendar.date(byAdding: .month, value: -1, to: calendarMonth) {
                            calendarMonth = prev
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    Button {
                        if let next = calendar.date(byAdding: .month, value: 1, to: calendarMonth) {
                            calendarMonth = next
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 12)

                // Weekday headers
                HStack(spacing: 0) {
                    ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { d in
                        Text(d)
                            .font(.system(size: 11))
                            .foregroundStyle(AgendaColor.textMuted)
                            .frame(width: 34, height: 22)
                    }
                }
                .padding(.bottom, 2)

                // Date grid
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
                                let isSelected = calendar.isDate(cellDate, inSameDayAs: selectedDate)
                                let isTodayCell = calendar.isDate(cellDate, inSameDayAs: today)
                                let hasNotes = notesOnDates.contains(day)

                                Button {
                                    draft.hasScheduledDate = true
                                    draft.scheduledDate = calendar.startOfDay(for: cellDate)
                                    scheduleSaveDraft()
                                    showDatePicker = false
                                } label: {
                                    ZStack {
                                        if isSelected {
                                            Circle()
                                                .fill(AgendaColor.amber)
                                                .frame(width: 24, height: 24)
                                        }
                                        Text("\(day)")
                                            .font(.system(size: 13, weight: isSelected ? .semibold : (isTodayCell ? .medium : .regular)))
                                            .foregroundStyle(isSelected ? .white : (isTodayCell ? AgendaColor.amber : .primary))
                                    }
                                    .frame(width: 34, height: 32)
                                    .overlay(alignment: .bottom) {
                                        if hasNotes && !isSelected {
                                            Circle()
                                                .fill(AgendaColor.amber.opacity(0.6))
                                                .frame(width: 4, height: 4)
                                                .padding(.bottom, 2)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(18)

            // Bottom bar
            Divider()
            HStack(spacing: 0) {
                if dateLabel.isEmpty == false {
                    Button {
                        draft.hasScheduledDate = false
                        draft.scheduledDate = nil
                        scheduleSaveDraft()
                        showDatePicker = false
                    } label: {
                        Text("清除日期")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") {
                    draft.hasScheduledDate = note.scheduledDate != nil
                    draft.scheduledDate = note.scheduledDate
                    showDatePicker = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.trailing, 12)
                Button("指定日期") {
                    scheduleSaveDraft()
                    showDatePicker = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(AgendaColor.amber)
                )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .frame(width: 272)
    }

    /// Days in the displayed month that have at least one note scheduled.
    private func noteDatesInMonth(_ startOfMonth: Date, days: Int, calendar: Calendar) -> Set<Int> {
        guard let range = calendar.range(of: .day, in: .month, for: startOfMonth) else { return [] }
        var result = Set<Int>()
        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) else { continue }
            let hasNotes = store.filteredNotes().contains { note in
                guard let d = note.scheduledDate else { return false }
                return calendar.isDate(d, inSameDayAs: date)
            }
            if hasNotes { result.insert(day) }
        }
        return result
    }

    private func daysInMonth(_ date: Date, calendar: Calendar) -> Int {
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    private func monthYearString(_ date: Date) -> String {
        let fm = DateFormatter()
        fm.locale = Locale(identifier: "zh_CN")
        fm.dateFormat = "yyyy年M月"
        return fm.string(from: date)
    }

    // MARK: - Save / Draft

    private func saveDraft() {
        saveTask?.cancel(); saveTask = nil
        let sd = draft.hasScheduledDate ? draft.scheduledDate : nil
        store.updateNote(noteID: note.id, title: draft.title, body: draft.body,
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

    private func splitList(_ text: String) -> [String] { splitCommaList(text) }
}

// MARK: - Supporting Types

private struct StreamNoteDraft: Equatable {
    var title: String; var body: String
    var hasScheduledDate: Bool; var scheduledDate: Date?
    var tagsText: String; var peopleText: String; var status: NoteStatus

    init(note: Note) {
        title = note.title; body = note.body
        hasScheduledDate = note.scheduledDate != nil
        scheduledDate = note.scheduledDate ?? Date()
        tagsText = note.tags.joined(separator: ", ")
        peopleText = note.people.joined(separator: ", ")
        status = note.status
    }
}
