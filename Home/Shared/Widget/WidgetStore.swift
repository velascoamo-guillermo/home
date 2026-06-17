import Foundation

// Explicitly nonisolated: this type is compiled into BOTH the app target
// (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor) and the widget extension
// (which may not set that). nonisolated makes it identical in both and
// callable from the widget's nonisolated TimelineProvider methods.
nonisolated enum WidgetStore {
    static let appGroupIdentifier = "group.com.guille.home"

    private static var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("widget-snapshot.json")
    }

    static func read() -> WidgetSnapshot? {
        guard let url = snapshotURL,
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let url = snapshotURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
