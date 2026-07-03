import SwiftUI

struct PressableGlassCard<Content: View>: View {
    let onTap: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(18)
            .background(.regularMaterial, in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            .scaleEffect(isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .contentShape(.rect(cornerRadius: 20))
            .onTapGesture(perform: onTap)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

#Preview {
    PressableGlassCard(onTap: {}) {
        Text("Header").font(.headline)
        Text("Row content")
    }
    .padding()
}
