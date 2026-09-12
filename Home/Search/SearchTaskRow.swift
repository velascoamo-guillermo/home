import SwiftUI

struct SearchTaskRow: View {
    let task: HouseholdTask

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).font(.headline)
                Text(task.nextDueDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
