import Foundation

/// Persiste la date de départ entre les sessions via UserDefaults.
/// Utilisé par le widget et AddTripView.
final class TripDraftStore {

    static let shared = TripDraftStore()
    private init() {}

    private let key = "pendingDepartureDate"
    private let defaults = UserDefaults(suiteName: "group.com.jitey.fueltracker")!

    var pendingDepartureDate: Date? {
        get { defaults.object(forKey: key) as? Date }
        set {
            if let date = newValue {
                defaults.set(date, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }

    func markDeparture() {
        pendingDepartureDate = .now
    }

    func clear() {
        pendingDepartureDate = nil
    }
}
