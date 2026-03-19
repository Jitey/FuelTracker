import SwiftUI
import SwiftData
import WidgetKit

struct AddTripView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Récupère le véhicule par défaut
    @Query private var vehicles: [Vehicle]

    // MARK: - Champs du formulaire

    @State private var departureDate: Date = .now
    @State private var arrivalDate: Date = .now
    @State private var distanceKm: String = ""
    @State private var consumptionL100: String = ""
    @State private var fuelPricePerL: String = ""
    @State private var tollCost: String = ""
    @State private var note: String = ""

    // MARK: - UI State

    @State private var showValidationError = false

    // MARK: - Computed

    private var defaultVehicle: Vehicle? {
        vehicles.first(where: { $0.isDefault }) ?? vehicles.first
    }

    /// Lookup RECHERCHEV-style : plein le plus récent antérieur à la date du trajet
    private func activeFillup(for date: Date) -> FuelFillup? {
        var descriptor = FetchDescriptor<FuelFillup>(
            predicate: #Predicate { $0.date <= date },
            sortBy: [SortDescriptor(\FuelFillup.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func applyFillupPrice(for date: Date) {
        guard fuelPricePerL.isEmpty, let fillup = activeFillup(for: date) else { return }
        fuelPricePerL = String(format: "%.3f", fillup.pricePerLiter)
            .replacingOccurrences(of: ".", with: ",")
    }

    private var previewVolumeL: Double? {
        guard let d = Double(distanceKm.replacingOccurrences(of: ",", with: ".")),
              let c = Double(consumptionL100.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return d * c / 100
    }

    private var previewTotalCost: Double? {
        guard let vol = previewVolumeL,
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

                // MARK: Dates
                Section("Horaires") {
                    DatePicker("Départ", selection: $departureDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .onChange(of: departureDate) {
                            if arrivalDate < departureDate {
                                arrivalDate = departureDate
                            }
                            // Recalcule le bon plein si la date change
                            fuelPricePerL = ""
                            applyFillupPrice(for: departureDate)
                        }

                    DatePicker("Arrivée", selection: $arrivalDate, in: departureDate..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }

                // MARK: Trajet
                Section("Trajet") {
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("0", text: $distanceKm)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(distanceKm.isEmpty ? .secondary : .primary)
                        Text("km")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Consommation")
                        Spacer()
                        TextField("0,0", text: $consumptionL100)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(consumptionL100.isEmpty ? .secondary : .primary)
                        Text("L/100 km")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    HStack {
                        Text("Prix au litre")
                        Spacer()
                        TextField("0,000", text: $fuelPricePerL)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(fuelPricePerL.isEmpty ? .secondary : .primary)
                        Text("€/L")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Carburant")
                } footer: {
                    if let fillup = activeFillup(for: departureDate) {
                        Text("Prix depuis le plein du \(fillup.date.formatted(.dateTime.day().month(.abbreviated)))")
                    }
                }

                // MARK: Péage (optionnel)
                Section {
                    HStack {
                        Text("Péage")
                        Spacer()
                        TextField("Aucun", text: $tollCost)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(tollCost.isEmpty ? .secondary : .primary)
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

                // MARK: Note (optionnelle)
                Section("Note") {
                    TextField("Ajouter une note…", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                }

                // MARK: Aperçu calculé
                if let volume = previewVolumeL, let cost = previewTotalCost {
                    Section("Aperçu") {
                        HStack {
                            Text("Volume consommé")
                            Spacer()
                            Text(String(format: "%.2f L", volume))
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Coût total estimé")
                            Spacer()
                            Text(cost.formatted(.currency(code: "EUR")))
                                .foregroundStyle(.teal)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Nouveau trajet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
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
                Text("Vérifiez que la distance, la consommation et le prix au litre sont bien renseignés, et que l'heure d'arrivée est après le départ.")
            }
        }
        .onAppear {
            // Récupère la date de départ depuis le widget si disponible
            if let pending = TripDraftStore.shared.pendingDepartureDate {
                departureDate = pending
                if arrivalDate < departureDate {
                    arrivalDate = departureDate
                }
            }
            applyFillupPrice(for: departureDate)
        }    }

    // MARK: - Sauvegarde

    private func saveTrip() {
        let distance = Double(distanceKm.replacingOccurrences(of: ",", with: "."))!
        let conso    = Double(consumptionL100.replacingOccurrences(of: ",", with: "."))!
        let price    = Double(fuelPricePerL.replacingOccurrences(of: ",", with: "."))!
        let toll     = Double(tollCost.replacingOccurrences(of: ",", with: "."))

        let trip = Trip(
            departureDate:    departureDate,
            arrivalDate:      arrivalDate,
            distanceKm:       distance,
            consumptionL100:  conso,
            fuelPricePerL:    price,
            tollCost:         toll,
            note:             note.isEmpty ? nil : note,
            vehicle:          defaultVehicle
        )

        context.insert(trip)
        TripDraftStore.shared.clear()
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    AddTripView()
        .modelContainer(previewContainer)
}
