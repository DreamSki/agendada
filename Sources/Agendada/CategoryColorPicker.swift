import AgendadaCore
import SwiftUI

struct BookmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.28))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct CategoryColorPicker: View {
    @Binding var selectedColor: CategoryColor

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Array(CategoryColor.allCases.prefix(7)), id: \.self) { color in
                    colorButton(color)
                }
            }
            HStack(spacing: 6) {
                ForEach(Array(CategoryColor.allCases.dropFirst(7)), id: \.self) { color in
                    colorButton(color)
                }
            }
        }
    }

    private func colorButton(_ color: CategoryColor) -> some View {
        Button {
            selectedColor = color
        } label: {
            BookmarkShape()
                .fill(color.sidebarTint)
                .frame(width: 22, height: 28)
                .overlay {
                    if selectedColor == color {
                        BookmarkShape()
                            .stroke(AgendaColor.amber, lineWidth: 2)
                            .frame(width: 22, height: 28)
                    }
                }
                .frame(width: 32, height: 36)
        }
        .buttonStyle(.plain)
    }
}
