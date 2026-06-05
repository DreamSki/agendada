import AgendadaCore
import SwiftUI

struct SidebarView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @State private var sidebarModal: SidebarModal?
    @State private var createProjectAfterCategoryCreation = false
    @State private var menuDismissedAt: Date = .distantPast
    // 保留项目/智能概览操作
    @State private var nameSheet: NameSheet?
    @State private var deletion: DeletionTarget?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    overviewSection
                        .padding(.top, 2)
                        .padding(.bottom, 16)

                    smartOverviewSection

                    ForEach(store.topLevelCategories) { category in
                        categoryRecursiveSection(category, depth: 0)
                    }

                    // Uncategorized projects section
                    uncategorizedSection
                }
                .padding(.top, 46)
                .padding(.bottom, 18)
            }

            bottomToolbar
        }
        .background(AgendaColor.sidebarBg)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AgendaColor.sidebarBorder)
                .frame(width: 1)
        }
        // ── ProjectTargetPicker sheet ──
        .sheet(item: projectTargetPickerItem) { _ in
            ProjectTargetPickerView(
                store: store,
                onSelect: { sidebarModal = .projectNaming($0) },
                onCreateNewCategory: {
                    createProjectAfterCategoryCreation = true
                    sidebarModal = .categoryEditor(.create)
                },
                onDismiss: { sidebarModal = nil }
            )
        }
        // ── CategoryEditor sheet ──
        .sheet(item: categoryEditorItem) { modal in
            if case let .categoryEditor(mode) = modal {
                CategoryEditorSheet(
                    mode: mode,
                    onSave: { name, color in
                        handleCategoryEditorSave(mode: mode, name: name, color: color)
                    },
                    onCancel: { sidebarModal = nil }
                )
            }
        }
        // ── ProjectNaming sheet ──
        .sheet(item: projectNamingItem) { modal in
            if case let .projectNaming(category) = modal {
                NamePromptSheet(
                    sheet: .newProject(category),
                    onSave: { name, _ in
                        store.addProject(name: name, categoryID: category?.id)
                        sidebarModal = nil
                    }
                )
            }
        }
        // ── Category Delete confirmation ──
        .confirmationDialog(
            "删除分类？",
            isPresented: isDeleteConfirmationShown,
            titleVisibility: .visible
        ) {
            Button("删除分类", role: .destructive) {
                if case let .categoryDeleteConfirmation(category) = sidebarModal {
                    store.deleteCategory(category.id)
                    sidebarModal = nil
                }
            }
            Button("取消", role: .cancel) { sidebarModal = nil }
        } message: {
            if case let .categoryDeleteConfirmation(category) = sidebarModal {
                Text("会删除\u{201C}\(category.name)\u{201D}。其中的项目会移动到\u{201C}其他项目\u{201D}，笔记不会被删除。此操作不可撤销。")
            }
        }
        // ── 保留：项目/智能概览的 sheet ──
        .sheet(item: $nameSheet) { sheet in
            NamePromptSheet(sheet: sheet) { name, query in
                applyNameSheet(sheet, name: name, query: query)
            }
        }
        // ── 保留：项目/智能概览的 confirmationDialog ──
        .confirmationDialog(
            deletion?.title ?? "",
            isPresented: Binding(
                get: { deletion != nil },
                set: { isPresented in
                    if !isPresented { deletion = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            if let deletion {
                Button(deletion.buttonTitle, role: .destructive) {
                    applyDeletion(deletion)
                    self.deletion = nil
                }
            }

            Button("取消", role: .cancel) {
                deletion = nil
            }
        } message: {
            if let deletion {
                Text(deletion.message)
            }
        }
        .navigationTitle("Agendada")
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            AgendaSidebarSectionLabel("概览")
                .padding(.bottom, 6)

            sidebarButton("简达", systemImage: "smallcircle.fill.circle", selection: .overview(.brief), tint: AgendaColor.amber,
                dropAction: { payload in
                    guard let note = store.note(withID: payload.noteID), !note.isBrief else { return false }
                    store.setBrief(true, noteID: payload.noteID)
                    return true
                })
            sidebarButton(todayTitle, systemImage: "calendar", selection: .overview(.today), tint: Color(red: 0.29, green: 0.56, blue: 0.89),
                dropAction: { payload in
                    guard let note = store.note(withID: payload.noteID) else { return false }
                    let isToday = note.scheduledDate.map { Calendar.current.isDateInToday($0) } ?? false
                    guard !isToday else { return false }
                    store.scheduleToday(noteID: payload.noteID)
                    return true
                })
            sidebarButton("待办事项", systemImage: "checkmark.circle", selection: .overview(.tasks), tint: Color(red: 0.96, green: 0.32, blue: 0.37))
            sidebarTrashButton
        }
    }

    // MARK: - Smart Overview Section

    @ViewBuilder
    private var smartOverviewSection: some View {
        let overviews = store.smartOverviews
        if !overviews.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                AgendaSidebarSectionLabel("智能概览")
                    .padding(.bottom, 6)

                ForEach(overviews) { overview in
                    smartOverviewRow(overview)
                }
            }
            .padding(.bottom, 16)
        }
    }

    private func smartOverviewRow(_ overview: SmartOverview) -> some View {
        let isSelected = store.selectedSmartOverviewID == overview.id
        return AgendaSidebarRow(
            title: overview.name,
            systemImage: "sparkle.magnifyingglass",
            isSelected: isSelected,
            tint: AgendaColor.amber,
            selectedTextColor: AgendaColor.amber,
            showsSelectionBackground: true,
            action: { select(.smartOverview(overview.id)) }
        )
        .contextMenu {
            Button("重命名…") {
                nameSheet = .renameSmartOverview(overview)
            }
            Divider()
            Button("删除", role: .destructive) {
                deletion = .smartOverview(overview)
            }
        }
    }

    // MARK: - Category Sections

    private func categoryRecursiveSection(_ category: ProjectCategory, depth: Int) -> some View {
        CategorySectionView(
            category: category,
            currentSelection: currentSelection,
            projects: store.orderedProjects(in: category.id),
            depth: depth,
            onSelectProject: { select(.project($0)) },
            onRenameProject: { nameSheet = .renameProject($0) },
            onDeleteProject: { deletion = .project($0) },
            onSetSidebarModal: { sidebarModal = $0 }
        )
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            Button {
                if sidebarModal == .createMenu {
                    sidebarModal = nil
                } else {
                    guard Date().timeIntervalSince(menuDismissedAt) > 0.18 else { return }
                    sidebarModal = .createMenu
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .heavy))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help("新建项目或分类")
            .background {
                NSPopoverPresenter(
                    isPresented: isCreateMenuShown,
                    preferredEdge: .maxX,
                    contentSize: CGSize(width: 220, height: 110)
                ) {
                    CreateMenuContent(
                        onNewProject: { sidebarModal = .projectTargetPicker },
                        onNewCategory: { sidebarModal = .categoryEditor(.create) }
                    )
                }
            }

            Spacer()

            Button {} label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 28, height: 28)
            }
            .help("历史记录")

            Button {} label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: 28)
            }
            .foregroundStyle(Color(red: 0.78, green: 0.78, blue: 0.80))
            .help("后退")

            Button {} label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: 28)
            }
            .foregroundStyle(Color(red: 0.78, green: 0.78, blue: 0.80))
            .help("前进")
        }
        .buttonStyle(.plain)
        .foregroundStyle(AgendaColor.textMuted)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(AgendaColor.toolbarCapsuleBg, in: Capsule())
        .overlay(Capsule().stroke(AgendaColor.sidebarBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Modal State

    fileprivate typealias CategoryEditorMode = CategoryEditorSheet.Mode

    fileprivate enum SidebarModal: Identifiable, Equatable {
        case createMenu
        case projectTargetPicker
        case categoryEditor(CategoryEditorMode)
        case projectNaming(ProjectCategory?)
        case categoryDeleteConfirmation(ProjectCategory)

        var id: String {
            switch self {
            case .createMenu:                        "createMenu"
            case .projectTargetPicker:               "projectTargetPicker"
            case .categoryEditor(.create):           "catEditor-create"
            case .categoryEditor(.edit(let c)):      "catEditor-\(c.id.uuidString)"
            case .categoryEditor(.createSubcategory(let c)): "catSubEditor-\(c.id.uuidString)"
            case .projectNaming(let c?):             "projNaming-\(c.id.uuidString)"
            case .projectNaming(nil):                "projNaming-none"
            case .categoryDeleteConfirmation(let c): "catDelete-\(c.id.uuidString)"
            }
        }
    }

    // MARK: - Modal Bindings

    private var isCreateMenuShown: Binding<Bool> {
        Binding(get: { sidebarModal == .createMenu },
                set: {
                    if $0 {
                        sidebarModal = .createMenu
                    } else if sidebarModal == .createMenu {
                        menuDismissedAt = Date()
                        sidebarModal = nil
                    }
                })
    }

    private var projectTargetPickerItem: Binding<SidebarModal?> {
        Binding(get: { sidebarModal == .projectTargetPicker ? sidebarModal : nil },
                set: { if $0 == nil, sidebarModal == .projectTargetPicker { sidebarModal = nil } })
    }

    private var categoryEditorItem: Binding<SidebarModal?> {
        Binding(get: { if case .categoryEditor = sidebarModal { return sidebarModal } else { return nil } },
                set: { if $0 == nil, case .categoryEditor = sidebarModal { sidebarModal = nil } })
    }

    private var projectNamingItem: Binding<SidebarModal?> {
        Binding(get: { if case .projectNaming = sidebarModal { return sidebarModal } else { return nil } },
                set: { if $0 == nil, case .projectNaming = sidebarModal { sidebarModal = nil } })
    }

    private var isDeleteConfirmationShown: Binding<Bool> {
        Binding(get: { if case .categoryDeleteConfirmation = sidebarModal { return true } else { return false } },
                set: { if !$0 { sidebarModal = nil } })
    }

    // MARK: - Create Menu Content (NSPopover)

    private struct CreateMenuContent: View {
        let onNewProject: () -> Void
        let onNewCategory: () -> Void
        @State private var hoveredRow: Int?

        var body: some View {
            VStack(spacing: 0) {
                CreateMenuRow(
                    icon: "doc.badge.plus",
                    title: "新建项目",
                    isHovered: hoveredRow == 0,
                    action: onNewProject
                )
                .onHover { hoveredRow = $0 ? 0 : nil }

                Divider().padding(.leading, 40)

                CreateMenuRow(
                    icon: "bookmark",
                    title: "新建分类",
                    isHovered: hoveredRow == 1,
                    action: onNewCategory
                )
                .onHover { hoveredRow = $0 ? 1 : nil }
            }
            .padding(.vertical, 6)
        }
    }

    private struct CreateMenuRow: View {
        let icon: String
        let title: String
        let isHovered: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AgendaColor.amber)
                        .frame(width: 18, height: 18)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(Color(nsColor: .labelColor))

                        Text(subtitle)
                            .font(.custom("Avenir Next", size: 11))
                            .foregroundStyle(AgendaColor.textMuted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered ? Color.accentColor.opacity(0.08) : .clear)
                )
            }
            .buttonStyle(.plain)
        }

        private var subtitle: String {
            title == "新建项目"
                ? "记录会议、规划日程、整理生活"
                : "例如\u{201C}工作\u{201D}或\u{201C}家庭\u{201D}"
        }
    }

    private func handleCategoryEditorSave(mode: CategoryEditorMode, name: String, color: CategoryColor) {
        switch mode {
        case .create:
            let category = store.addCategory(name: name, color: color)
            if createProjectAfterCategoryCreation {
                createProjectAfterCategoryCreation = false
                sidebarModal = .projectNaming(category)
            } else {
                sidebarModal = nil
            }
        case .edit(let category):
            store.updateCategory(category.id, name: name, color: color)
            sidebarModal = nil
        case .createSubcategory(let parentCategory):
            _ = store.addCategory(name: name, color: color, parentID: parentCategory.id)
            sidebarModal = nil
        }
    }

    // MARK: - Selection

    private var currentSelection: SidebarSelection? {
        if let overview = store.selectedOverview {
            return .overview(overview)
        }

        if let smartOverviewID = store.selectedSmartOverviewID {
            return .smartOverview(smartOverviewID)
        }

        if let projectID = store.selectedProjectID {
            return .project(projectID)
        }

        return nil
    }

    private func select(_ selection: SidebarSelection) {
        withAnimation(.easeInOut(duration: 0.14)) {
            switch selection {
            case let .overview(overview):
                store.selectOverview(overview)
            case let .smartOverview(smartOverviewID):
                store.selectSmartOverview(smartOverviewID)
            case let .project(projectID):
                store.selectProject(projectID)
            }
        }
    }

    private func sidebarButton(
        _ title: String,
        systemImage: String,
        selection: SidebarSelection,
        tint: Color,
        showsSelectionBackground: Bool = true,
        dropAction: ((DragPayload) -> Bool)? = nil
    ) -> some View {
        AgendaSidebarRow(
            title: title,
            systemImage: systemImage,
            isSelected: currentSelection == selection,
            tint: tint,
            selectedTextColor: showsSelectionBackground ? AgendaColor.amber : AgendaColor.textPrimary,
            showsSelectionBackground: showsSelectionBackground,
            action: { select(selection) },
            dropAction: dropAction
        )
    }

    private var defaultCategory: ProjectCategory? {
        if let selectedProjectID = store.selectedProjectID,
           let categoryID = store.project(withID: selectedProjectID)?.categoryID {
            return store.category(withID: categoryID)
        }

        return store.categories.first
    }

    private var todayTitle: String {
        Date().formatted(.dateTime.year().month().day())
    }

    private var sidebarTrashButton: some View {
        let trashCount = store.trashedNotes.count
        let title = trashCount > 0 ? "废纸篓 (\(trashCount))" : "废纸篓"
        let isSelected = store.selectedOverview == .trash

        return AgendaSidebarRow(
            title: title,
            systemImage: "trash",
            isSelected: isSelected,
            tint: AgendaColor.textMuted,
            selectedTextColor: AgendaColor.amber,
            showsSelectionBackground: false,
            action: { store.selectOverview(.trash) },
            dropAction: { payload in
                store.deleteNote(payload.noteID)
                return true
            }
        )
    }

    private var uncategorizedSection: some View {
        let uncategorized = store.uncategorizedProjects
        guard !uncategorized.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                Text("其他项目")
                    .font(AgendaFont.sidebarItem)
                    .foregroundStyle(AgendaColor.textMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)

                ForEach(uncategorized) { project in
                    uncategorizedRow(project)
                }
            }
            .padding(.bottom, 16)
        )
    }

    private func uncategorizedRow(_ project: Project) -> some View {
        AgendaSidebarRow(
            title: project.name,
            systemImage: "agenda.note.stack",
            isSelected: currentSelection == .project(project.id),
            tint: project.color.sidebarTint,
            selectedTextColor: AgendaColor.amber,
            showsSelectionBackground: true,
            action: { select(.project(project.id)) },
            dropAction: nil
        )
        .contextMenu {
            Button("重命名") { nameSheet = .renameProject(project) }
            Button("删除", role: .destructive) { deletion = .project(project) }
        }
    }
}

