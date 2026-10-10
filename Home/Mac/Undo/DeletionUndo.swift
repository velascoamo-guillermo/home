#if os(macOS)
import Foundation

/// Puts a deletion on the window's undo stack: Undo restores, Redo deletes again, and each
/// run registers its inverse so people can toggle as often as they like. The inverse is only
/// registered when the action actually succeeds — a failed restore must not leave a stale
/// "Redo" offered to the user.
enum DeletionUndo {
    typealias Action = @MainActor @Sendable () async -> Bool

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
            guard let manager else {
                let perform = perform
                Task { _ = await perform() }
                return
            }

            // Register the inverse synchronously, inside this handler's call stack: that is
            // the only window where `UndoManager` knows whether it is currently undoing or
            // redoing, and routes the registration to the opposite stack accordingly. Once we
            // `await`, that context is gone and the registration would land on the wrong stack.
            let wasGrouping = manager.groupingLevel > 0
            if !wasGrouping { manager.beginUndoGrouping() }
            let next = Step(manager: manager, actionName: actionName, perform: inverse, inverse: perform)
            manager.registerUndo(withTarget: next) { _ in
                MainActor.assumeIsolated { next.run() }
            }
            manager.setActionName(actionName)
            if !wasGrouping { manager.endUndoGrouping() }

            // If the action itself fails, pull the speculative registration back out so a
            // failed restore doesn't leave a stale "Redo" (or "Undo") offered to the user.
            let perform = perform
            Task {
                let succeeded = await perform()
                if !succeeded { manager.removeAllActions(withTarget: next) }
            }
        }
    }
}
#endif
