import Foundation

enum PetDetailSummary {
    static func ageText(birthday: Date?, now: Date, calendar: Calendar) -> String? {
        guard let birthday else { return nil }
        let comps = calendar.dateComponents([.year, .month], from: birthday, to: now)
        if let years = comps.year, years > 0 { return "\(years) yr\(years == 1 ? "" : "s")" }
        if let months = comps.month, months > 0 { return "\(months) mo" }
        return "<1 mo"
    }

    static func weightText(_ entries: [WeightEntry], locale: Locale = .current) -> String? {
        guard let latest = entries.max(by: { $0.date < $1.date }) else { return nil }
        let value = latest.weightKg.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
        return "\(value) kg"
    }

    static func nextAppointment(_ appointments: [Appointment], now: Date) -> Appointment? {
        appointments
            .filter { $0.status == .upcoming && $0.date >= now }
            .min { $0.date < $1.date }
    }
}
