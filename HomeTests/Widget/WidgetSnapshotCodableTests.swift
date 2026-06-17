import Testing
import Foundation
@testable import Home

struct WidgetSnapshotCodableTests {

    @Test func roundTrip() throws {
        let id = UUID()
        let refDate = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = WidgetSnapshot(
            generatedAt: refDate,
            events: [
                WidgetEvent(
                    id: id,
                    title: "Vacunas",
                    subtitle: "Rex",
                    date: refDate.addingTimeInterval(3600),
                    kind: .appointment,
                    systemImage: "calendar"
                )
            ],
            lunch: WidgetMeal(slot: "lunch", title: "Pasta", products: ["Tomates"], isShort: false, isEmpty: false),
            dinner: WidgetMeal(slot: "dinner", title: "", products: [], isShort: false, isEmpty: true)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetSnapshot.self, from: data)

        #expect(decoded.generatedAt == snapshot.generatedAt)
        #expect(decoded.events.count == 1)
        #expect(decoded.events[0].id == id)
        #expect(decoded.events[0].title == "Vacunas")
        #expect(decoded.events[0].kind == .appointment)
        #expect(decoded.lunch.title == "Pasta")
        #expect(decoded.lunch.products == ["Tomates"])
        #expect(decoded.lunch.isEmpty == false)
        #expect(decoded.dinner.isEmpty == true)
    }
}
