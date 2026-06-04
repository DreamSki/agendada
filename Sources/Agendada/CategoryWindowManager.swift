import AgendadaCore
import AppKit
import SwiftUI

@MainActor
final class CategoryWindowManager {
    static let shared = CategoryWindowManager()

    private var openWindows: [ProjectCategory.ID: NSWindow] = [:]

    func openWindow(for category: ProjectCategory, store: ObservableLibraryStore) {
        // If window already exists, bring it to front
        if let existingWindow = openWindows[category.id] {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = CategoryWindowContent(category: category, store: store)
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = category.name
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.center()

        let categoryID = category.id
        window.delegate = WindowCloseTracker {
            Task { @MainActor in
                CategoryWindowManager.shared.handleWindowClosed(categoryID: categoryID)
            }
        }

        openWindows[category.id] = window
        window.makeKeyAndOrderFront(nil)
    }

    func closeWindow(for categoryID: ProjectCategory.ID) {
        openWindows[categoryID]?.close()
        openWindows.removeValue(forKey: categoryID)
    }

    private func handleWindowClosed(categoryID: ProjectCategory.ID) {
        openWindows.removeValue(forKey: categoryID)
    }
}

/// Simple delegate that calls a closure on window close.
/// Avoids actor-isolation issues with NSWindowDelegate.
private final class WindowCloseTracker: NSObject, NSWindowDelegate {
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

// MARK: - Window Content

private struct CategoryWindowContent: View {
    let category: ProjectCategory
    let store: ObservableLibraryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                CategoryBookmarkIcon(color: category.color.sidebarTint)
                    .frame(width: 16, height: 22)
                Text(category.name)
                    .font(.title2.weight(.semibold))
                Spacer()
            }
            .padding()

            Divider()

            // Project list
            let projects = store.orderedProjects(in: category.id)
            if projects.isEmpty {
                Text("没有项目")
                    .foregroundStyle(AgendaColor.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(projects) { project in
                    HStack(spacing: 8) {
                        Image(systemName: "agenda.note.stack")
                            .foregroundStyle(projectColorTint(project.color))
                        Text(project.name)
                        Spacer()
                        let noteCount = store.library.notes.filter { $0.projectID == project.id && $0.status != .trashed }.count
                        Text("\(noteCount) 条笔记")
                            .foregroundStyle(AgendaColor.textMuted)
                            .font(.caption)
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private func projectColorTint(_ color: ProjectColor) -> Color {
    switch color {
    case .blue:   Color(red: 0.26, green: 0.76, blue: 0.74)
    case .green:  Color(red: 0.28, green: 0.68, blue: 0.45)
    case .orange: AgendaColor.amber
    case .pink:   Color(red: 0.93, green: 0.36, blue: 0.62)
    case .gray:   AgendaColor.textSecondary
    }
}
