#if os(macOS)
import Foundation
import Observation

/// App-wide lifecycle for every window: load once, observe calendars once, refresh on
/// activation at most once per `activationDebounce` however many windows report it.
@Observable
final class MacBootstrap {
    static let activationDebounce: TimeInterval = 5

    private(set) var didStart = false
    private(set) var didFinishLoading = false

    @ObservationIgnored private let load: @MainActor () async -> Void
    @ObservationIgnored private let observe: @MainActor () async -> Void
    @ObservationIgnored private let refresh: @MainActor () async -> Void
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private var lastRefresh: Date?

    init(load: @escaping @MainActor () async -> Void,
         observe: @escaping @MainActor () async -> Void,
         refresh: @escaping @MainActor () async -> Void,
         now: @escaping @MainActor () -> Date = { .now }) {
        self.load = load
        self.observe = observe
        self.refresh = refresh
        self.now = now
    }

    func start() async {
        guard !didStart else { return }
        didStart = true
        let observe = observe
        Task { await observe() }
        await load()
        didFinishLoading = true
    }

    func appDidBecomeActive() async {
        guard didFinishLoading else { return }
        let current = now()
        if let lastRefresh, current.timeIntervalSince(lastRefresh) < Self.activationDebounce { return }
        lastRefresh = current
        await refresh()
    }
}
#endif
