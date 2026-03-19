import Foundation
import SwiftData

@Model
final class FuelFillup {

    var id: UUID
    var date: Date
    var pricePerLiter: Double
    var volumeL: Double
    var distanceSinceLast: Double?
    var avgConsumption: Double?
    var station: String?
    var note: String?
    var vehicle: Vehicle?

    // MARK: - Propriétés calculées (non persistées)

    /// Prix total du plein : pricePerLiter × volumeL
    var totalPrice: Double {
        pricePerLiter * volumeL
    }

    /// Coût par kilomètre depuis le dernier plein
    var costPerKm: Double? {
        guard let distance = distanceSinceLast, distance > 0 else { return nil }
        return totalPrice / distance
    }

    init(
        date: Date,
        pricePerLiter: Double,
        volumeL: Double,
        distanceSinceLast: Double? = nil,
        avgConsumption: Double? = nil,
        station: String? = nil,
        note: String? = nil,
        vehicle: Vehicle? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.pricePerLiter = pricePerLiter
        self.volumeL = volumeL
        self.distanceSinceLast = distanceSinceLast
        self.avgConsumption = avgConsumption
        self.station = station
        self.note = note
        self.vehicle = vehicle
    }
}
