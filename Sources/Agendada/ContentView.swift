import AgendadaCore
import SwiftUI

struct ContentView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @State private var sidebarWidth: CGFloat = 240
    @State private var detailWidth: CGFloat = 340
    @State private var noteNavigationTarget: Note.ID?

    var body: some View {
        @Bindable var store = store

        HStack(spacing: 0) {
            SidebarView()
                .ignoresSafeArea(.container, edges: .top)
                .frame(width: sidebarWidth)

            NoteStreamView(searchText: $store.searchText, navigationTargetNoteID: $noteNavigationTarget)
                .ignoresSafeArea(.container, edges: .top)

            Divider()

            RelatedPanelContentView(navigateToNote: navigateToNote)
                .ignoresSafeArea(.container, edges: .top)
                .frame(width: detailWidth)
        }
    }

    private func navigateToNote(_ noteID: Note.ID) {
        noteNavigationTarget = noteID
        store.selectNote(noteID)
    }
}
