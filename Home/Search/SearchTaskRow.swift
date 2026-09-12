import SwiftUI

struct SearchTaskRow: View {
    let task: HouseholdTask

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(task.title).font(.headline)
            Text(task.nextDueDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
