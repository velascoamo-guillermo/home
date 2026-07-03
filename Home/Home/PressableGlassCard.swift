import SwiftUI

struct PressableGlassCard<Content: View>: View {
    let onTap: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12, content: content)
        }
        .buttonStyle(GlassCardButtonStyle())
    }
}

// Button-based press feedback (not a DragGesture) so the card never blocks the
// enclosing ScrollView's pan and the press state cannot stick on scroll-steal.
private struct GlassCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(.rect(cornerRadius: 20))
    }
}

#Preview {
    PressableGlassCard(onTap: {}) {
        Text("Header").font(.headline)
        Text("Row content")
    }
    .padding()
}
