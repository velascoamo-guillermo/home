import SwiftUI

struct PressableCard<Content: View>: View {
    let fill: Color
    let onTap: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12, content: content)
        }
        .buttonStyle(CardButtonStyle(fill: fill))
    }
}

// Button-based press feedback (not a DragGesture) so the card never blocks the
// enclosing ScrollView's pan and the press state cannot stick on scroll-steal.
private struct CardButtonStyle: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: 20))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(.rect(cornerRadius: 20))
    }
}

#Preview {
    PressableCard(fill: Palette.tasks, onTap: {}) {
        Text("Header").font(.headline)
        Text("Row content")
    }
    .padding()
}
