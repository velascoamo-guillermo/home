import SwiftUI
import WidgetKit

struct HomeWidget: Widget {
    let kind = "HomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HomeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Hogar")
        .description("Próximos eventos y menú de hoy.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