// MARK: - Category Section (with hover controls)

private struct CategorySectionView: View {
    @Environment(ObservableLibraryStore.self) private var store
    let category: ProjectCategory
    let currentSelection: SidebarSelection?
    let projects: [Project]
    let depth: Int
    let onSelectProject: (Project.ID) -> Void
    let onRenameProject: (Project) -> Void
    let onDeleteProject: (Project) -> Void
    /// 从父层传递的状态控制回调（分类编辑/删除等需要顶层 state machine）
    let onSetSidebarModal: (SidebarView.SidebarModal) -> Void

    @State private var isExpanded = true
    @State private var isHovering = false
    @State private var showCategoryAction = false
    @State private var actionPresenter = AgendadaFloatingMenuPresenter()

    private var subcategories: [ProjectCategory] {
        store.subcategories(of: category.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header
            HStack(spacing: 6) {
                if !subcategories.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AgendaColor.textMuted)
                            .rotationEffect(isExpanded ? .degrees(90) : .zero)
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.plain)
                }
                CategoryBookmarkIcon(color: category.color.sidebarTint)
                Text(category.name)
                    .font(AgendaFont.sidebarItem)
                    .foregroundStyle(AgendaColor.textMuted)
                Spacer()
                // ... 按钮：始终占位，opacity 控制显隐
                Button {
                    if showCategoryAction {
                        showCategoryAction = false
                    } else {
                        actionPresenter.configure(
                            dismiss: { showCategoryAction = false },
                            showSubmenu: { _ in }
                        )
                        showCategoryAction = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AgendaColor.textMuted)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1 : 0)
                .disabled(!isHovering)
                .popover(isPresented: $showCategoryAction, arrowEdge: .trailing) {
                    AgendadaFloatingMenuView(
                        sections: actionSections,
                        presenter: actionPresenter,
                        width: 280
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                    showCategoryAction = false
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }

            if isExpanded {
                // Projects
                ForEach(projects) { project in
                    AgendaSidebarRow(
                        title: project.name,
                        systemImage: "agenda.note.stack",
                        isSelected: currentSelection == .project(project.id),
                        tint: project.color.sidebarTint,
                        selectedTextColor: AgendaColor.amber,
                        showsSelectionBackground: true,
                        action: { onSelectProject(project.id) },
                        dropAction: { payload in
                            guard let note = store.note(withID: payload.noteID),
                                  note.projectID != project.id else { return false }
                            store.moveNotes([payload.noteID], toProject: project.id)
                            return true
                        }
                    )
                    .contextMenu {
                        Button("重命名") { onRenameProject(project) }
                        Button("删除", role: .destructive) { onDeleteProject(project) }
                    }
                    .padding(.leading, CGFloat(depth) * 12)
                }

                // Subcategories
                ForEach(subcategories) { sub in
                    CategorySectionView(
                        category: sub,
                        currentSelection: currentSelection,
                        projects: store.orderedProjects(in: sub.id),
                        depth: depth + 1,
                        onSelectProject: onSelectProject,
                        onRenameProject: onRenameProject,
                        onDeleteProject: onDeleteProject,
                        onSetSidebarModal: onSetSidebarModal
                    )
                }
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Category Action Menu

    private var actionSections: [AgendadaFloatingMenuSection] {
        let projectCount = store.orderedProjects(in: category.id).count
        let subCount = store.subcategories(of: category.id).count
        return [
            .init(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "doc.badge.plus",
                    title: "在分类中新建项目",
                    subtitle: "当前共 \(projectCount) 个项目"
                ) { [self = self] _ in
                    self.showCategoryAction = false
                    self.onSetSidebarModal(.projectNaming(category))
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "bookmark.badge.plus",
                    title: "新建子分类\u{2026}",
                    subtitle: subCount > 0 ? "当前共 \(subCount) 个子分类" : nil
                ) { [self = self] _ in
                    self.showCategoryAction = false
                    self.onSetSidebarModal(.categoryEditor(.createSubcategory(parentCategory: category)))
                },
            ]),
            .init(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "pencil",
                    title: "编辑分类\u{2026}"
                ) { [self = self] _ in
                    self.showCategoryAction = false
                    self.onSetSidebarModal(.categoryEditor(.edit(category)))
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "arrow.up.arrow.down",
                    title: "按字母顺序对项目进行排序"
                ) { [self = self] _ in
                    self.showCategoryAction = false
                    self.store.sortProjectsAlphabetically(in: category.id)
                },
            ]),
            .init(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "square.and.arrow.up",
                    title: "分享\u{2026}"
                ) { [self = self] _ in
                    self.showCategoryAction = false
                    let text = CategoryShareHelper.shareText(for: category, projects: self.store.projects)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                },
                AgendadaFloatingMenuItem(
                    iconSystemName: "macwindow",
                    title: "在单独的窗口中打开"
                ) { [self = self] _ in
                    self.showCategoryAction = false
                    CategoryWindowManager.shared.openWindow(for: category, store: self.store)
                },
            ]),
            .init(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "xmark",
                    title: "删除分类",
                    role: .destructive
                ) { [self = self] _ in
                    self.showCategoryAction = false
                    self.onSetSidebarModal(.categoryDeleteConfirmation(category))
                },
            ]),
        ]
    }
}

