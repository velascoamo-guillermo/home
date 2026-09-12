import Testing
@testable import Casita

@Suite("TaskSection.Predefined") struct PredefinedSectionTests {

    @Test("raw values are stable keys")
    func keys() {
        #expect(TaskSection.Predefined.allCases.map(\.rawValue) == [
            "general", "plumbing", "kitchen", "climate", "lighting",
            "cleaning", "storage", "repairs", "garden", "airQuality",
        ])
    }

    @Test("legacy icon strings map to sections", arguments: [
        ("wrench", TaskSection.Predefined.general), ("drop", .plumbing),
        ("flame", .kitchen), ("fan", .climate), ("lightbulb", .lighting),
        ("trash", .cleaning), ("shippingbox", .storage), ("hammer", .repairs),
        ("leaf", .garden), ("air.purifier", .airQuality),
        ("pawprint", .general), ("", .general),
    ])
    func legacy(icon: String, expected: TaskSection.Predefined) {
        #expect(TaskSection.Predefined(legacyIcon: icon) == expected)
    }

    @Test("every case has a name")
    func names() {
        for c in TaskSection.Predefined.allCases { #expect(!c.name.isEmpty) }
    }
}
