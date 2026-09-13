import Foundation
import Observation

@Observable
final class CalendarFeed {
    private(set) var accessState: CalendarAccessState = .notDetermined
    private(set) var events: [CalendarEventSnapshot] = []
    private(set) var calendars: [CalendarInfo] = []
    private(set) var excludedIDs: Set<String>
    private(set) var isBannerDismissed: Bool

    @ObservationIgnored private let source: any CalendarEventSource
    @ObservationIgnored private let selection: CalendarSelectionStore
    @ObservationIgnored private var loadedInterval: DateInterval?
    // A refused upgrade from write-only access still reports write-only; surface it as denied.
    @ObservationIgnored private var accessRefused = false

    init(source: any CalendarEventSource, selection: CalendarSelectionStore = CalendarSelectionStore()) {
        self.source = source
        self.selection = selection
        self.excludedIDs = selection.excludedIDs()
        self.isBannerDismissed = selection.isBannerDismissed
    }

    var showsBanner: Bool {
        !isBannerDismissed && (accessState == .notDetermined || accessState == .denied)
    }

    func load(interval: DateInterval) async {
        loadedInterval = interval
        await reload()
    }

    func reload() async {
        let state = await source.accessState()
        accessState = (state == .notDetermined && accessRefused) ? .denied : state
        await refetch()
    }

    func requestAccess() async {
        let granted = await source.requestAccess()
        accessRefused = !granted
        await reload()
        if granted { await loadCalendars() }
    }

    func loadCalendars() async {
        guard accessState == .fullAccess else {
            calendars = []
            return
        }
        let list = await source.calendars()
        calendars = list
        guard !list.isEmpty else { return }
        let pruned = excludedIDs.intersection(list.map(\.id))
        if pruned != excludedIDs {
            excludedIDs = pruned
            selection.setExcludedIDs(pruned)
        }
    }

    func setCalendar(_ id: String, included: Bool) {
        if included {
            excludedIDs.remove(id)
        } else {
            excludedIDs.insert(id)
        }
        selection.setExcludedIDs(excludedIDs)
        Task { await refetch() }
    }

    func dismissBanner() {
        selection.dismissBanner()
        isBannerDismissed = true
    }

    // AsyncStream is single-consumer: call once for the app's lifetime (ContentView).
    func observeChanges() async {
        for await _ in source.changes {
            await reload()
        }
    }

    private func refetch() async {
        guard let interval = loadedInterval else { return }
        guard accessState == .fullAccess else {
            events = []
            return
        }
        let fetched = await source.events(in: interval, excluding: excludedIDs)
        guard loadedInterval == interval else { return }
        events = fetched
    }
}
