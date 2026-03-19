import SwiftUI
import SwiftData

struct FuelFillupDetailView: View {
    let fillup: FuelFillup
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Hero : prix total
                VStack(spacing: 4) {
                    Text(fillup.totalPrice.formatted(.currency(code: "EUR")))
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .foregroundStyle(.teal)
                    Text("Prix du plein")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))

                // Infos plein
                InfoSection(title: "Plein") {
                    InfoRow(label: "Date",
                            value: fillup.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute()))
                    InfoRow(label: "Volume",
                            value: String(format: "%.2f L", fillup.volumeL))
                    InfoRow(label: "Prix au litre",
                            value: fillup.pricePerLiter.formatted(.currency(code: "EUR")) + "/L")
                    if let station = fillup.station, !station.isEmpty {
                        InfoRow(label: "Station", value: station)
                    }
                }

                // Jusqu'au prochain plein
                if fillup.distanceUntilNext != nil || fillup.avgConsumption != nil {
                    InfoSection(title: "Depuis le dernier plein") {
                        if let distance = fillup.distanceUntilNext {
                            InfoRow(label: "Distance parcourue",
                                    value: String(format: "%.0f km", distance))
                        }
                        if let conso = fillup.avgConsumption {
                            InfoRow(label: "Consommation moyenne",
                                    value: String(format: "%.1f L/100 km", conso))
                        }
                        if let costPerKm = fillup.costPerKm {
                            InfoRow(label: "Coût / km",
                                    value: String(format: "%.3f €/km", costPerKm),
                                    isHighlighted: true)
                        }
                    }
                }

                // Note
                if let note = fillup.note, !note.isEmpty {
                    InfoSection(title: "Note") {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                }

                // Actions
                Button {
                    showEdit = true
                } label: {
                    Label("Modifier ce plein", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Supprimer ce plein", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            .padding(16)
        }
        .navigationTitle(fillup.date.formatted(.dateTime.day().month(.abbreviated).year()))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEdit) {
            EditFuelFillupView(fillup: fillup)
        }
        .alert("Supprimer ce plein ?", isPresented: $showDeleteAlert) {
            Button("Supprimer", role: .destructive) {
                context.delete(fillup)
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action est irréversible.")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FuelFillupDetailView(fillup: SampleData.sampleFillup)
    }
    .modelContainer(previewContainer)
}
