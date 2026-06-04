import AgendadaCore
import SwiftUI

struct CategoryBookmarkIcon: View {
    let color: Color

    var body: some View {
        BookmarkShape()
            .fill(color)
            .frame(width: 10, height: 14)
    }
}
