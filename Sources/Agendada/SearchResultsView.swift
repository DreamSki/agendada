import AgendadaCore
import SwiftUI

// MARK: - Search Results Mode

/// Renders search results as grouped snippets instead of full note cards.
struct SearchResultsContentView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @Binding var navigationTargetNoteID: Note.ID?
    @State private var expandedSearchResultNoteIDs: Set<Note.ID> = []

    var body: some View {
        let groups = store.searchResultGroups()
        let summary = store.searchSummary
        let scopeLabel = searchScopeLabel
        let selectedIndex = store.selectedSearchResultIndex

        VStack(alignment: .leading, spacing: 0) {
            // Summary header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("搜索结果：\(store.library.searchHighlightText)")
                        .font(AgendaFont.breadcrumbTitle)
                        .foregroundStyle(Color(red: 0.173, green: 0.173, blue: 0.180))
                    Spacer()
                    Text("\(summary.totalMatchedNotes) 篇笔记 · \(summary.totalOccurrences) 个命中")
                        .font(AgendaFont.cardMeta)
                        .foregroundStyle(AgendaColor.textMuted)
                }

                HStack(spacing: 8) {
                    Text(scopeLabel)
                        .font(AgendaFont.panelMicro)
                        .foregroundStyle(AgendaColor.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AgendaColor.sidebarBg, in: Capsule())

                    Spacer()

                    Button {
                        store.exitSearchMode()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .semibold))
                            Text("退出搜索")
                                .font(AgendaFont.panelMicro)
                        }
                        .foregroundStyle(AgendaColor.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlColor), in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AgendaSpacing.cardPaddingH)
            .padding(.bottom, 14)

            ForEach(groups) { group in
                SearchResultGroupRow(
                    group: group,
                    highlightTerms: highlightTerms,
                    selectedGlobalIndex: selectedIndex,
                    isExpanded: isSearchResultGroupExpanded(group.note.id),
                    onToggleExpand: {
                        toggleSearchResultGroupExpansion(group.note.id)
                    },
                    onSelectOccurrence: { occurrence in
                        openResult(occurrence)
                    }
                )
                .padding(.bottom, AgendaSpacing.cardGap)
            }
        }
        .onChange(of: store.searchPresentationMode) { _, newMode in
            // Clear expanded groups when search mode changes
            if newMode == .normal {
                clearExpandedSearchResultGroups()
            }
        }
        .onChange(of: store.library.searchHighlightText) { _, _ in
            // Clear expanded groups when search query changes
            clearExpandedSearchResultGroups()
        }
    }

    private var searchScopeLabel: String {
        if let pid = store.selectedProjectID, let proj = store.project(withID: pid) {
            return "项目：\(proj.name)"
        }
        if store.selectedOverview == .trash { return "废纸篓" }
        if store.selectedOverview == .all { return "全部笔记" }
        if let ov = store.selectedOverview { return ov.title }
        return "当前范围"
    }

    private var highlightTerms: [String] {
        let raw = store.library.searchHighlightText
        return raw.split(separator: " ").map(String.init)
    }

    private func isSearchResultGroupExpanded(_ noteID: Note.ID) -> Bool {
        expandedSearchResultNoteIDs.contains(noteID)
    }

    private func toggleSearchResultGroupExpansion(_ noteID: Note.ID) {
        if expandedSearchResultNoteIDs.contains(noteID) {
            expandedSearchResultNoteIDs.remove(noteID)
        } else {
            expandedSearchResultNoteIDs.insert(noteID)
        }
    }

    private func clearExpandedSearchResultGroups() {
        expandedSearchResultNoteIDs.removeAll()
    }

    /// Unified path for opening a search result — click or Enter.
    /// Navigates to the source project, selects the note, prepares editor
    /// highlight navigation, then exits search results mode.
    private func openResult(_ occurrence: SearchOccurrence) {
        // 1. Navigate to source note's project without clearing search state
        store.openSearchResult(occurrence)
        navigationTargetNoteID = occurrence.noteID

        // 2. Prepare editor navigation before exiting search
        let query = store.library.searchHighlightText
        if !query.isEmpty {
            SharedBlockNoteWebView.shared.prepareSearchNavigation(
                noteID: occurrence.noteID,
                query: query,
                bodyIndex: occurrence.field == .body ? occurrence.bodyIndexInNote : 0
            )
        }

        // 3. Exit search mode — editor already has pending navigation from step 2
        store.exitSearchMode()
    }
}

