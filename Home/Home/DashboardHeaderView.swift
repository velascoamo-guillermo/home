import SwiftUI

struct DashboardHeaderView: View {
    let tasksDueToday: Int
    let itemsToBuy: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.greeting(hour: Calendar.current.component(.hour, from: .now)))
                .font(.title.bold())
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let summary = Self.summary(tasksDueToday: tasksDueToday, itemsToBuy: itemsToBuy) {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
}

#Preview {
    DashboardHeaderView(tasksDueToday: 3, itemsToBuy: 2)
        .padding()
}
