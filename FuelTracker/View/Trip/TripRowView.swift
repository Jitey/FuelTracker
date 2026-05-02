import SwiftUI
import SwiftData

struct TripRowView: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Ligne principale : date + coût
            HStack(alignment: .firstTextBaseline) {
                Text(trip.departureDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                Text(trip.totalCost.formatted(.currency(code: "EUR")))
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.teal)
            }

            // Ligne secondaire : durée + distance + badge péage
            HStack(spacing: 8) {
                Label(trip.durationFormatted, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Circle()
                    .fill(.secondary.opacity(0.4))
                    .frame(width: 3, height: 3)

                Label(trip.distanceKm.formatted(.number.precision(.fractionLength(1))) + " km",
                      systemImage: "arrow.triangle.swap")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let toll = trip.tollCost, toll > 0 {
                    Spacer()
                    Text("Péage \(toll.formatted(.currency(code: "EUR")))")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
                        .foregroundStyle(Color.orange)
                }
            }

            // Badge route (si assignée)
            if let route = trip.route {
                RouteBadge(route: route, isReturn: trip.isReturn, variant: trip.routeVariant)
            }

            // Note (si renseignée)
            if let note = trip.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }
}

// MARK: - Badge route

struct RouteBadge: View {
    let route: Route
    let isReturn: Bool
    var variant: String? = nil

    private var color: Color { Color(route.colorName) }

    var body: some View {
        HStack(spacing: 5) {
            // Flèche aller/retour
            Text(isReturn ? "↙" : "↗")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)

            // Libellé de la route
            Text(isReturn ? route.returnLabel : route.label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .lineLimit(1)

            // Variante (si présente)
            if let variant, !variant.isEmpty {
                Circle()
                    .fill(color.opacity(0.5))
                    .frame(width: 3, height: 3)
                Text(variant)
                    .font(.caption2)
                    .foregroundStyle(color.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(color.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("Sans péage") {
    TripRowView(trip: SampleData.sampleTrip)
        .padding()
        .modelContainer(previewContainer)
}

#Preview("Avec péage") {
    TripRowView(trip: SampleData.sampleTripWithToll)
        .padding()
        .modelContainer(previewContainer)
}
