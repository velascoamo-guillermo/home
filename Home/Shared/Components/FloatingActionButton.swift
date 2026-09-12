import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Palette.onAccent)
        }
        .buttonStyle(FABButtonStyle())
        .accessibilityLabel("Add task")
        .accessibilityIdentifier("fab.addTask")
    }
}

// Button-based press feedback (not a DragGesture), mirroring CardButtonStyle.
private struct FABButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 56, height: 56)
            .background(Circle().fill(Palette.accent))
            .shadow(color: Palette.accent.opacity(0.3), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    FloatingActionButton(action: {})
}
