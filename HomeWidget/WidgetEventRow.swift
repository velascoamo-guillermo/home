import SwiftUI

struct WidgetEventRow: View {
    let event: WidgetEvent
    var showSubtitle: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(event.title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            if showSubtitle {
                Text(event.subtitle)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }
        }
    }
}
