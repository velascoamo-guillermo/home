import SwiftUI

struct EventRow: View {
    let event: PetEvent

    private var meta: String {
        let date = event.date.formatted(date: .abbreviated, time: .omitted)
        guard let value = event.value, !value.isEmpty else { return date }
        return "\(date) · \(value)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.category.icon)
                .font(.title3)
                .foregroundStyle(Palette.accent)
                .frame(width: 32)
                .accessibilityHidden(true)
            PetEntryLabel(title: event.title, meta: meta)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Palette.inkSecondary)
                .accessibilityHidden(true)
        }
    }
}
