import AppIntents
import SwiftUI

struct WidgetCompleteButton: View {
    let event: WidgetEvent

    var body: some View {
        Button(intent: CompleteTaskIntent(taskId: event.id.uuidString)) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17))
                .foregroundStyle(Palette.accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Completar \(event.title)")
    }
}
