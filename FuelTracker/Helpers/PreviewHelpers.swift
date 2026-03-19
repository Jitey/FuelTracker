import SwiftUI
import SwiftData

// MARK: - Container en mémoire pour les previews

@MainActor
let previewContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Vehicle.self, Trip.self, FuelFillup.self,
        configurations: config
    )
    SampleData.insert(into: container.mainContext)
    return container
}()

// MARK: - Données fictives

enum SampleData {

    @MainActor
    static func insert(into context: ModelContext) {
        let vehicle = Vehicle(name: "Nissan Juke", isDefault: true)
        context.insert(vehicle)

        let trips = [
            Trip(
                departureDate: date("15/03/2026 17:42"),
                arrivalDate:   date("15/03/2026 21:00"),
                distanceKm: 325.4,
                consumptionL100: 6.2,
                fuelPricePerL: 2.00,
                tollCost: 4.80,
                note: "Retour de week-end",
                vehicle: vehicle
            ),
            Trip(
                departureDate: date("15/03/2026 16:24"),
                arrivalDate:   date("15/03/2026 17:37"),
                distanceKm: 102.0,
                consumptionL100: 4.9,
                fuelPricePerL: 2.00,
                vehicle: vehicle
            ),
            Trip(
                departureDate: date("13/03/2026 17:18"),
                arrivalDate:   date("13/03/2026 18:14"),
                distanceKm: 157.1,
                consumptionL100: 6.2,
                fuelPricePerL: 2.01,
                vehicle: vehicle
            ),
            Trip(
                departureDate: date("13/03/2026 12:31"),
                arrivalDate:   date("13/03/2026 16:28"),
                distanceKm: 310.0,
                consumptionL100: 6.2,
                fuelPricePerL: 2.01,
                tollCost: 17.00,
                note: "Trajet autoroute A1",
                vehicle: vehicle
            ),
            Trip(
                departureDate: date("02/02/2026 08:03"),
                arrivalDate:   date("02/02/2026 08:27"),
                distanceKm: 25.8,
                consumptionL100: 6.2,
                fuelPricePerL: 1.66,
                vehicle: vehicle
            ),
            Trip(
                departureDate: date("04/02/2026 16:36"),
                arrivalDate:   date("04/02/2026 17:00"),
                distanceKm: 22.4,
                consumptionL100: 5.2,
                fuelPricePerL: 1.66,
                tollCost: 1.00,
                vehicle: vehicle
            ),
            Trip(
                departureDate: date("13/01/2026 12:31"),
                arrivalDate:   date("13/01/2026 16:28"),
                distanceKm: 310.0,
                consumptionL100: 6.2,
                fuelPricePerL: 2.01,
                tollCost: 17.00,
                note: "Trajet autoroute A1",
                vehicle: vehicle
            ),
            Trip(
                departureDate: date("02/01/2026 08:03"),
                arrivalDate:   date("02/01/2026 08:27"),
                distanceKm: 25.8,
                consumptionL100: 6.2,
                fuelPricePerL: 1.66,
                vehicle: vehicle
            ),
            Trip(
                departureDate: date("04/12/2025 16:36"),
                arrivalDate:   date("04/12/2025 17:00"),
                distanceKm: 22.4,
                consumptionL100: 5.2,
                fuelPricePerL: 1.66,
                tollCost: 1.00,
                vehicle: vehicle
            ),
        ]

        trips.forEach { context.insert($0) }

        let fillups = [
            FuelFillup(
                date: date("15/03/2026 12:00"),
                pricePerLiter: 1.999,
                volumeL: 30.21,
                distanceSinceLast: nil,
                avgConsumption: nil,
                station: "Total Énergies A1",
                vehicle: vehicle
            ),
            FuelFillup(
                date: date("13/03/2026 10:00"),
                pricePerLiter: 2.010,
                volumeL: 27.12,
                distanceSinceLast: 472,
                avgConsumption: 6.4,
                station: "Intermarché Breteuil",
                vehicle: vehicle
            ),
        ]

        fillups.forEach { context.insert($0) }

        try? context.save()
    }

    // MARK: - Accesseurs pratiques

    @MainActor
    static var sampleTrip: Trip {
        let context = previewContainer.mainContext
        let trips = try! context.fetch(FetchDescriptor<Trip>(
            sortBy: [SortDescriptor(\Trip.departureDate, order: .reverse)]
        ))
        return trips.first!
    }

    @MainActor
    static var sampleTripWithToll: Trip {
        let context = previewContainer.mainContext
        let trips = try! context.fetch(FetchDescriptor<Trip>(
            sortBy: [SortDescriptor(\Trip.departureDate, order: .reverse)]
        ))
        return trips.first(where: { $0.tollCost != nil })!
    }

    @MainActor
    static var sampleFillup: FuelFillup {
        let context = previewContainer.mainContext
        let fillups = try! context.fetch(FetchDescriptor<FuelFillup>(
            sortBy: [SortDescriptor(\FuelFillup.date, order: .reverse)]
        ))
        return fillups.first!
    }

    // MARK: - Helper date

    private static func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.date(from: string) ?? .now
    }
}
