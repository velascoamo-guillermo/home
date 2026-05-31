import SwiftUI

struct MealSlotRow: View {
    let slot: MealSlot
    let entry: MealEntry?
    let onSuggest: () -> Void
    let onCook: () -> Void

    var body: some View {
        if let entry {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(slot.displayName).font(.caption).foregroundStyle(.secondary)
                    Text(entry.meal.title.isEmpty ? "Sin título" : entry.meal.title)
                        .font(.body)
                    if !entry.links.isEmpty {
                        Text(entry.links.map(\.product.name).joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let cals = entry.meal.nutrition.calories {
                        Text("\(cals) kcal").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if entry.isShort {
                    Text("Falta stock")
                        .font(.caption2).bold()
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.red.opacity(0.15), in: .capsule)
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 4)
            .swipeActions(edge: .leading) {
                Button { onCook() } label: {
                    Label("Cocinado", systemImage: "flame.fill")
                }
                .tint(.green)
            }
        } else {
            HStack {
                Text(slot.displayName).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { onSuggest() } label: {
                    Label("Sugerir", systemImage: "sparkles").font(.caption)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Sugerir \(slot.displayName)")
            }
            .padding(.vertical, 4)
        }
    }
}
