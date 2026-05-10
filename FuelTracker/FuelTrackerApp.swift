import SwiftUI
import SwiftData

@main
struct FuelTrackerApp: App {

    let container: ModelContainer

    init() {
        do {
            // SwiftData gère automatiquement l'ajout de nouveaux modèles
            // sans plan de migration explicite (lightweight migration)
            let schema = Schema([
                Vehicle.self,
                Trip.self,
                FuelFillup.self,
                Route.self
            ])
            let config = ModelConfiguration(schema: schema)
            container = try ModelContainer(for: schema, configurations: config)
            createDefaultVehicleIfNeeded()
        } catch {
            fatalError("Impossible de créer le ModelContainer : \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }

    // MARK: - Véhicule par défaut

    private func createDefaultVehicleIfNeeded() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Vehicle>()

        do {
            let existing = try context.fetch(descriptor)
            if existing.isEmpty {
                let defaultVehicle = Vehicle(name: "Mon véhicule", isDefault: true)
                context.insert(defaultVehicle)
                try context.save()
            }
        } catch {
            print("Erreur lors de la création du véhicule par défaut : \(error)")
        }
    }
}
