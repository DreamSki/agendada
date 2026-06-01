import AgendadaCore
import SwiftUI

struct SidebarView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @State private var nameSheet: NameSheet?
    @State private var deletion: DeletionTarget?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    overviewSection
                        .padding(.top, 2)
                        .padding(.bottom, 16)

                    ForEach(store.categories) { category in
                        categorySection(category)
                    }
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
        .sheet(item: $nameSheet) { sheet in
            NamePromptSheet(sheet: sheet) { name, query in
                applyNameSheet(sheet, name: name, query: query)
            }
        }
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

            sidebarButton("简达", systemImage: "smallcircle.fill.circle", selection: .overview(.brief), tint: AgendaColor.amber)
            sidebarButton(todayTitle, systemImage: "calendar", selection: .overview(.today), tint: Color(red: 0.29, green: 0.56, blue: 0.89))
            sidebarButton("待办事项", systemImage: "checkmark.circle", selection: .overview(.tasks), tint: Color(red: 0.96, green: 0.32, blue: 0.37))
            sidebarTrashButton
        }
    }

    // MARK: - Category Section

    private func categorySection(_ category: ProjectCategory) -> some View {
        CategorySectionView(
            category: category,
            currentSelection: currentSelection,
            projects: store.projects(in: category.id),
            onSelectProject: { select(.project($0)) },
            onRenameProject: { nameSheet = .renameProject($0) },
            onDeleteProject: { deletion = .project($0) }
        )
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            Menu {
                Button("新建项目") {
                    nameSheet = .newProject(defaultCategory)
                }
                Button("新建分类") {
                    nameSheet = .newCategory
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .heavy))
                    .frame(width: 32, height: 32)
            }
            .menuStyle(.borderlessButton)
            .help("新建项目或分类")

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
        showsSelectionBackground: Bool = true
    ) -> some View {
        AgendaSidebarRow(
            title: title,
            systemImage: systemImage,
            isSelected: currentSelection == selection,
            tint: tint,
            selectedTextColor: showsSelectionBackground ? AgendaColor.amber : AgendaColor.textPrimary,
            showsSelectionBackground: showsSelectionBackground
        ) {
            select(selection)
        }
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
            showsSelectionBackground: false
        ) {
            store.selectOverview(.trash)
        }
    }
}

// MARK: - Category Section (with hover controls)

private struct CategorySectionView: View {
    let category: ProjectCategory
    let currentSelection: SidebarSelection?
    let projects: [Project]
    let onSelectProject: (Project.ID) -> Void
    let onRenameProject: (Project) -> Void
    let onDeleteProject: (Project) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(category.name)
                .font(AgendaFont.sidebarItem)
                .foregroundStyle(AgendaColor.textMuted)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            ForEach(projects) { project in
                AgendaSidebarRow(
                    title: project.name,
                    systemImage: "agenda.note.stack",
                    isSelected: currentSelection == .project(project.id),
                    tint: project.color.sidebarTint,
                    selectedTextColor: AgendaColor.amber,
                    showsSelectionBackground: true
                ) {
                    onSelectProject(project.id)
                }
                .contextMenu {
                    Button("重命名") { onRenameProject(project) }
                    Button("删除", role: .destructive) { onDeleteProject(project) }
                }
            }
        }
        .padding(.bottom, 16)
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

    @State private var isHovering = false

    var body: some View {
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
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .leading) {
                if isSelected && showsSelectionBackground {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AgendaColor.amber)
                        .frame(width: 4)
                        .offset(x: -8)
                        .padding(.vertical, 4)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { isHovering = $0 }
    }

    private var rowBackground: Color {
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

// MARK: - Section Header

private struct AgendaSidebarHeader<MenuContent: View>: View {
    let title: String
    let onAdd: (() -> Void)?
    @ViewBuilder let menuItems: MenuContent

    init(title: String, onAdd: (() -> Void)? = nil, @ViewBuilder menuItems: () -> MenuContent) {
        self.title = title
        self.onAdd = onAdd
        self.menuItems = menuItems()
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(AgendaFont.sidebarSection)
                .foregroundStyle(AgendaColor.textMuted)

            Spacer()

            if let onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AgendaColor.textMuted)
                .help("新建")
            }

            Menu {
                menuItems
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .menuStyle(.borderlessButton)
            .foregroundStyle(AgendaColor.textMuted)
            .help("操作")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 5)
    }
}

