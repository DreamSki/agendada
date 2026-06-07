import SwiftUI

/// 当前笔记内查找条 — 不影响 List Search 状态
struct FindInNoteBar: View {
    @Environment(ObservableLibraryStore.self) private var store
    @State private var draftText = ""
    @State private var keyMonitor: Any?

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AgendaColor.textMuted)

            TextField("在当前笔记中查找...", text: $draftText)
                .textFieldStyle(.plain)
                .font(.custom("Avenir Next", size: 13))
                .frame(maxWidth: 160)
                .focused($isFieldFocused)
                .onChange(of: draftText) { _, newValue in
                    store.updateFindInNoteText(newValue)
                }

            // 命中计数
            if !store.findInNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let summary = store.findInNoteSummary
                Text(summary.totalOccurrences > 0
                     ? "\(summary.currentIndex)/\(summary.totalOccurrences)"
                     : "0/0")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(summary.totalOccurrences > 0
                                     ? AgendaColor.textPrimary
                                     : AgendaColor.textMuted)
                    .monospacedDigit()

                Button {
                    store.goToPreviousInNote()
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AgendaColor.textMuted)
                }
                .buttonStyle(.plain)
                .disabled(summary.totalOccurrences == 0)

                Button {
                    store.goToNextInNote()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AgendaColor.textMuted)
                }
                .buttonStyle(.plain)
                .disabled(summary.totalOccurrences == 0)
            }

            Spacer()

            Button {
                closeFindBar()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AgendaColor.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
        )
        .onAppear {
            draftText = store.findInNoteText
            isFieldFocused = true
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
        // Enter → next occurrence (works on every press, not just on text change)
        .onSubmit {
            store.goToNextInNote()
        }
    }

    // MARK: - Key Monitor

    /// Intercepts Esc to close the find bar reliably, even when the
    /// NSTextField holds firstResponder and consumes the key event.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak store] event in
            guard let store, store.isFindInNoteBarVisible else { return event }
            if event.keyCode == 53 { // ⎋ Escape
                store.clearFindInNote()
                return nil
            }
            return event
        } as AnyObject?
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func closeFindBar() {
        store.clearFindInNote()
    }
}
