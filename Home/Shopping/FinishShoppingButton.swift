import SwiftUI

struct FinishShoppingButton: View {
    let action: FinishShoppingAction
    let perform: () -> Void

    var body: some View {
        Button(action: perform) {
            Label(action.title, systemImage: "cart.badge.checkmark")
                .font(.headline)
                .foregroundStyle(Palette.onAccent)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Palette.accent, in: .capsule)
                .shadow(color: Palette.accent.opacity(0.35), radius: 10, y: 4)
                .contentTransition(.numericText())
        }
        .buttonStyle(FinishPressStyle())
        .accessibilityLabel(action.accessibilityLabel)
        .accessibilityIdentifier("finishShopping")
    }
}

private struct FinishPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.3), value: configuration.isPressed)
    }
}