// MARK: - Sidebar Selection

private enum SidebarSelection: Hashable {
    case overview(Overview)
    case smartOverview(SmartOverview.ID)
    case project(Project.ID)
}

// MARK: - Sidebar Row

private struct AgendaSidebarRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let tint: Color
    let selectedTextColor: Color
    let showsSelectionBackground: Bool
    let action: () -> Void
    let dropAction: ((DragPayload) -> Bool)?

    @State private var isHovering = false
    @State private var isDropTargeted = false

    init(title: String, systemImage: String, isSelected: Bool, tint: Color, selectedTextColor: Color, showsSelectionBackground: Bool, action: @escaping () -> Void, dropAction: ((DragPayload) -> Bool)? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.tint = tint
        self.selectedTextColor = selectedTextColor
        self.showsSelectionBackground = showsSelectionBackground
        self.action = action
        self.dropAction = dropAction
    }

    var body: some View {
        rowContent
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .onHover { isHovering = $0 }
            .when(dropAction != nil) { view in
                view.dropDestination(for: DragPayload.self) { items, _ in
                    guard let payload = items.first else { return false }
                    return dropAction?(payload) ?? false
                } isTargeted: { targeted in
                    isDropTargeted = targeted
                }
            }
    }

    private var rowContent: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                SidebarIcon(systemImage: systemImage, tint: tint, isSelected: isSelected)
                    .frame(width: 16, alignment: .center)

                Text(title)
                    .font(isSelected ? AgendaFont.sidebarItemActive : AgendaFont.sidebarItem)
                    .foregroundStyle(isSelected && showsSelectionBackground ? selectedTextColor : AgendaColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .layoutPriority(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .background(dropBackground, in: RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .leading) {
                if isSelected && showsSelectionBackground {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AgendaColor.amber)
                        .frame(width: 4)
                        .offset(x: -8)
                        .padding(.vertical, 4)
                }
            }
            .overlay(
                isDropTargeted
                    ? RoundedRectangle(cornerRadius: 6)
                        .stroke(AgendaColor.amber, lineWidth: 1.5)
                    : nil
            )
        }
    }

    private var dropBackground: Color {
        if isDropTargeted {
            return AgendaColor.amber.opacity(0.15)
        }
        if isSelected && showsSelectionBackground {
            return AgendaColor.sidebarSelectedBg
        }
        return isHovering ? AgendaColor.sidebarHoverBg : .clear
    }

}

