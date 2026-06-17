import Foundation
import Network
import Observation

@MainActor
@Observable
final class Reachability {
    private(set) var isOnline: Bool = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "reachability.monitor")

    /// Emits `true`/`false` on each connectivity change. First value is the current state.
    nonisolated let changes: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    init() {
        var cont: AsyncStream<Bool>.Continuation!
        changes = AsyncStream { cont = $0 }
        continuation = cont
        monitor.pathUpdateHandler = { [continuation, weak self] path in
            let online = path.status == .satisfied
            continuation.yield(online)
            Task { @MainActor [weak self] in
                self?.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel(); continuation.finish() }
}
