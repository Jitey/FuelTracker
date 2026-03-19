import SwiftUI
import SwiftData

struct SettingsView: View {

    @Query private var vehicles: [Vehicle]
    @Query(sort: \FuelFillup.date, order: .reverse) private var fillups: [FuelFillup]
    @Query(sort: \Trip.departureDate, order: .reverse) private var trips: [Trip]
    @Environment(\.modelContext) private var context

    @State private var vehicleName: String = ""
    @State private var defaultFuelPrice: String = ""
    @State private var showResetAlert = false
    @State private var showExportSheet = false
    @State private var exportURL: URL? = nil
    @State private var exportType: ExportType = .trips

    enum ExportType { case trips, fillups }

    private var defaultVehicle: Vehicle? {
        vehicles.first(where: { $0.isDefault }) ?? vehicles.first
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Véhicule
                Section("Véhicule") {
                    HStack {
                        Text("Nom")
                        Spacer()
                        TextField("Mon véhicule", text: $vehicleName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .onSubmit { saveVehicleName() }
                    }
                }

                // MARK: Carburant
                Section {
                    HStack {
                        Text("Prix par défaut")
                        Spacer()
                        TextField("0,000", text: $defaultFuelPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                        Text("€/L")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Carburant")
                } footer: {
                    Text("Utilisé uniquement si aucun plein n'est enregistré avant un trajet.")
                }

                // MARK: Export
                Section("Données") {
                    Button {
                        exportType = .trips
                        exportURL = generateCSV(type: .trips)
                        showExportSheet = true
                    } label: {
                        Label("Exporter les trajets", systemImage: "arrow.up.doc")
                    }

                    Button {
                        exportType = .fillups
                        exportURL = generateCSV(type: .fillups)
                        showExportSheet = true
                    } label: {
                        Label("Exporter les pleins", systemImage: "arrow.up.doc")
                    }
                }

                // MARK: Zone danger
                Section {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("Vider toutes les données", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Supprime définitivement tous les trajets et pleins enregistrés.")
                }

                // MARK: À propos
                Section("À propos") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Trajets enregistrés")
                        Spacer()
                        Text("\(trips.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Pleins enregistrés")
                        Spacer()
                        Text("\(fillups.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Réglages")
            .onAppear { loadSettings() }
            .onChange(of: vehicleName) { saveVehicleName() }
            .onChange(of: defaultFuelPrice) { saveDefaultFuelPrice() }
            .alert("Vider toutes les données ?", isPresented: $showResetAlert) {
                Button("Vider", role: .destructive) { resetAllData() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Cette action est irréversible. Tous vos trajets et pleins seront supprimés.")
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
        }
    }

    // MARK: - Chargement

    private func loadSettings() {
        vehicleName = defaultVehicle?.name ?? ""
        let savedPrice = UserDefaults.standard.double(forKey: "defaultFuelPrice")
        if savedPrice > 0 {
            defaultFuelPrice = String(format: "%.3f", savedPrice)
                .replacingOccurrences(of: ".", with: ",")
        }
    }

    // MARK: - Sauvegarde

    private func saveVehicleName() {
        guard let vehicle = defaultVehicle, !vehicleName.isEmpty else { return }
        vehicle.name = vehicleName
        try? context.save()
    }

    private func saveDefaultFuelPrice() {
        let price = Double(defaultFuelPrice.replacingOccurrences(of: ",", with: ".")) ?? 0
        UserDefaults.standard.set(price, forKey: "defaultFuelPrice")
    }

    // MARK: - Reset

    private func resetAllData() {
        trips.forEach   { context.delete($0) }
        fillups.forEach { context.delete($0) }
        try? context.save()
    }

    // MARK: - Export CSV

    private func generateCSV(type: ExportType) -> URL? {
        let content: String

        switch type {
        case .trips:
            var rows = ["Départ;Arrivée;Durée;Distance (km);Conso (L/100);Volume (L);Péage;Prix/L;Coût total;Note"]
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy HH:mm"
            formatter.locale = Locale(identifier: "fr_FR")

            for trip in trips {
                let toll = trip.tollCost.map { String(format: "%.2f €", $0) } ?? ""
                rows.append([
                    formatter.string(from: trip.departureDate),
                    formatter.string(from: trip.arrivalDate),
                    trip.durationFormatted,
                    String(format: "%.1f", trip.distanceKm),
                    String(format: "%.1f", trip.consumptionL100),
                    String(format: "%.2f", trip.volumeL),
                    toll,
                    String(format: "%.3f €", trip.fuelPricePerL),
                    String(format: "%.2f €", trip.totalCost),
                    trip.note ?? ""
                ].joined(separator: ";"))
            }
            content = rows.joined(separator: "\n")

        case .fillups:
            var rows = ["Date;Prix/L;Volume (L);Prix total;Distance depuis dernier;Conso moy.;Station;Note"]
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy HH:mm"
            formatter.locale = Locale(identifier: "fr_FR")

            for fillup in fillups {
                let distance = fillup.distanceSinceLast.map { String(format: "%.0f km", $0) } ?? ""
                let conso    = fillup.avgConsumption.map    { String(format: "%.1f L/100", $0) } ?? ""
                rows.append([
                    formatter.string(from: fillup.date),
                    String(format: "%.3f €", fillup.pricePerLiter),
                    String(format: "%.2f", fillup.volumeL),
                    String(format: "%.2f €", fillup.totalPrice),
                    distance,
                    conso,
                    fillup.station ?? "",
                    fillup.note ?? ""
                ].joined(separator: ";"))
            }
            content = rows.joined(separator: "\n")
        }

        let filename = type == .trips ? "trajets_export.csv" : "pleins_export.csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(previewContainer)
}
