import Foundation
import SwiftData

@Model
final class Trip: Hashable {

    var id: UUID
    var departureDate: Date
    var arrivalDate: Date
    var distanceKm: Double
    var consumptionL100: Double
    var fuelPricePerL: Double
    var tollCost: Double?
    var note: String?
    var vehicle: Vehicle?

    // MARK: - Propriétés calculées (non persistées)

    /// Volume consommé en litres : distanceKm × consumptionL100 / 100
    var volumeL: Double {
        distanceKm * consumptionL100 / 100
    }

    /// Coût total : (volumeL × fuelPricePerL) + péage éventuel
    var totalCost: Double {
        (volumeL * fuelPricePerL) + (tollCost ?? 0)
    }

    /// Durée du trajet en minutes
    var durationMinutes: Int {
        Int(arrivalDate.timeIntervalSince(departureDate) / 60)
    }

    /// Coût par kilomètre
    var costPerKm: Double {
        guard distanceKm > 0 else { return 0 }
        return totalCost / distanceKm
    }

    /// Durée formatée pour l'affichage (ex: "1h 23min" ou "34min")
    var durationFormatted: String {
        let totalMins = durationMinutes
        let hours = totalMins / 60
        let mins = totalMins % 60
        if hours > 0 {
            return "\(hours)h \(mins)min"
        } else {
            return "\(mins)min"
        }
    }

    init(
        departureDate: Date,
        arrivalDate: Date,
        distanceKm: Double,
        consumptionL100: Double,
        fuelPricePerL: Double,
        tollCost: Double? = nil,
        note: String? = nil,
        vehicle: Vehicle? = nil
    ) {
        self.id = UUID()
        self.departureDate = departureDate
        self.arrivalDate = arrivalDate
        self.distanceKm = distanceKm
        self.consumptionL100 = consumptionL100
        self.fuelPricePerL = fuelPricePerL
        self.tollCost = tollCost
        self.note = note
        self.vehicle = vehicle
    }
}
