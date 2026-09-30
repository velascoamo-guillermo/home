import Foundation

/// Integer-cent money helpers. Decimal (not Double) keeps formatting exact.
nonisolated enum Money {
    static func format(cents: Int, locale: Locale = .current) -> String {
        (Decimal(cents) / 100).formatted(.currency(code: "EUR").locale(locale))
    }

    static func spoken(cents: Int) -> String {
        let euros = cents / 100
        let rest = abs(cents % 100)
        let unit = euros == 1 ? "euro" : "euros"
        return rest == 0 ? "\(euros) \(unit)" : "\(euros) \(unit) \(rest)"
    }
}
