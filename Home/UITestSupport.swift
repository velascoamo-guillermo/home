import Foundation
import Supabase

// Drives the app in an isolated, network-free mode for XCUITest runs:
// temp-dir SQLite, no sync engine, deterministic fixtures.
enum UITestSupport {
    nonisolated static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    static func makeStore() -> SupabaseStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("uitests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return SupabaseStore(
            client: SupabaseClient(
                supabaseURL: URL(string: "http://127.0.0.1")!,
                supabaseKey: "uitest",
                options: .init(auth: .init(autoRefreshToken: false, emitLocalSessionAsInitialSession: false))
            ),
            localURL: dir.appendingPathComponent("home.sqlite"),
            syncEnabled: false
        )
    }

    static func seed(_ store: SupabaseStore) async {
        let milk = StockProduct(name: "Fixture Milk", icon: "shippingbox",
                                packages: 2, looseUnits: 0, unitsPerPackage: 6)
        let coffee = StockProduct(name: "Fixture Coffee", icon: "shippingbox",
                                  packages: 1, looseUnits: 0, unitsPerPackage: 1)
        let filters = StockProduct(name: "Fixture Filters", icon: "shippingbox",
                                   packages: 0, looseUnits: 0, unitsPerPackage: 1)
        try? await store.addProduct(milk)
        try? await store.addProduct(coffee)
        try? await store.addProduct(filters)

        var changeFilter = HouseholdTask(
            title: "Fixture Change Filter", icon: "wrench", intervalDays: 30,
            nextDueDate: Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now)
        changeFilter.productId = filters.id
        let waterPlants = HouseholdTask(
            title: "Fixture Water Plants", icon: "wrench", intervalDays: 7,
            nextDueDate: Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now)
        try? await store.addTask(changeFilter)
        try? await store.addTask(waterPlants)
    }
}
