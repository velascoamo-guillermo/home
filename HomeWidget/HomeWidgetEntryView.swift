import SwiftUI
import WidgetKit

struct HomeWidgetEntryView: View {
    let entry: HomeWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemLarge:
            LargeWidgetView(snapshot: entry.snapshot)
        default:
            MediumWidgetView(snapshot: entry.snapshot)
        }
    }
}
