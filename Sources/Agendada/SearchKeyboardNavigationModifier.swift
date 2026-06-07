import AgendadaCore
import SwiftUI

/// Centralized keyboard handling for the search results view.
///
/// Encapsulates ↑ ↓ Enter Esc behavior so that `SearchResultsContentView` stays
/// focused on display logic, and keyboard navigation has a single source of truth.
struct SearchKeyboardNavigationModifier: ViewModifier {
    @Environment(ObservableLibraryStore.self) private var store

    /// Called when Enter is pressed with a selected result.
    /// Receives the occurrence to open.
    let onOpenResult: (SearchOccurrence) -> Void
    /// Called when Esc is pressed and no search result is selected (second-stage Esc).
    let onExitSearch: () -> Void

    func body(content: Content) -> some View {
        content
            .onExitCommand {
                // Two-stage Esc: first clears selection, second exits search
                if store.selectedSearchResultIndex != nil {
                    store.clearSearchResultSelection()
                } else {
                    onExitSearch()
                }
            }
            .onKeyPress(.upArrow) {
                _ = store.selectPreviousSearchResult()
                return .handled
            }
            .onKeyPress(.downArrow) {
                _ = store.selectNextSearchResult()
                return .handled
            }
            .onKeyPress(.return) {
                if let occ = store.jumpToSelectedSearchResult() {
                    onOpenResult(occ)
                }
                return .handled
            }
    }
}
