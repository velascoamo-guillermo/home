#if os(macOS)
import Foundation

/// Puts a deletion on the window's undo stack: Undo restores, Redo deletes again, and each
/// run registers its inverse so people can toggle as often as they like.
enum DeletionUndo {
    typealias Action = @MainActor @Sendable () async -> Void

    static func register(on manager: UndoManager?, named actionName: String,
                         undo: @escaping Action, redo: @escaping Action) {
        guard let manager else { return }
        let step = Step(manager: manager, actionName: actionName, perform: undo, inverse: redo)
        // The handler may be typed @Sendable and nonisolated depending on the SDK; `step` is
        // main-actor isolated (so Sendable) and undo/redo only ever fire on the main thread.
        manager.registerUndo(withTarget: step) { _ in
            MainActor.assumeIsolated { step.run() }
        }
        manager.setActionName(actionName)
    }
}

extension DeletionUndo {
    @MainActor
    final class Step {
        private weak var manager: UndoManager?
        private let actionName: String
        private let perform: Action
        private let inverse: Action

        init(manager: UndoManager, actionName: String, perform: @escaping Action, inverse: @escaping Action) {
            self.manager = manager
            self.actionName = actionName
            self.perform = perform
            self.inverse = inverse
        }

        func run() {
            let wasGrouping = (manager?.groupingLevel ?? 0) > 0
            if !wasGrouping { manager?.beginUndoGrouping() }
            DeletionUndo.register(on: manager, named: actionName, undo: inverse, redo: perform)
            if !wasGrouping { manager?.endUndoGrouping() }
            let perform = perform
            Task { await perform() }
        }
    }
}
#endif
