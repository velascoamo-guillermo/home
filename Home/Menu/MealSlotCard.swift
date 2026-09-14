import SwiftUI

struct MealSlotCard: View {
    let slot: MealSlot
    let entry: MealEntry?
    let onCook: () -> Void
    let onAddMissing: () -> Void

    var body: some View {
        if let entry {
            filled(entry)
        } else {
            empty
        }
    }

    private func filled(_ entry: MealEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(slot.displayName.uppercased(), systemImage: Self.icon(for: slot))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.inkSecondary)
                Spacer()
                stockBadge(entry)
            }
            Text(entry.meal.title.isEmpty ? "Sin título" : entry.meal.title)
                .font(.title3.bold())
                .foregroundStyle(Palette.ink)
            if let detail = Self.detail(for: entry) {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .contextMenu {
            Button(action: onCook) {
                Label("Cocinado", systemImage: "flame.fill")
            }
        }
    }

    private var empty: some View {
        HStack(spacing: 12) {
            Image(systemName: Self.icon(for: slot))
                .font(.body)
                .foregroundStyle(Palette.inkSecondary)
                .accessibilityHidden(true)
            Text("Añadir \(slot.displayName.lowercased())")
                .font(.headline)
                .foregroundStyle(Palette.inkSecondary)
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Añadir \(slot.displayName.lowercased())")
    }

    @ViewBuilder
    private func stockBadge(_ entry: MealEntry) -> some View {
        if entry.isShort {
            if entry.allShortNeeded {
                badge("En la compra", color: .green)
            } else {
                Button(action: onAddMissing) {
                    badge("Falta stock", color: .red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Añadir faltantes a la compra")
            }
        }
    }

    private func badge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.15), in: .capsule)
            .foregroundStyle(color)
    }

    static func icon(for slot: MealSlot) -> String {
        switch slot {
        case .lunch:  "sun.max.fill"
        case .dinner: "moon.stars.fill"
        }
    }

    static func detail(for entry: MealEntry) -> String? {
        var parts = entry.links.map(\.product.name)
        if let calories = entry.meal.nutrition.calories { parts.append("\(calories) kcal") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
