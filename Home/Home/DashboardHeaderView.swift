import SwiftUI

struct DashboardHeaderView: View {
    let tasksDueToday: Int
    let itemsToBuy: Int

    var body: some View {
        HeroHeader(
            label: Self.heroLabel(hour: Calendar.current.component(.hour, from: .now), date: .now),
            value: tasksDueToday,
            unit: "tasks today",
            subline: Self.heroSubline(tasksDueToday: tasksDueToday, itemsToBuy: itemsToBuy)
        )
    }

    static func greeting(hour: Int) -> String {
        switch hour {
        case ..<12: "Good morning"
        case ..<18: "Good afternoon"
        default:    "Good evening"
        }
    }

    static func summary(tasksDueToday: Int, itemsToBuy: Int) -> String? {
        var parts: [String] = []
        if tasksDueToday > 0 {
            parts.append("\(tasksDueToday) task\(tasksDueToday == 1 ? "" : "s") today")
        }
        if itemsToBuy > 0 {
            parts.append("\(itemsToBuy) to buy")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func heroLabel(hour: Int, date: Date) -> String {
        "\(greeting(hour: hour)) · \(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))"
    }

    static func heroSubline(itemsToBuy: Int) -> String? {
        itemsToBuy == 0 ? nil : "\(itemsToBuy) to buy"
    }

    static func heroSubline(tasksDueToday: Int, itemsToBuy: Int) -> String? {
        if tasksDueToday == 0 && itemsToBuy == 0 {
            return "All clear ✨"
        }
        return heroSubline(itemsToBuy: itemsToBuy)
    }
}

#Preview {
    DashboardHeaderView(tasksDueToday: 3, itemsToBuy: 2)
        .padding()
}
