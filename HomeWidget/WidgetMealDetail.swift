import SwiftUI

struct WidgetMealDetail: View {
    let meal: WidgetMeal

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(meal.slotLabel)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Palette.inkSecondary)
                if meal.isShort {
                    Text("Falta stock")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.orange, in: .capsule)
                        .foregroundStyle(Palette.onAccent)
                }
            }
            Text(meal.title)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            if !meal.products.isEmpty {
                Text(meal.products.joined(separator: " · "))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }
        }
    }
}
