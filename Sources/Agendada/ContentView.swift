import AgendadaCore
import SwiftUI

struct ContentView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @State private var sidebarWidth: CGFloat = 260
    @State private var detailWidth: CGFloat = 340

    var body: some View {
        @Bindable var store = store

        HStack(spacing: 0) {
            SidebarView()
                .ignoresSafeArea(.container, edges: .top)
                .frame(width: sidebarWidth)

            Divider()

            NoteStreamView(searchText: $store.searchText)
                .ignoresSafeArea(.container, edges: .top)

            Divider()

            RelatedPanelContentView()
                .ignoresSafeArea(.container, edges: .top)
                .frame(width: detailWidth)
        }
    }
}
