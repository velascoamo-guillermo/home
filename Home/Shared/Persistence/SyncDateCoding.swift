import Foundation

/// Lenient ISO8601 decoding for sync. Postgres `timestamptz` emits fractional
/// seconds (e.g. `2024-06-01T12:00:00.123456+00:00`) which Foundation's
/// `.iso8601` strategy cannot parse — it throws, aborting reconcile for any
/// model without a tolerant custom decoder. This tries fractional first, then plain.
nonisolated enum SyncDateCoding {
    static func date(from string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = date(from: raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Invalid ISO8601 date: \(raw)")
            }
            return date
        }
        return decoder
    }
}
