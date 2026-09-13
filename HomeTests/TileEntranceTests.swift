import Testing
@testable import Casita

@Suite("Tile entrance") @MainActor struct TileEntranceTests {

    @Test("first tile starts immediately")
    func firstTileHasNoDelay() {
        #expect(Tile.entranceDelay(forIndex: 0) == 0)
    }

    @Test("later tiles start strictly after earlier ones")
    func staggersInOrder() {
        let delays = HubTile.all.indices.map(Tile.entranceDelay(forIndex:))
        #expect(zip(delays, delays.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("stagger is capped so a long grid doesn't lag")
    func delayIsCapped() {
        #expect(Tile.entranceDelay(forIndex: 100) == Tile.entranceDelay(forIndex: Tile.maxStaggeredIndex))
        #expect(Tile.entranceDelay(forIndex: 100) <= 0.5)
    }
}