// MARK: - Static Row

private struct AgendaSidebarStaticRow: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: AgendaIcon.sidebar))
                .foregroundStyle(tint)
                .frame(width: 24, alignment: .center)

            Text(title)
                .font(AgendaFont.sidebarItem)
                .foregroundStyle(AgendaColor.textMuted)

            Spacer(minLength: 0)
        }
        .frame(height: AgendaSpacing.sidebarItemH)
        .padding(.horizontal, 8)
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
        case .newCategory:
            store.addCategory(name: name)
        case let .newProject(category):
            store.addProject(name: name, categoryID: category?.id)
        case let .renameCategory(category):
            store.renameCategory(category.id, name: name)
        case let .renameProject(project):
            store.renameProject(project.id, name: name)
        case let .renameSmartOverview(smartOverview):
            store.renameSmartOverview(smartOverview.id, name: name, query: query)
        }

        nameSheet = nil
    }

    func applyDeletion(_ deletion: DeletionTarget) {
        switch deletion {
        case let .category(category):
            store.deleteCategory(category.id)
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

    static var newCategory: NameSheet {
        NameSheet(mode: .newCategory, title: "新建分类", placeholder: "分类名称", initialName: "", initialQuery: nil)
    }

    static func newProject(_ category: ProjectCategory?) -> NameSheet {
        NameSheet(mode: .newProject(category), title: "新建项目", placeholder: "项目名称", initialName: "", initialQuery: nil)
    }

    static func renameCategory(_ category: ProjectCategory) -> NameSheet {
        NameSheet(mode: .renameCategory(category), title: "重命名分类", placeholder: "分类名称", initialName: category.name, initialQuery: nil)
    }

    static func renameProject(_ project: Project) -> NameSheet {
        NameSheet(mode: .renameProject(project), title: "重命名项目", placeholder: "项目名称", initialName: project.name, initialQuery: nil)
    }

    static func renameSmartOverview(_ smartOverview: SmartOverview) -> NameSheet {
        NameSheet(mode: .renameSmartOverview(smartOverview), title: "编辑智能概览", placeholder: "概览名称", initialName: smartOverview.name, initialQuery: smartOverview.query)
    }

    enum Mode {
        case newCategory
        case newProject(ProjectCategory?)
        case renameCategory(ProjectCategory)
        case renameProject(Project)
        case renameSmartOverview(SmartOverview)
    }
}

// MARK: - Deletion Target

private enum DeletionTarget: Identifiable {
    case category(ProjectCategory)
    case project(Project)
    case smartOverview(SmartOverview)

    var id: UUID {
        switch self {
        case let .category(category): category.id
        case let .project(project): project.id
        case let .smartOverview(smartOverview): smartOverview.id
        }
    }

    var title: String {
        switch self {
        case .category: "删除分类？"
        case .project: "删除项目？"
        case .smartOverview: "删除智能概览？"
        }
    }

    var message: String {
        switch self {
        case let .category(category): "会删除\u{201C}\(category.name)\u{201D}以及其中的项目和笔记。"
        case let .project(project): "会删除\u{201C}\(project.name)\u{201D}以及其中的笔记。"
        case let .smartOverview(smartOverview): "会删除\u{201C}\(smartOverview.name)\u{201D}这个动态视图，不会删除任何笔记。"
        }
    }

    var buttonTitle: String {
        switch self {
        case .category: "删除分类"
        case .project: "删除项目"
        case .smartOverview: "删除智能概览"
        }
    }
}
