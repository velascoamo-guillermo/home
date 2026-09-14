import SwiftUI

struct AgendaHeaderView: View {
    let now: Date
    let tasksDue: Int
    let itemsToBuy: Int

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Self.title(hour: Calendar.current.component(.hour, from: now), date: now))
                .font(.title3.bold())
            HStack(spacing: 8) {
                Chip(title: Self.taskChipTitle(tasksDue), systemImage: "checklist",
                     fill: Palette.tasks, isSelected: false) { open("tasks") }
                Chip(title: "\(itemsToBuy) to buy", systemImage: "cart",
                     fill: Palette.shopping, isSelected: false) { open("shopping") }
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

    static func title(hour: Int, date: Date) -> String {
        "\(greeting(hour: hour)) · \(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))"
    }

    static func taskChipTitle(_ count: Int) -> String {
        "\(count) task\(count == 1 ? "" : "s")"
    }

    static func tasksDue(_ tasks: [HouseholdTask], today: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: today)
        return tasks.filter { calendar.startOfDay(for: $0.nextDueDate) <= start }.count
    }

    private func open(_ host: String) {
        guard let url = URL(string: "home://\(host)") else { return }
        openURL(url)
    }
}

#Preview {
    AgendaHeaderView(now: .now, tasksDue: 3, itemsToBuy: 2)
        .padding()
}
