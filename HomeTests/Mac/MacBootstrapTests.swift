#if os(macOS)
import Testing
import Foundation
@testable import Casita

@MainActor final class BootstrapProbe {
    var loads = 0, observes = 0, refreshes = 0
    var now = Date(timeIntervalSince1970: 1_000)
}

@Suite("MacBootstrap") @MainActor struct MacBootstrapTests {

    private func make(_ probe: BootstrapProbe) -> MacBootstrap {
        MacBootstrap(
            load: { probe.loads += 1 },
            observe: { probe.observes += 1 },
            refresh: { probe.refreshes += 1 },
            now: { probe.now })
    }

    @Test("two windows starting the app load and observe once")
    func loadsOnce() async throws {
        let probe = BootstrapProbe()
        let bootstrap = make(probe)
        await bootstrap.start()
        await bootstrap.start()
        try await Task.sleep(for: .milliseconds(50))
        #expect(probe.loads == 1)
        #expect(probe.observes == 1)
        #expect(bootstrap.didFinishLoading)
    }

    @Test("windows starting concurrently while the first load is in flight load and observe once")
    func loadsOnceConcurrently() async throws {
        let probe = BootstrapProbe()
        let bootstrap = MacBootstrap(
            load: {
                probe.loads += 1
                try? await Task.sleep(for: .milliseconds(50))
            },
            observe: { probe.observes += 1 },
            refresh: { probe.refreshes += 1 },
            now: { probe.now })
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask { await bootstrap.start() }
            }
        }
        try await Task.sleep(for: .milliseconds(50))
        #expect(probe.loads == 1)
        #expect(probe.observes == 1)
        #expect(bootstrap.didFinishLoading)
    }

    @Test("activation before loading finished does not refresh")
    func noRefreshBeforeLoad() async {
        let probe = BootstrapProbe()
        await make(probe).appDidBecomeActive()
        #expect(probe.refreshes == 0)
    }

    @Test("activations from several windows within the debounce refresh once")
    func debounced() async {
        let probe = BootstrapProbe()
        let bootstrap = make(probe)
        await bootstrap.start()
        await bootstrap.appDidBecomeActive()
        probe.now = probe.now.addingTimeInterval(1)
        await bootstrap.appDidBecomeActive()
        #expect(probe.refreshes == 1)
        probe.now = probe.now.addingTimeInterval(MacBootstrap.activationDebounce)
        await bootstrap.appDidBecomeActive()
        #expect(probe.refreshes == 2)
    }
}
#endif
