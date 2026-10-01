#if os(macOS)
import SwiftUI

struct MacScenes: Scene {
    let app: MacAppState

    var body: some Scene {
        WindowGroup(for: SidebarItem.self) { $item in
            MacRootView(item: $item)
                .environment(app.store)
                .environment(app.calendarFeed)
                .environment(app.bootstrap)
        } defaultValue: {
            .today
        }
        .defaultSize(width: 1100, height: 720)
        .commands { MacAppCommands(store: app.store) }
    }
}
#endif
