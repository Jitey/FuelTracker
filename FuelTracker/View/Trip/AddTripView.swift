import SwiftUI
import SwiftData
import WidgetKit

struct AddTripView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var vehicles: [Vehicle]

    // MARK: - Champs du formulaire

    @State private var departureDate: Date = .now
    @State private var arrivalDate: Date = .now
    @State private var distanceKm: String = ""
    @State private var consumptionL100: String = ""
    @State private var fuelPricePerL: String = ""
    @State private var tollCost: String = ""
    @State private var note: String = ""

    // MARK: - Route

    @State private var selectedRoute: Route? = nil
    @State private var isReturn: Bool = false
    @State private var routeVariant: String = ""
    @State private var showRoutePicker = false

    // MARK: - UI State

    @State private var showValidationError = false

    // MARK: - Computed

    private var defaultVehicle: Vehicle? {
        vehicles.first(where: { $0.isDefault }) ?? vehicles.first
    }

    private func activeFillup(for date: Date) -> FuelFillup? {
        var descriptor = FetchDescriptor<FuelFillup>(
            predicate: #Predicate { $0.date <= date },
            sortBy: [SortDescriptor(\FuelFillup.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func applyFillupPrice(for date: Date) {
        guard fuelPricePerL.isEmpty else { return }
        if let fillup = activeFillup(for: date) {
            fuelPricePerL = String(format: "%.3f", fillup.pricePerLiter)
                .replacingOccurrences(of: ".", with: ",")
        } else {
            let defaultPrice = UserDefaults.standard.double(forKey: "defaultFuelPrice")
            if defaultPrice > 0 {
                fuelPricePerL = String(format: "%.3f", defaultPrice)
                    .replacingOccurrences(of: ".", with: ",")
            }
        }
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

    private var tripDuration: String? {
        let duration = arrivalDate.timeIntervalSince(departureDate)
        guard duration > 0 else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: duration)
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
                            if arrivalDate < departureDate { arrivalDate = departureDate }
                            fuelPricePerL = ""
                            applyFillupPrice(for: departureDate)
                        }
                    DatePicker("Arrivée", selection: $arrivalDate, in: departureDate..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }

                // MARK: Route récurrente
                Section {
                    Button {
                        showRoutePicker = true
                    } label: {
                        HStack {
                            if let route = selectedRoute {
                                RouteColorDot(colorName: route.colorName, size: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isReturn ? route.returnLabel : route.label)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text(isReturn ? "↙ Retour" : "↗ Aller")
                                        .font(.caption)
                                        .foregroundStyle(RouteColor.color(for: route.colorName))
                                }
                            } else {
                                Image(systemName: "arrow.triangle.swap")
                                    .foregroundStyle(.secondary)
                                Text("Aucune route")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // Variante (visible seulement si une route est sélectionnée)
                    if selectedRoute != nil {
                        HStack {
                            Text("Variante")
                            Spacer()
                            TextField("Ex: Autoroute, Nationale…", text: $routeVariant)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Route récurrente")
                } footer: {
                    Text("Optionnel — pour regrouper vos trajets habituels.")
                }

                // MARK: Trajet
                Section("Trajet") {
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("0", text: $distanceKm)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("km").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Consommation")
                        Spacer()
                        TextField("0,0", text: $consumptionL100)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("L/100 km").foregroundStyle(.secondary)
                    }
                }

                Section {
                    HStack {
                        Text("Prix au litre")
                        Spacer()
                        TextField("0,000", text: $fuelPricePerL)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("€/L").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Carburant")
                } footer: {
                    if let fillup = activeFillup(for: departureDate) {
                        Text("Prix depuis le plein du \(fillup.date.formatted(.dateTime.day().month(.abbreviated)))")
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
                            Text("€").foregroundStyle(.secondary)
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

                Section("Aperçu") {
                    HStack {
                        Text("Durée du trajet")
                        Spacer()
                        if let duration = tripDuration {
                            Text(duration).foregroundStyle(.secondary)
                        }
                    }
                    if let volume = previewVolumeL, let cost = previewTotalCost {
                        HStack {
                            Text("Volume consommé")
                            Spacer()
                            Text(String(format: "%.2f L", volume)).foregroundStyle(.secondary)
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
                        guard isFormValid else { showValidationError = true; return }
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
            .sheet(isPresented: $showRoutePicker) {
                RoutePickerView(selectedRoute: $selectedRoute, isReturn: $isReturn)
            }
        }
        .onAppear {
            if let pending = TripDraftStore.shared.pendingDepartureDate {
                departureDate = pending
                if arrivalDate < departureDate { arrivalDate = departureDate }
            }
            applyFillupPrice(for: departureDate)
        }
    }

    // MARK: - Sauvegarde

    private func saveTrip() {
        let distance = Double(distanceKm.replacingOccurrences(of: ",", with: "."))!
        let conso    = Double(consumptionL100.replacingOccurrences(of: ",", with: "."))!
        let price    = Double(fuelPricePerL.replacingOccurrences(of: ",", with: "."))!
        let toll     = Double(tollCost.replacingOccurrences(of: ",", with: "."))

        let trip = Trip(
            departureDate:   departureDate,
            arrivalDate:     arrivalDate,
            distanceKm:      distance,
            consumptionL100: conso,
            fuelPricePerL:   price,
            tollCost:        toll,
            note:            note.isEmpty ? nil : note,
            vehicle:         defaultVehicle,
            route:           selectedRoute,
            isReturn:        isReturn,
            routeVariant:    routeVariant.isEmpty ? nil : routeVariant
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
