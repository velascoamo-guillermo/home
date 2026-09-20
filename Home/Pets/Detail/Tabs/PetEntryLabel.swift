import SwiftUI

/// Title + date + optional detail: the row shape every pet section sheet shares.
struct PetEntryLabel: View {
    let title: String
    let meta: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
            Text(meta)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Palette.inkSecondary)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    List {
        PetEntryLabel(title: "Hipoglucemia prolongada (posible sobredosis)",
                      meta: "12 Sep 2025",
                      detail: "Fructosamina por debajo del rango de monitorización")
            .pastelRow(Palette.pets)
        PetEntryLabel(title: "Asma", meta: "21 Apr 2026")
            .pastelRow(Palette.pets)
    }
    .flatListStyle()
}