// MARK: - Sidebar Icon

private struct SidebarIcon: View {
    let systemImage: String
    let tint: Color
    let isSelected: Bool

    var body: some View {
        if systemImage == "agenda.note.stack" {
            AgendaStackedDocumentIcon(color: tint)
                .frame(width: 18, height: 18)
        } else if systemImage == "agenda.focus.dot" {
            ZStack {
                Circle()
                    .fill(tint)
                    .frame(width: 10, height: 10)
                Circle()
                    .stroke(tint.opacity(0.7), lineWidth: 1)
                    .frame(width: 10, height: 10)
            }
            .frame(width: 16, height: 16)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: AgendaIcon.sidebar))
                .symbolVariant(.fill)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? tint : tint.opacity(0.55))
        }
    }
}

// MARK: - Stacked Document Icon

private struct AgendaStackedDocumentIcon: View {
    let color: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 2.5)
                .stroke(color.opacity(0.7), lineWidth: 1.7)
                .frame(width: 12, height: 14)
                .offset(x: 4, y: 3)

            RoundedRectangle(cornerRadius: 2.5)
                .fill(color.opacity(0.10))
                .frame(width: 12, height: 14)
                .overlay {
                    RoundedRectangle(cornerRadius: 2.5)
                        .stroke(color, lineWidth: 1.9)
                }
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(color.opacity(0.9))
                            .frame(width: 5, height: 1.5)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(color.opacity(0.55))
                            .frame(width: 7, height: 1.2)
                    }
                    .padding(.leading, 3)
                    .padding(.top, 4)
                }
        }
    }
}

