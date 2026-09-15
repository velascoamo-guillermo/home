import Testing
import Foundation
@testable import Casita

@Suite("PetDetailSummary") @MainActor struct PetDetailSummaryTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return c
    }()
    private let en = Locale(identifier: "en_US")

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test("age uses years once a year old, singular for one")
    func ageYears() {
        let now = date(2026, 9, 14)
        #expect(PetDetailSummary.ageText(birthday: date(2023, 5, 1), now: now, calendar: calendar) == "3 yrs")
        #expect(PetDetailSummary.ageText(birthday: date(2025, 9, 14), now: now, calendar: calendar) == "1 yr")
    }

    @Test("age falls back to months, then under a month")
    func ageMonths() {
        let now = date(2026, 9, 14)
        #expect(PetDetailSummary.ageText(birthday: date(2026, 4, 2), now: now, calendar: calendar) == "5 mo")
        #expect(PetDetailSummary.ageText(birthday: date(2026, 9, 1), now: now, calendar: calendar) == "<1 mo")
        #expect(PetDetailSummary.ageText(birthday: nil, now: now, calendar: calendar) == nil)
    }

    @Test("weight shows the most recent entry regardless of order")
    func latestWeight() {
        let pet = UUID()
        let entries = [
            WeightEntry(petId: pet, date: date(2026, 1, 1), weightKg: 3.9),
            WeightEntry(petId: pet, date: date(2026, 8, 1), weightKg: 4.26),
            WeightEntry(petId: pet, date: date(2026, 5, 1), weightKg: 4.0),
        ]
        #expect(PetDetailSummary.weightText(entries, locale: en) == "4.3 kg")
        #expect(PetDetailSummary.weightText([WeightEntry(petId: pet, date: .now, weightKg: 5)], locale: en) == "5 kg")
        #expect(PetDetailSummary.weightText([], locale: en) == nil)
    }

    @Test("next appointment is the earliest upcoming one not in the past")
    func nextAppointment() {
        let pet = UUID()
        let now = date(2026, 9, 14, 12)
        func appt(_ d: Date, _ status: AppointmentStatus, _ reason: String) -> Appointment {
            Appointment(petId: pet, date: d, reason: reason, notes: "", status: status)
        }
        let appts = [
            appt(date(2026, 9, 30), .upcoming, "later"),
            appt(date(2026, 9, 14, 9), .upcoming, "stale"),
            appt(date(2026, 9, 16), .cancelled, "cancelled"),
            appt(date(2026, 9, 20), .upcoming, "next"),
            appt(date(2026, 9, 15), .done, "done"),
        ]
        #expect(PetDetailSummary.nextAppointment(appts, now: now)?.reason == "next")
        #expect(PetDetailSummary.nextAppointment([], now: now) == nil)
    }

    @Test("tile accessibility label appends a positive badge count")
    func tileLabel() {
        #expect(Tile.accessibilityLabel(title: "History", badge: 5) == "History, 5")
        #expect(Tile.accessibilityLabel(title: "History", badge: 0) == "History")
        #expect(Tile.accessibilityLabel(title: "Vet", badge: nil) == "Vet")
    }
}
