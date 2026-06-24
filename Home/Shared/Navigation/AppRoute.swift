import Foundation

struct AppRoute: Equatable {
    var tab: AppTab
    var hubDestination: HubDestination?
}

enum AppRouter {
    static func route(host: String?) -> AppRoute {
        guard let tab = AppTab(host: host) else {
            return AppRoute(tab: .home, hubDestination: nil)
        }
        if let dest = HubDestination(appTab: tab) {
            return AppRoute(tab: .menu, hubDestination: dest)
        }
        return AppRoute(tab: tab, hubDestination: nil)
    }
}