// MARK: - Section Label

private struct AgendaSidebarSectionLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(AgendaFont.sidebarItem)
            .foregroundStyle(AgendaColor.textMuted)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
    }
}

// MARK: - Project Color Extension

private extension ProjectColor {
    var sidebarTint: Color {
        switch self {
        case .blue:
            Color(red: 0.26, green: 0.76, blue: 0.74)
        case .green:
            Color(red: 0.28, green: 0.68, blue: 0.45)
        case .orange:
            AgendaColor.amber
        case .pink:
            Color(red: 0.93, green: 0.36, blue: 0.62)
        case .gray:
            AgendaColor.textSecondary
        }
    }
}

// MARK: - Name Sheet

private extension SidebarView {
    func applyNameSheet(_ sheet: NameSheet, name: String, query: String?) {
        switch sheet.mode {
        case let .newProject(category):
            store.addProject(name: name, categoryID: category?.id)
        case let .renameProject(project):
            store.renameProject(project.id, name: name)
        case let .renameSmartOverview(smartOverview):
            store.renameSmartOverview(smartOverview.id, name: name, query: query)
        }

        nameSheet = nil
    }

    func applyDeletion(_ deletion: DeletionTarget) {
        switch deletion {
        case let .project(project):
            store.deleteProject(project.id)
        case let .smartOverview(smartOverview):
            store.deleteSmartOverview(smartOverview.id)
        }
    }
}

