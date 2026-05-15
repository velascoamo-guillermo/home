import SwiftUI

struct ClinicalEntryRow: View {
    let entry: ClinicalEntry
    let fileCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title).font(.headline)
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
                if !entry.description.isEmpty {
                    Text(entry.description).font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
                }
            }
            Spacer()
            if fileCount > 0 {
                Label("\(fileCount)", systemImage: "paperclip")
                    .font(.caption2).foregroundStyle(.secondary)
                    .accessibilityLabel("\(fileCount) attached \(fileCount == 1 ? "file" : "files")")
            }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}
