import Foundation
import SwiftData

@Model
final class FuelFillup: Hashable {

    var id: UUID
    var date: Date
    var pricePerLiter: Double
    var volumeL: Double

    // Renommé distanceSinceLast → distanceUntilNext
    // @Attribute assure la migration depuis l'ancien nom
    @Attribute(originalName: "distanceSinceLast")
    var distanceUntilNext: Double?

    // Stockée — calculée via recalculateConsumption()
    var avgConsumption: Double?

    var station: String?
    var note: String?
    var vehicle: Vehicle?

    // MARK: - Propriétés calculées (non persistées)

    /// Prix total du plein : pricePerLiter × volumeL
    var totalPrice: Double {
        pricePerLiter * volumeL
    }

    /// Coût par kilomètre jusqu'au prochain plein
    var costPerKm: Double? {
        guard let distance = distanceUntilNext, distance > 0 else { return nil }
        return totalPrice / distance
    }

    init(
        date: Date,
        pricePerLiter: Double,
        volumeL: Double,
        distanceUntilNext: Double? = nil,
        station: String? = nil,
        note: String? = nil,
        vehicle: Vehicle? = nil
    ) {
        self.id               = UUID()
        self.date             = date
        self.pricePerLiter    = pricePerLiter
        self.volumeL          = volumeL
        self.distanceUntilNext = distanceUntilNext
        self.station          = station
        self.note             = note
        self.vehicle          = vehicle
    }
}
