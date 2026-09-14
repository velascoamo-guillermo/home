import CoreGraphics
import EventKit
import Foundation
import os

actor EventKitCalendarSource: CalendarEventSource {
    nonisolated let changes: AsyncStream<Void>
    private let store = EKEventStore()
    private let logger = Logger(subsystem: "com.guillermovelasco.managedhome", category: "calendar")
    // Tracks authorization across reads so a store created before access was granted
    // (e.g. via CalendarService's own store, or iOS Settings) is reset once we observe
    // the transition into full access, instead of serving its pre-grant cache forever.
    private var lastState: CalendarAccessState?

    init() {
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        changes = stream
        // Observes every EKEventStore in the process, so exports via CalendarService also refresh the agenda.
        _ = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: nil) { _ in
            continuation.yield(())
        }
    }

    func accessState() -> CalendarAccessState {
        CalendarAccessState(EKEventStore.authorizationStatus(for: .event))
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            if granted { _ = refreshStoreIfNeeded() }
            return granted
        } catch {
            logger.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func calendars() -> [CalendarInfo] {
        _ = refreshStoreIfNeeded()
        return store.calendars(for: .event).map {
            CalendarInfo(id: $0.calendarIdentifier, title: $0.title, color: CalendarColor($0.cgColor))
        }
    }

    func events(in interval: DateInterval, excluding excludedIDs: Set<String>) -> [CalendarEventSnapshot] {
        guard refreshStoreIfNeeded() == .fullAccess else { return [] }
        let included = store.calendars(for: .event).filter { !excludedIDs.contains($0.calendarIdentifier) }
        guard !included.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: included)
        return store.events(matching: predicate).map(Self.snapshot)
    }

    private func refreshStoreIfNeeded() -> CalendarAccessState {
        let current = accessState()
        if current == .fullAccess, lastState != .fullAccess {
            store.reset()
        }
        lastState = current
        return current
    }

    private static func snapshot(_ event: EKEvent) -> CalendarEventSnapshot {
        CalendarEventSnapshot(
            itemIdentifier: event.calendarItemIdentifier,
            title: event.title ?? "",
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            calendarID: event.calendar?.calendarIdentifier ?? "",
            calendarTitle: event.calendar?.title ?? "",
            calendarColor: CalendarColor(event.calendar?.cgColor)
        )
    }
}

private extension CalendarColor {
    nonisolated init(_ cgColor: CGColor?) {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB).flatMap { space in
            cgColor?.converted(to: space, intent: .defaultIntent, options: nil)
        }
        let c = srgb?.components ?? []
        self.init(red: c.count > 2 ? Double(c[0]) : 0.5,
                  green: c.count > 2 ? Double(c[1]) : 0.5,
                  blue: c.count > 2 ? Double(c[2]) : 0.5)
    }
}
