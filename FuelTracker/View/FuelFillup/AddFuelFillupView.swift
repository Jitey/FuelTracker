import SwiftUI
import SwiftData

struct AddFuelFillupView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \FuelFillup.date, order: .reverse) private var fillups: [FuelFillup]
    @Query private var vehicles: [Vehicle]

    // MARK: - Champs

    @State private var date: Date = .now
    @State private var pricePerLiter: String = ""
    @State private var volumeL: String = ""
    @State private var distanceSinceLast: String = ""
    @State private var avgConsumption: String = ""
    @State private var station: String = ""
    @State private var note: String = ""

    // MARK: - UI State

    @State private var showValidationError = false

    // MARK: - Computed

    private var defaultVehicle: Vehicle? {
        vehicles.first(where: { $0.isDefault }) ?? vehicles.first
    }

    private var previewTotalPrice: Double? {
        guard let price = Double(pricePerLiter.replacingOccurrences(of: ",", with: ".")),
              let vol   = Double(volumeL.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return price * vol
    }

    private var isFormValid: Bool {
        Double(pricePerLiter.replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(volumeL.replacingOccurrences(of: ",", with: ".")) != nil &&
        !pricePerLiter.isEmpty &&
        !volumeL.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Date
                Section("Date") {
                    DatePicker("Date du plein", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }

                // MARK: Carburant
                Section("Carburant") {
                    HStack {
                        Text("Prix au litre")
                        Spacer()
                        TextField("0,000", text: $pricePerLiter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("€/L")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Volume")
                        Spacer()
                        TextField("0,00", text: $volumeL)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("L")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Depuis dernier plein (optionnel)
                Section {
                    HStack {
                        Text("Distance parcourue")
                        Spacer()
                        TextField("Inconnue", text: $distanceSinceLast)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        if !distanceSinceLast.isEmpty {
                            Text("km")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Conso moyenne")
                        Spacer()
                        TextField("Inconnue", text: $avgConsumption)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        if !avgConsumption.isEmpty {
                            Text("L/100")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Depuis le dernier plein")
                } footer: {
                    Text("Optionnel — à remplir si vous notez votre kilométrage.")
                }

                // MARK: Station (optionnelle)
                Section("Station") {
                    TextField("Nom de la station…", text: $station)
                }

                // MARK: Note (optionnelle)
                Section("Note") {
                    TextField("Ajouter une note…", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                }

                // MARK: Aperçu
                if let total = previewTotalPrice {
                    Section("Aperçu") {
                        HStack {
                            Text("Prix total du plein")
                            Spacer()
                            Text(total.formatted(.currency(code: "EUR")))
                                .foregroundStyle(.teal)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Nouveau plein")
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
                        saveFillup()
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
                Text("Le prix au litre et le volume sont obligatoires.")
            }
        }
    }

    // MARK: - Sauvegarde

    private func saveFillup() {
        let price    = Double(pricePerLiter.replacingOccurrences(of: ",", with: "."))!
        let vol      = Double(volumeL.replacingOccurrences(of: ",", with: "."))!
        let distance = Double(distanceSinceLast.replacingOccurrences(of: ",", with: "."))
        let conso    = Double(avgConsumption.replacingOccurrences(of: ",", with: "."))

        let fillup = FuelFillup(
            date:              date,
            pricePerLiter:     price,
            volumeL:           vol,
            distanceSinceLast: distance,
            avgConsumption:    conso,
            station:           station.isEmpty ? nil : station,
            note:              note.isEmpty ? nil : note,
            vehicle:           defaultVehicle
        )

        context.insert(fillup)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    AddFuelFillupView()
        .modelContainer(previewContainer)
}
