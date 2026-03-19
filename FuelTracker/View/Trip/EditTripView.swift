import SwiftUI
import SwiftData
import WidgetKit

struct EditTripView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let trip: Trip

    // MARK: - Champs

    @State private var departureDate: Date
    @State private var arrivalDate: Date
    @State private var distanceKm: String
    @State private var consumptionL100: String
    @State private var fuelPricePerL: String
    @State private var tollCost: String
    @State private var note: String

    // MARK: - UI State

    @State private var showValidationError = false

    init(trip: Trip) {
        self.trip = trip
        _departureDate   = State(initialValue: trip.departureDate)
        _arrivalDate     = State(initialValue: trip.arrivalDate)
        _distanceKm      = State(initialValue: String(format: "%.1f", trip.distanceKm).replacingOccurrences(of: ".", with: ","))
        _consumptionL100 = State(initialValue: String(format: "%.1f", trip.consumptionL100).replacingOccurrences(of: ".", with: ","))
        _fuelPricePerL   = State(initialValue: String(format: "%.3f", trip.fuelPricePerL).replacingOccurrences(of: ".", with: ","))
        _tollCost        = State(initialValue: trip.tollCost.map { String(format: "%.2f", $0).replacingOccurrences(of: ".", with: ",") } ?? "")
        _note            = State(initialValue: trip.note ?? "")
    }

    // MARK: - Computed

    private var previewVolumeL: Double? {
        guard let d = Double(distanceKm.replacingOccurrences(of: ",", with: ".")),
              let c = Double(consumptionL100.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return d * c / 100
    }

    private var previewTotalCost: Double? {
        guard let vol   = previewVolumeL,
              let price = Double(fuelPricePerL.replacingOccurrences(of: ",", with: ".")) else { return nil }
        let toll = Double(tollCost.replacingOccurrences(of: ",", with: ".")) ?? 0
        return (vol * price) + toll
    }

    private var isFormValid: Bool {
        !distanceKm.isEmpty &&
        !consumptionL100.isEmpty &&
        !fuelPricePerL.isEmpty &&
        Double(distanceKm.replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(consumptionL100.replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(fuelPricePerL.replacingOccurrences(of: ",", with: ".")) != nil &&
        arrivalDate >= departureDate
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {

                Section("Horaires") {
                    DatePicker("Départ", selection: $departureDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .onChange(of: departureDate) {
                            if arrivalDate < departureDate { arrivalDate = departureDate }
                        }
                    DatePicker("Arrivée", selection: $arrivalDate, in: departureDate..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }

                Section("Trajet") {
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("0", text: $distanceKm)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("km")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Consommation")
                        Spacer()
                        TextField("0,0", text: $consumptionL100)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("L/100 km")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Carburant") {
                    HStack {
                        Text("Prix au litre")
                        Spacer()
                        TextField("0,000", text: $fuelPricePerL)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("€/L")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    HStack {
                        Text("Péage")
                        Spacer()
                        TextField("Aucun", text: $tollCost)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        if !tollCost.isEmpty {
                            Text("€")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Péage")
                } footer: {
                    Text("Optionnel — laissez vide si pas de péage.")
                }

                Section("Note") {
                    TextField("Ajouter une note…", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                }

                if let volume = previewVolumeL, let cost = previewTotalCost {
                    Section("Aperçu") {
                        HStack {
                            Text("Volume consommé")
                            Spacer()
                            Text(String(format: "%.2f L", volume))
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Coût total")
                            Spacer()
                            Text(cost.formatted(.currency(code: "EUR")))
                                .foregroundStyle(.teal)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Modifier le trajet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        guard isFormValid else {
                            showValidationError = true
                            return
                        }
                        saveTrip()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("OK") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                }
            }
            .alert("Formulaire incomplet", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Vérifiez que la distance, la consommation et le prix au litre sont bien renseignés.")
            }
        }
    }

    // MARK: - Sauvegarde

    private func saveTrip() {
        trip.departureDate   = departureDate
        trip.arrivalDate     = arrivalDate
        trip.distanceKm      = Double(distanceKm.replacingOccurrences(of: ",", with: "."))!
        trip.consumptionL100 = Double(consumptionL100.replacingOccurrences(of: ",", with: "."))!
        trip.fuelPricePerL   = Double(fuelPricePerL.replacingOccurrences(of: ",", with: "."))!
        trip.tollCost        = Double(tollCost.replacingOccurrences(of: ",", with: "."))
        trip.note            = note.isEmpty ? nil : note
        try? context.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    EditTripView(trip: SampleData.sampleTrip)
        .modelContainer(previewContainer)
}
