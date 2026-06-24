import SwiftUI

struct SearchMealRow: View {
    let meal: Meal
    var showsIcon: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            if showsIcon {
                Image(systemName: "fork.knife")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 32)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.title.isEmpty ? "Untitled meal" : meal.title).font(.headline)
                Text(meal.slot.displayName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
