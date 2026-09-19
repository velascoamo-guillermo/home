import SwiftUI

struct WidgetSectionHeader: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .accessibilityHidden(true)
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
        }
        .foregroundStyle(Palette.ink)
    }
}
