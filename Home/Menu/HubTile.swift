import SwiftUI

enum HubTile: Identifiable, Hashable {
    case destination(HubDestination)
    case settings

    static let all: [HubTile] = HubDestination.allCases.map(HubTile.destination) + [.settings]

    var id: String {
        switch self {
        case .destination(let dest): dest.id
        case .settings:              "settings"
        }
    }

    var title: String {
        switch self {
        case .destination(let dest): dest.title
        case .settings:              "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .destination(let dest): dest.systemImage
        case .settings:              "gearshape.fill"
        }
    }

    var fill: Color {
        switch self {
        case .destination(let dest): dest.fill
        case .settings:              Palette.surface
        }
    }
}
