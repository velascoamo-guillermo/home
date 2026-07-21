import SwiftUI

struct SearchMealRow: View {
    let meal: Meal
    var showsIcon: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            if showsIcon {
                IconChip(systemImage: "fork.knife")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.title.isEmpty ? "Untitled meal" : meal.title).font(.headline)
                if let cals = meal.nutrition.calories {
                    Text("\(cals) kcal").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}
