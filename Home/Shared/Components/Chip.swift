import SwiftUI

struct Chip: View {
    let title: String
    var systemImage: String? = nil
    let fill: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
                Text(title)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.accent)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(ChipButtonStyle(fill: fill, isSelected: isSelected))
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// Button-based press feedback (not a DragGesture) so the chip never blocks an enclosing ScrollView's pan and the press state cannot stick on scroll-steal.
private struct ChipButtonStyle: ButtonStyle {
    let fill: Color
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(fill, in: .capsule)
            .overlay {
                if isSelected {
                    Capsule().stroke(Palette.accent, lineWidth: 2)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(.capsule)
    }
}

#Preview {
    VStack(spacing: 12) {
        Chip(title: "Dogs", systemImage: "pawprint.fill", fill: Palette.pets, isSelected: true, action: {})
        Chip(title: "Cats", fill: Palette.pets, isSelected: false, action: {})
    }
    .padding()
}
