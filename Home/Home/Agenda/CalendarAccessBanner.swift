import SwiftUI
import UIKit

struct CalendarAccessBanner: View {
    let state: CalendarAccessState
    let onAllow: () -> Void
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar")
                .font(.title3)
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(state == .denied ? "Calendar access is off" : "Show your calendar events here")
                    .font(.subheadline.weight(.semibold))
                if state == .denied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } else {
                    Button("Allow", action: onAllow)
                }
            }
            .buttonStyle(.borderless)
            Spacer()
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(Palette.inkSecondary)
        }
        .padding(14)
        .background(Palette.surface, in: .rect(cornerRadius: 16))
    }
}
