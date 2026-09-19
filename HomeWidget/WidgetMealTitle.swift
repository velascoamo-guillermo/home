import SwiftUI

struct WidgetMealTitle: View {
    let meal: WidgetMeal

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(meal.slotLabel)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Palette.inkSecondary)
            Text(meal.isEmpty ? "Sin planificar" : meal.title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(meal.isEmpty ? Palette.inkSecondary : Palette.ink)
                .lineLimit(2)
        }
    }
}
