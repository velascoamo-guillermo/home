import SwiftUI

struct MealSlotRow: View {
    let slot: MealSlot
    let entry: MealEntry?
    let onCook: () -> Void
    let onAddMissing: () -> Void

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
                    if entry.allShortNeeded {
                        Text("En la compra")
                            .font(.caption2).bold()
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.green.opacity(0.15), in: .capsule)
                            .foregroundStyle(.green)
                    } else {
                        Button(action: onAddMissing) {
                            Text("Falta stock")
                                .font(.caption2).bold()
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(.red.opacity(0.15), in: .capsule)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Añadir faltantes a la compra")
                    }
                }
            }
            .padding(.vertical, 4)
            .contextMenu {
                Button { onCook() } label: {
                    Label("Cocinado", systemImage: "flame.fill")
                }
            }
        } else {
            HStack {
                Text(slot.displayName).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Añadir").font(.caption).foregroundStyle(.tint)
            }
            .padding(.vertical, 4)
        }
    }
}
