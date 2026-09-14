import SwiftUI

struct MenuHeaderView: View {
    let today: Weekday
    let summary: MenuWeekSummary
    let onPlannedTap: () -> Void
    let onShortTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hoy · \(today.displayName)")
                .font(.title3.bold())
            HStack(spacing: 8) {
                Chip(title: summary.plannedTitle, systemImage: "fork.knife",
                     fill: Palette.meals, isSelected: false, action: onPlannedTap)
                if summary.shortCount > 0 {
                    Chip(title: "\(summary.shortCount) falta stock", systemImage: "cart",
                         fill: Palette.shopping, isSelected: false, action: onShortTap)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    MenuHeaderView(today: .thursday, summary: MenuWeekSummary(entries: []),
                   onPlannedTap: {}, onShortTap: {})
        .padding()
}
