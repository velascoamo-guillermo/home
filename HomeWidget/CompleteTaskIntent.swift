import AppIntents
import Foundation
import WidgetKit
import os

struct CompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Task"

    @Parameter(title: "Task ID")
    var taskId: String

    init() {}
    init(taskId: String) { self.taskId = taskId }

    func perform() async throws -> some IntentResult {
        let logger = Logger(subsystem: "com.guillermovelasco.managedhome.HomeWidget",
                             category: "intent")
        // Every exit path — success, guard early-out, or thrown error — must
        // reload timelines so the widget never shows a stale checkmark state.
        defer { WidgetCenter.shared.reloadAllTimelines() }

        guard let id = UUID(uuidString: taskId),
              let dbURL = FileManager.default
                  .containerURL(forSecurityApplicationGroupIdentifier: WidgetStore.appGroupIdentifier)?
                  .appendingPathComponent("home.sqlite")
        else {
            logger.error("invalid taskId or missing app-group container: \(taskId, privacy: .public)")
            return .result()
        }

        do {
            let store = try await LocalStore(url: dbURL)
            let tasks = try await store.fetchAll(HouseholdTask.self)
            guard let task = tasks.first(where: { $0.id == id }) else {
                logger.error("task not found: \(id, privacy: .public)")
                return .result()
            }
            let products = try await store.fetchAll(StockProduct.self)

            let plan = TaskCompletion.plan(for: task, stockProducts: products)
            var updatedTask = plan.updatedTask
            updatedTask.updatedAt = .now
            try await store.upsert([updatedTask], enqueue: true)
            if var product = plan.updatedProduct {
                product.updatedAt = .now
                try await store.upsert([product], enqueue: true)
            }

            refreshSnapshot(tasks: tasks.map { $0.id == id ? updatedTask : $0 },
                            products: products)
        } catch {
            logger.error("complete failed: \(error)")
        }

        return .result()
    }

    private func refreshSnapshot(tasks: [HouseholdTask], products: [StockProduct]) {
        guard var snapshot = WidgetStore.read() else { return }
        let appointments = snapshot.events.filter { $0.kind == .appointment }
        let taskEvents = tasks.map { task in
            WidgetEvent(task: task,
                        productName: task.productId.flatMap { pid in
                            products.first { $0.id == pid }?.name
                        })
        }
        snapshot.events = Array((appointments + taskEvents)
            .sorted { $0.date < $1.date }
            .prefix(3))
        snapshot.generatedAt = .now
        WidgetStore.write(snapshot)
    }
}