// MARK: - Name Sheet Types

private struct NamePromptSheet: View {
    let sheet: NameSheet
    let onSave: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var query: String

    init(sheet: NameSheet, onSave: @escaping (String, String?) -> Void) {
        self.sheet = sheet
        self.onSave = onSave
        _name = State(initialValue: sheet.initialName)
        _query = State(initialValue: sheet.initialQuery ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(sheet.title)
                .font(.title3.weight(.semibold))

            TextField(sheet.placeholder, text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)

            if sheet.initialQuery != nil {
                TextField("查询条件", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    onSave(name, sheet.initialQuery == nil ? nil : query)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    (sheet.initialQuery != nil && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                )
            }
        }
        .padding(20)
    }
}

private struct NameSheet: Identifiable {
    let id = UUID()
    let mode: Mode
    let title: String
    let placeholder: String
    let initialName: String
    let initialQuery: String?

    static func newProject(_ category: ProjectCategory?) -> NameSheet {
        NameSheet(mode: .newProject(category), title: "新建项目", placeholder: "项目名称", initialName: "", initialQuery: nil)
    }

    static func renameProject(_ project: Project) -> NameSheet {
        NameSheet(mode: .renameProject(project), title: "重命名项目", placeholder: "项目名称", initialName: project.name, initialQuery: nil)
    }

