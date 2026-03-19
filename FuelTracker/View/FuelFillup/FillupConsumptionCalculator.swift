import Foundation
import SwiftData

/// Recalcule la consommation moyenne de chaque plein.
///
/// Logique N / N+1 :
///   - La distance est associée au plein N (distance parcourue jusqu'au plein N+1)
///   - La conso de N = volumeL(N+1) / distanceUntilNext(N) × 100
///   - Le dernier plein n'a pas encore de suivant → avgConsumption = nil
///
/// À appeler après chaque insert ou update de FuelFillup.
enum FillupConsumptionCalculator {

    static func recalculate(context: ModelContext) {
        let descriptor = FetchDescriptor<FuelFillup>(
            sortBy: [SortDescriptor(\FuelFillup.date, order: .forward)]
        )
        guard let fillups = try? context.fetch(descriptor), fillups.count >= 2 else { return }

        for i in 0..<fillups.count - 1 {
            let current = fillups[i]
            let next    = fillups[i + 1]

            if let distance = current.distanceUntilNext, distance > 0 {
                current.avgConsumption = next.volumeL / distance * 100
            } else {
                current.avgConsumption = nil
            }
        }

        // Le dernier plein n'a pas encore de suivant
        fillups.last?.avgConsumption = nil

        try? context.save()
    }
}
