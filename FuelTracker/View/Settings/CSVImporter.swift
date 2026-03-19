import Foundation
import SwiftData

// MARK: - Résultat d'import

struct ImportResult {
    let success: Bool
    let title: String
    let message: String
}

// MARK: - Importeur CSV

enum CSVImporter {

    // MARK: - Import trajets

    static func importTrips(from url: URL, context: ModelContext, vehicle: Vehicle?) -> ImportResult {
        guard url.startAccessingSecurityScopedResource() else {
            return ImportResult(success: false, title: "Accès refusé", message: "Impossible d'accéder au fichier.")
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return ImportResult(success: false, title: "Erreur de lecture", message: "Le fichier ne peut pas être lu.")
        }

        let lines = raw.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else {
            return ImportResult(success: false, title: "Fichier vide", message: "Aucune donnée à importer.")
        }

        // Vérifie l'en-tête
        let header = lines[0].lowercased()
        guard header.contains("départ") || header.contains("depart") else {
            return ImportResult(success: false, title: "Format incorrect", message: "L'en-tête du fichier ne correspond pas au format attendu.\n\nTéléchargez le fichier exemple pour voir le format correct.")
        }

        // Récupère les trajets existants pour dédup
        let existing = (try? context.fetch(FetchDescriptor<Trip>())) ?? []
        let existingKeys = Set(existing.map { tripKey($0) })

        let formatter = dateFormatter()
        var imported = 0
        var skipped  = 0
        var errors   = 0

        for line in lines.dropFirst() {
            let cols = line.components(separatedBy: ";")
            guard cols.count >= 5 else { errors += 1; continue }

            guard
                let departure = formatter.date(from: cols[0].trimmingCharacters(in: .whitespaces)),
                let arrival   = formatter.date(from: cols[1].trimmingCharacters(in: .whitespaces)),
                let distance  = Double(cols[2].trimmingCharacters(in: .whitespaces)),
                let conso     = Double(cols[3].trimmingCharacters(in: .whitespaces)),
                let price     = Double(cols[4].trimmingCharacters(in: .whitespaces))
            else { errors += 1; continue }

            let toll = cols.count > 5 ? Double(cols[5].trimmingCharacters(in: .whitespaces)) : nil
            let note = cols.count > 6 ? cols[6].trimmingCharacters(in: .whitespaces) : nil

            let key = "\(departure.timeIntervalSince1970)-\(distance)-\(conso)"
            if existingKeys.contains(key) { skipped += 1; continue }

            let trip = Trip(
                departureDate:   departure,
                arrivalDate:     arrival,
                distanceKm:      distance,
                consumptionL100: conso,
                fuelPricePerL:   price,
                tollCost:        toll,
                note:            note.flatMap { $0.isEmpty ? nil : $0 },
                vehicle:         vehicle
            )
            context.insert(trip)
            imported += 1
        }

        try? context.save()
        return importResult(imported: imported, skipped: skipped, errors: errors, type: "trajet")
    }

    // MARK: - Import pleins

    static func importFillups(from url: URL, context: ModelContext, vehicle: Vehicle?) -> ImportResult {
        guard url.startAccessingSecurityScopedResource() else {
            return ImportResult(success: false, title: "Accès refusé", message: "Impossible d'accéder au fichier.")
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return ImportResult(success: false, title: "Erreur de lecture", message: "Le fichier ne peut pas être lu.")
        }

        let lines = raw.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else {
            return ImportResult(success: false, title: "Fichier vide", message: "Aucune donnée à importer.")
        }

        let header = lines[0].lowercased()
        guard header.contains("prix") && header.contains("volume") else {
            return ImportResult(success: false, title: "Format incorrect", message: "L'en-tête du fichier ne correspond pas au format attendu.\n\nTéléchargez le fichier exemple pour voir le format correct.")
        }

        let existing = (try? context.fetch(FetchDescriptor<FuelFillup>())) ?? []
        let existingKeys = Set(existing.map { fillupKey($0) })

        let formatter = dateFormatter()
        var imported = 0
        var skipped  = 0
        var errors   = 0

        for line in lines.dropFirst() {
            let cols = line.components(separatedBy: ";")
            guard cols.count >= 3 else { errors += 1; continue }

            guard
                let date  = formatter.date(from: cols[0].trimmingCharacters(in: .whitespaces)),
                let price = Double(cols[1].trimmingCharacters(in: .whitespaces)),
                let vol   = Double(cols[2].trimmingCharacters(in: .whitespaces))
            else { errors += 1; continue }

            let distance = cols.count > 3 ? Double(cols[3].trimmingCharacters(in: .whitespaces)) : nil
            let station  = cols.count > 4 ? cols[4].trimmingCharacters(in: .whitespaces) : nil
            let note     = cols.count > 5 ? cols[5].trimmingCharacters(in: .whitespaces) : nil

            let key = "\(date.timeIntervalSince1970)-\(price)-\(vol)"
            if existingKeys.contains(key) { skipped += 1; continue }

            let fillup = FuelFillup(
                date:              date,
                pricePerLiter:     price,
                volumeL:           vol,
                distanceUntilNext: distance,
                station:           station.flatMap { $0.isEmpty ? nil : $0 },
                note:              note.flatMap { $0.isEmpty ? nil : $0 },
                vehicle:           vehicle
            )
            context.insert(fillup)
            imported += 1
        }

        try? context.save()
        return importResult(imported: imported, skipped: skipped, errors: errors, type: "plein")
    }

    // MARK: - Helpers

    private static func dateFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy HH:mm"
        f.locale = Locale(identifier: "fr_FR")
        return f
    }

    private static func tripKey(_ trip: Trip) -> String {
        "\(trip.departureDate.timeIntervalSince1970)-\(trip.distanceKm)-\(trip.consumptionL100)"
    }

    private static func fillupKey(_ fillup: FuelFillup) -> String {
        "\(fillup.date.timeIntervalSince1970)-\(fillup.pricePerLiter)-\(fillup.volumeL)"
    }

    private static func importResult(imported: Int, skipped: Int, errors: Int, type: String) -> ImportResult {
        let success = imported > 0 || skipped > 0
        let title   = success ? "Import terminé" : "Aucune donnée importée"

        var parts: [String] = []
        if imported > 0 { parts.append("\(imported) \(type)\(imported > 1 ? "s" : "") importé\(imported > 1 ? "s" : "")") }
        if skipped  > 0 { parts.append("\(skipped) doublon\(skipped > 1 ? "s" : "") ignoré\(skipped > 1 ? "s" : "")") }
        if errors   > 0 { parts.append("\(errors) ligne\(errors > 1 ? "s" : "") ignorée\(errors > 1 ? "s" : "") (format invalide)") }
        if parts.isEmpty { parts.append("Aucune donnée valide trouvée dans le fichier.") }

        return ImportResult(success: success, title: title, message: parts.joined(separator: "\n"))
    }
}
