#if os(macOS)
import SwiftUI

struct MacScenes: Scene {
    let app: MacAppState

    var body: some Scene {
        WindowGroup(for: MacWindowSeed.self) { $seed in
            MacRootView(seed: $seed)
                .environment(app.store)
                .environment(app.calendarFeed)
                .environment(app.bootstrap)
        } defaultValue: {
            .new(.today)
        }
        .defaultSize(width: 1100, height: 720)
        .commands { MacAppCommands(store: app.store, bootstrap: app.bootstrap) }

        Settings {
            MacSettingsView()
                .environment(app.store)
                .environment(app.calendarFeed)
        }

        Window("Casita Help", id: MacHelpView.windowID) {
            MacHelpView()
        }
        .windowResizability(.contentSize)
    }
}
#endif
