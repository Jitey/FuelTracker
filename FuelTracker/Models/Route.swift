import Foundation
import SwiftUI
import SwiftData

// MARK: - Couleurs disponibles pour les routes

enum RouteColor: String, CaseIterable, Codable {
    case teal    = "teal"
    case blue    = "blue"
    case indigo  = "indigo"
    case purple  = "purple"
    case pink    = "pink"
    case red     = "red"
    case orange  = "orange"
    case yellow  = "yellow"
    case green   = "green"
    case mint    = "mint"

    var displayName: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .teal:   return .teal
        case .blue:   return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink:   return .pink
        case .red:    return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green:  return .green
        case .mint:   return .mint
        }
    }

    /// Résout un colorName stocké en base → Color SwiftUI
    static func color(for name: String) -> Color {
        RouteColor(rawValue: name)?.color ?? .teal
    }
}

// MARK: - Modèle Route

/// Représente un trajet récurrent entre deux points (ex: Maison → Bureau).
/// Un même trajet peut être fait en aller ou en retour (géré via `Trip.isReturn`).
@Model
final class Route {

    var id: UUID
    var origin: String
    var destination: String
    var colorName: String         // Stocké comme String pour SwiftData
    var createdAt: Date

    // Relation inverse — SwiftData gère automatiquement
    @Relationship(deleteRule: .nullify, inverse: \Trip.route)
    var trips: [Trip] = []

    // MARK: - Computed

    /// Libellé court : "Origine → Destination"
    var label: String {
        "\(origin) → \(destination)"
    }

    /// Libellé retour : "Destination → Origine"
    var returnLabel: String {
        "\(destination) → \(origin)"
    }

    /// Nombre de trajets aller
    var outboundCount: Int {
        trips.filter { !$0.isReturn }.count
    }

    /// Nombre de trajets retour
    var returnCount: Int {
        trips.filter { $0.isReturn }.count
    }

    init(
        origin: String,
        destination: String,
        colorName: String = RouteColor.teal.rawValue
    ) {
        self.id          = UUID()
        self.origin      = origin
        self.destination = destination
        self.colorName   = colorName
        self.createdAt   = .now
    }
}
