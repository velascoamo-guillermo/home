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

    /// Accepts `.` or `,` as decimal separator, ≤2 fraction digits, ≤9 integer digits;
    /// ignores whitespace and `€`. Never uses Double/Decimal division — pure integer math.
    static func parseCents(_ text: String) -> Int? {
        let cleaned = text.filter { !$0.isWhitespace && $0 != "€" }
            .replacingOccurrences(of: ",", with: ".")
        let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard !cleaned.isEmpty, parts.count <= 2 else { return nil }
        let wholeText = String(parts[0])
        let fractionText = parts.count == 2 ? String(parts[1]) : ""
        guard !(wholeText.isEmpty && fractionText.isEmpty),
              wholeText.count <= 9, fractionText.count <= 2,
              (wholeText + fractionText).allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        let whole = Int(wholeText.isEmpty ? "0" : wholeText) ?? 0
        let fraction = Int(fractionText.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
        return whole * 100 + fraction
    }

    static func editText(cents: Int) -> String {
        String(format: "%d.%02d", cents / 100, cents % 100)
    }
}
