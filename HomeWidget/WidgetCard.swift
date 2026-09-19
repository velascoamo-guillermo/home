import SwiftUI

/// Flat pastel card over the widget's gradient canvas, matching `pastelRow` in the app.
struct WidgetCard<Content: View>: View {
    let fill: Color
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(12)
            .background(fill, in: .rect(cornerRadius: 16))
    }
}
