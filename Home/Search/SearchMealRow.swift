import SwiftUI

struct SearchMealRow: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(meal.title.isEmpty ? "Untitled meal" : meal.title).font(.headline)
            if let cals = meal.nutrition.calories {
                Text("\(cals) kcal").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
