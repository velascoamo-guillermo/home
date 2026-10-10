#if os(macOS)
import Foundation
import Observation

/// Owned by `HomeApp` so every window and the Settings scene share one store and one sync engine.
@Observable
final class MacAppState {
    let store: SupabaseStore
    let calendarFeed: CalendarFeed
    let bootstrap: MacBootstrap

    init() {
        UITestSupport.resetMacSettingsPane()
        let store = UITestSupport.isActive ? UITestSupport.makeStore() : SupabaseStore()
        let feed = UITestSupport.isActive
            ? UITestSupport.makeCalendarFeed()
            : CalendarFeed(source: EventKitCalendarSource())
        self.store = store
        self.calendarFeed = feed
        self.bootstrap = MacBootstrap(
            load: {
                await store.loadAll()
                if UITestSupport.isActive, store.stockProducts.isEmpty {
                    await UITestSupport.seed(store)
                }
            },
            observe: { await feed.observeChanges() },
            refresh: {
                guard !UITestSupport.isActive else { return }
                await store.refreshFromLocal()
                await feed.reload()
            },
            resign: {
                guard !UITestSupport.isActive, store.loadError == nil, !store.isLoading else { return }
                WidgetSnapshotWriter.write(from: store)
            })
    }
}
#endif
