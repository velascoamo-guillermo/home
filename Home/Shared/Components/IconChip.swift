import SwiftUI

/// Tinted rounded-square icon badge shared across dashboard cards, hub rows, and
/// list rows. `tint` nil falls back to the app tint.
struct IconChip: View {
    let systemImage: String
    var tint: Color? = nil
    var size: CGFloat = 32

    private var foreground: AnyShapeStyle {
        tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.tint)
    }

    private var background: AnyShapeStyle {
        tint.map { AnyShapeStyle($0.opacity(0.15)) } ?? AnyShapeStyle(.tint.opacity(0.15))
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background, in: .rect(cornerRadius: 9))
            .accessibilityHidden(true)
    }
}

extension View {
    /// Inset-grouped list with a hidden system background so glass rows read as
    /// floating cards over the app backdrop.
    func glassListStyle() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
    }

    /// Glass material backing for a list row, matching the dashboard card look.
    func glassRow() -> some View {
        self.listRowBackground(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                }
                .padding(.vertical, 2)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        IconChip(systemImage: "checklist", tint: .blue)
        IconChip(systemImage: "cart.fill", tint: .green)
        IconChip(systemImage: "pawprint.fill")
    }
    .padding()
}
