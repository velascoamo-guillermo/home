import EventKit

nonisolated enum CalendarAccessState: Equatable, Sendable {
    case notDetermined, fullAccess, denied, restricted

    init(_ status: EKAuthorizationStatus) {
        switch status {
        case .fullAccess:                self = .fullAccess
        case .notDetermined, .writeOnly: self = .notDetermined
        case .denied:                    self = .denied
        case .restricted:                self = .restricted
        @unknown default:                self = .denied
        }
    }
}