/// Zero-results state when committed search yields no matches.
struct SearchNoResultsView: View {
    @Environment(ObservableLibraryStore.self) private var store
    let searchText: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AgendaColor.textMuted.opacity(0.5))

            Text("没有找到「\(searchText)」")
                .font(AgendaFont.panelSectionTitle)
                .foregroundStyle(AgendaColor.textMuted)

            VStack(spacing: 4) {
                Text("试试：")
                    .font(AgendaFont.panelCaption)
                    .foregroundStyle(AgendaColor.textMuted)
                if store.searchScope != .all {
                    Button {
                        store.searchScope = .all
                    } label: {
                        Text("搜索全部笔记")
                            .font(AgendaFont.panelCaption)
                            .foregroundStyle(AgendaColor.amber)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct SearchResultGroupRow: View {
    @Environment(ObservableLibraryStore.self) private var store
    let group: SearchResultGroup
    let highlightTerms: [String]
    let selectedGlobalIndex: Int?
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onSelectOccurrence: (SearchOccurrence) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Note title + match count badge
            Button {
                if let first = group.occurrences.first {
                    onSelectOccurrence(first)
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(group.note.title.isEmpty ? "无标题" : group.note.title)
                        .font(AgendaFont.cardTitle)
                        .foregroundStyle(Color(red: 0.102, green: 0.102, blue: 0.102))
                        .lineLimit(1)

                    Text("\(group.occurrences.count)")
                        .font(.custom("Avenir Next Demi Bold", size: 9))
                        .foregroundStyle(AgendaColor.amber)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(AgendaColor.amber.opacity(0.12), in: Capsule())

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // Snippets (3 by default, or all when expanded)
            VStack(alignment: .leading, spacing: 4) {
                let visibleSnippets = isExpanded ? group.snippets : Array(group.snippets.prefix(3))

                ForEach(visibleSnippets) { snippet in
                    let isSelected = selectedGlobalIndex == snippet.occurrence.globalIndex
                    Button {
                        onSelectOccurrence(snippet.occurrence)
                    } label: {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: snippet.occurrence.field == .title ? "textformat" : "doc.text")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(isSelected ? AgendaColor.amber : AgendaColor.amber.opacity(0.6))
                                .frame(width: 14)
                                .padding(.top, 1)

                            HighlightedText(
                                text: snippet.occurrence.excerpt,
                                terms: highlightTerms,
                                baseFont: AgendaFont.cardBodyCompact,
                                baseColor: isSelected ? Color(red: 0.2, green: 0.2, blue: 0.2) : AgendaColor.textMuted,
                                highlightColor: AgendaColor.amber
                            )
                            .lineLimit(2)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(isSelected ? AgendaColor.amber.opacity(0.08) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? AgendaColor.amber : Color.clear, lineWidth: 1)
                            .background(isSelected ? AgendaColor.amber.opacity(0.08) : Color.clear)
                    )
                }

                // Expand/collapse button when there are more than 3 snippets
                if group.snippets.count > 3 {
                    Button {
                        onToggleExpand()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(AgendaColor.textMuted)

                            Text(isExpanded ? "收起" : "显示全部 \(group.snippets.count) 个命中")
                                .font(AgendaFont.panelMicro)
                                .foregroundStyle(AgendaColor.textMuted)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AgendaColor.sidebarBg, in: RoundedRectangle(cornerRadius: 3))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 28)
                }
            }
            .padding(.leading, 28)
        }
        .padding(AgendaSpacing.cardPaddingV)
        .padding(.horizontal, AgendaSpacing.cardPaddingH)
        .background(Color.white, in: RoundedRectangle(cornerRadius: AgendaSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AgendaSpacing.cardRadius)
                .stroke(AgendaColor.cardBorder, lineWidth: 0.5)
        )
        .shadow(color: AgendaColor.cardShadow, radius: 4, y: 2)
        .padding(.horizontal, 12)
    }
}

/// Renders text with case-insensitive term highlighting using AttributedString.
struct HighlightedText: View {
    let text: String
    let terms: [String]
    let baseFont: Font
    let baseColor: Color
    let highlightColor: Color

    var body: some View {
        if terms.isEmpty {
            Text(text)
                .font(baseFont)
                .foregroundStyle(baseColor)
        } else {
            Text(attributedText)
        }
    }

    private var attributedText: AttributedString {
        let nsString = text as NSString
        var result = AttributedString(text)
        result.font = baseFont
        result.foregroundColor = baseColor

        for term in terms {
            guard let regex = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: term), options: .caseInsensitive) else { continue }
            let fullRange = NSRange(location: 0, length: nsString.length)
            for match in regex.matches(in: text, range: fullRange) {
                guard match.range.lowerBound < nsString.length,
                      match.range.upperBound <= nsString.length else { continue }
                let lower = String.Index(utf16Offset: match.range.lowerBound, in: text)
                let upper = String.Index(utf16Offset: match.range.upperBound, in: text)
                if let range = Range(lower..<upper, in: result) {
                    result[range].backgroundColor = highlightColor.opacity(0.25)
                    result[range].foregroundColor = Color(red: 0.2, green: 0.2, blue: 0.2)
                }
            }
        }
        return result
    }
}
