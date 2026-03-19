import Foundation

/// Persiste la date de départ entre les sessions via UserDefaults.
/// Utilisé par le widget et AddTripView.
final class TripDraftStore {

    static let shared = TripDraftStore()
    private init() {}

    private let key = "pendingDepartureDate"

    var pendingDepartureDate: Date? {
        get { UserDefaults.standard.object(forKey: key) as? Date }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
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
