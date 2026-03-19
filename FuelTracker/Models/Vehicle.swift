import Foundation
import SwiftData

@Model
final class Vehicle {

    var id: UUID
    var name: String
    var isDefault: Bool

    // Relations inverses — SwiftData les gère automatiquement
    @Relationship(deleteRule: .nullify, inverse: \Trip.vehicle)
    var trips: [Trip] = []

    @Relationship(deleteRule: .nullify, inverse: \FuelFillup.vehicle)
    var fillups: [FuelFillup] = []

    init(name: String, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.isDefault = isDefault
    }
}
