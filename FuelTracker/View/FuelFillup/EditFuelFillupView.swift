import SwiftUI
import SwiftData

struct EditFuelFillupView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let fillup: FuelFillup

    // MARK: - Champs

    @State private var date: Date
    @State private var pricePerLiter: String
    @State private var volumeL: String
    @State private var distanceUntilNext: String
    @State private var station: String
    @State private var note: String

    // MARK: - UI State

    @State private var showValidationError = false

    init(fillup: FuelFillup) {
        self.fillup = fillup
        _date            = State(initialValue: fillup.date)
        _pricePerLiter   = State(initialValue: String(format: "%.3f", fillup.pricePerLiter).replacingOccurrences(of: ".", with: ","))
        _volumeL         = State(initialValue: String(format: "%.2f", fillup.volumeL).replacingOccurrences(of: ".", with: ","))
        _distanceUntilNext = State(initialValue: fillup.distanceUntilNext.map { String(format: "%.0f", $0) } ?? "")
        _station         = State(initialValue: fillup.station ?? "")
        _note            = State(initialValue: fillup.note ?? "")
    }

    // MARK: - Computed

    private var previewTotalPrice: Double? {
        guard let price = Double(pricePerLiter.replacingOccurrences(of: ",", with: ".")),
              let vol   = Double(volumeL.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return price * vol
    }

    private var previewAvgConsumption: Double? {
        guard let vol      = Double(volumeL.replacingOccurrences(of: ",", with: ".")),
              let distance = Double(distanceUntilNext.replacingOccurrences(of: ",", with: ".")),
              distance > 0 else { return nil }
        return vol / distance * 100
    }

    private var isFormValid: Bool {
        Double(pricePerLiter.replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(volumeL.replacingOccurrences(of: ",", with: ".")) != nil &&
        !pricePerLiter.isEmpty && !volumeL.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {

                Section("Date") {
                    DatePicker("Date du plein", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }

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

                Section {
                    HStack {
                        Text("Distance parcourue")
                        Spacer()
                        TextField("Inconnue", text: $distanceUntilNext)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        if !distanceUntilNext.isEmpty {
                            Text("km")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Depuis le dernier plein")
                } footer: {
                    Text("Optionnel — à remplir au plein suivant.")
                }

                Section("Station") {
                    TextField("Nom de la station…", text: $station)
                }

                Section("Note") {
                    TextField("Ajouter une note…", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                }

                // Aperçu
                if let total = previewTotalPrice {
                    Section("Aperçu") {
                        HStack {
                            Text("Prix total")
                            Spacer()
                            Text(total.formatted(.currency(code: "EUR")))
                                .foregroundStyle(.teal)
                                .fontWeight(.semibold)
                        }
                        if let conso = previewAvgConsumption {
                            HStack {
                                Text("Conso moyenne")
                                Spacer()
                                Text(String(format: "%.1f L/100", conso))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Modifier le plein")
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
        fillup.date              = date
        fillup.pricePerLiter     = Double(pricePerLiter.replacingOccurrences(of: ",", with: "."))!
        fillup.volumeL           = Double(volumeL.replacingOccurrences(of: ",", with: "."))!
        fillup.distanceUntilNext = Double(distanceUntilNext.replacingOccurrences(of: ",", with: "."))
        fillup.station           = station.isEmpty ? nil : station
        fillup.note              = note.isEmpty ? nil : note
        FillupConsumptionCalculator.recalculate(context: context)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    EditFuelFillupView(fillup: SampleData.sampleFillup)
        .modelContainer(previewContainer)
}
