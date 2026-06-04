import AgendadaCore
import SwiftUI

struct ProjectTargetPickerView: View {
    let store: ObservableLibraryStore
    let onSelect: (ProjectCategory?) -> Void
    let onCreateNewCategory: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("新建新项目到：")
                .font(.title3.weight(.semibold))
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // Existing categories
                    ForEach(store.categories) { category in
                        Button {
                            onSelect(category)
                        } label: {
                            HStack(spacing: 8) {
                                CategoryBookmarkIcon(color: category.color.sidebarTint)
                                Text(category.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                let count = store.orderedProjects(in: category.id).count
                                Text("\(count) 个项目")
                                    .foregroundStyle(AgendaColor.textMuted)
                                    .font(.caption)
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Uncategorized projects
                    let uncategorized = store.uncategorizedProjects
                    if !uncategorized.isEmpty {
                        Button {
                            onSelect(nil)
                        } label: {
                            HStack(spacing: 8) {
                                CategoryBookmarkIcon(color: AgendaColor.textMuted)
                                Text("未分类")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(uncategorized.count) 个项目")
                                    .foregroundStyle(AgendaColor.textMuted)
                                    .font(.caption)
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // Create new category
                    Button {
                        onCreateNewCategory()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bookmark.badge.plus")
                                .foregroundStyle(AgendaColor.amber)
                                .frame(width: 10)
                            Text("新建分类…")
                                .foregroundStyle(AgendaColor.amber)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("取消") { onDismiss() }
            }
        }
        .padding(24)
        .frame(width: 360, height: 320)
    }
}
