import Testing
@testable import Home

@Suite("AppRouter") @MainActor struct AppRouteTests {

    @Test("section hosts select the Menu hub and push the section")
    func sections() {
        #expect(AppRouter.route(host: "meals") == AppRoute(tab: .menu, hubDestination: .meals))
        #expect(AppRouter.route(host: "pets") == AppRoute(tab: .menu, hubDestination: .pets))
        #expect(AppRouter.route(host: "stock") == AppRoute(tab: .menu, hubDestination: .stock))
        #expect(AppRouter.route(host: "shopping") == AppRoute(tab: .menu, hubDestination: .shopping))
    }

    @Test("top-level hosts select their tab with no push")
    func topLevel() {
        #expect(AppRouter.route(host: "home") == AppRoute(tab: .home, hubDestination: nil))
        #expect(AppRouter.route(host: "search") == AppRoute(tab: .search, hubDestination: nil))
        #expect(AppRouter.route(host: "menu") == AppRoute(tab: .menu, hubDestination: nil))
    }

    @Test("unknown host falls back to home")
    func unknown() {
        #expect(AppRouter.route(host: nil) == AppRoute(tab: .home, hubDestination: nil))
        #expect(AppRouter.route(host: "zzz") == AppRoute(tab: .home, hubDestination: nil))
    }
}
