// Home/Pets/Detail/Tabs/ClinicalEntryRow.swift
import SwiftUI

struct ClinicalEntryRow: View {
    let entry: ClinicalEntry
    let fileCount: Int

    var body: some View {
        HStack(spacing: 10) {
            PetEntryLabel(
                title: entry.title,
                meta: entry.date.formatted(date: .abbreviated, time: .omitted),
                detail: entry.description
            )
            if fileCount > 0 {
                Label("\(fileCount)", systemImage: "paperclip")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Palette.surface, in: .capsule)
                    .accessibilityLabel("\(fileCount) attached \(fileCount == 1 ? "file" : "files")")
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Palette.inkSecondary)
                .accessibilityHidden(true)
        }
    }
}