    static func renameSmartOverview(_ smartOverview: SmartOverview) -> NameSheet {
        NameSheet(mode: .renameSmartOverview(smartOverview), title: "编辑智能概览", placeholder: "概览名称", initialName: smartOverview.name, initialQuery: smartOverview.query)
    }

    enum Mode {
        case newProject(ProjectCategory?)
        case renameProject(Project)
        case renameSmartOverview(SmartOverview)
    }
}

// MARK: - Deletion Target

private enum DeletionTarget: Identifiable {
    case project(Project)
    case smartOverview(SmartOverview)

    var id: UUID {
        switch self {
        case let .project(project): project.id
        case let .smartOverview(smartOverview): smartOverview.id
        }
    }

    var title: String {
        switch self {
        case .project: "删除项目？"
        case .smartOverview: "删除智能概览？"
        }
    }

    var message: String {
        switch self {
        case let .project(project): "会删除\u{201C}\(project.name)\u{201D}以及其中的笔记。"
        case let .smartOverview(smartOverview): "会删除\u{201C}\(smartOverview.name)\u{201D}这个动态视图，不会删除任何笔记。"
        }
    }

    var buttonTitle: String {
        switch self {
        case .project: "删除项目"
        case .smartOverview: "删除智能概览"
        }
    }
}
