import SwiftUI
import SwiftData

struct TripDetailView: View {
    let trip: Trip
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Hero : coût total
                VStack(spacing: 4) {
                    Text(trip.totalCost.formatted(.currency(code: "EUR")))
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .foregroundStyle(.teal)
                    Text("Coût total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))

                // Infos principales
                InfoSection(title: "Trajet") {
                    InfoRow(label: "Départ",
                            value: trip.departureDate.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                    InfoRow(label: "Arrivée",
                            value: trip.arrivalDate.formatted(.dateTime.hour().minute()))
                    InfoRow(label: "Durée",
                            value: trip.durationFormatted)
                    InfoRow(label: "Distance",
                            value: trip.distanceKm.formatted(.number.precision(.fractionLength(1))) + " km")
                }

                // Carburant
                InfoSection(title: "Carburant") {
                    InfoRow(label: "Consommation",
                            value: trip.consumptionL100.formatted(.number.precision(.fractionLength(1))) + " L/100 km")
                    InfoRow(label: "Volume consommé",
                            value: trip.volumeL.formatted(.number.precision(.fractionLength(2))) + " L")
                    InfoRow(label: "Prix au litre",
                            value: trip.fuelPricePerL.formatted(.currency(code: "EUR")))
                }

                // Coûts
                InfoSection(title: "Coûts") {
                    InfoRow(label: "Coût carburant",
                            value: (trip.volumeL * trip.fuelPricePerL).formatted(.currency(code: "EUR")))
                    if let toll = trip.tollCost, toll > 0 {
                        InfoRow(label: "Péage",
                                value: toll.formatted(.currency(code: "EUR")))
                    }
                    InfoRow(label: "Coût / km",
                            value: trip.costPerKm.formatted(.currency(code: "EUR")) + "/km",
                            isHighlighted: true)
                }

                // Note
                if let note = trip.note, !note.isEmpty {
                    InfoSection(title: "Note") {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                }

                // Supprimer
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Supprimer ce trajet", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }
            .padding(16)
        }
        .navigationTitle(trip.departureDate.formatted(.dateTime.day().month(.abbreviated).year()))
        .navigationBarTitleDisplayMode(.inline)
        .alert("Supprimer ce trajet ?", isPresented: $showDeleteAlert) {
            Button("Supprimer", role: .destructive) {
                context.delete(trip)
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action est irréversible.")
        }
    }
}

// MARK: - Composants réutilisables

struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.4)
                .padding(.bottom, 8)
                .padding(.horizontal, 14)

            VStack(spacing: 0) {
                content
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var isHighlighted: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(isHighlighted ? .semibold : .regular)
                .foregroundStyle(isHighlighted ? .teal : .primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 14)
        }
    }
}

// MARK: - Previews

#Preview("Sans péage") {
    NavigationStack {
        TripDetailView(trip: SampleData.sampleTrip)
    }
    .modelContainer(previewContainer)
}

#Preview("Avec péage et note") {
    NavigationStack {
        TripDetailView(trip: SampleData.sampleTripWithToll)
    }
    .modelContainer(previewContainer)
}
