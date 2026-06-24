import SwiftUI

struct SearchTaskRow: View {
    let task: HouseholdTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).font(.headline)
                Text(task.nextDueDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
