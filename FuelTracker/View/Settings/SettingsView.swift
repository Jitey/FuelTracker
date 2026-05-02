import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {

    @Query private var vehicles: [Vehicle]
    @Query private var routes: [Route]
    @Query(sort: \FuelFillup.date, order: .reverse) private var fillups: [FuelFillup]
    @Query(sort: \Trip.departureDate, order: .reverse) private var trips: [Trip]
    @Environment(\.modelContext) private var context

    @State private var vehicleName: String = ""
    @State private var defaultFuelPrice: String = ""
    @State private var showResetAlert = false
    @State private var showExportSheet = false
    @State private var exportURL: URL? = nil
    @State private var exportType: ExportType = .trips
    @State private var showImport = false
    @State private var importType: ExportType = .trips
    @State private var importResult: ImportResult? = nil

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

                // MARK: Routes récurrentes
                Section {
                    NavigationLink(destination: RouteManagerView()) {
                        HStack {
                            Label("Mes routes", systemImage: "arrow.triangle.swap")
                            Spacer()
                            Text("\(routes.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Routes récurrentes")
                } footer: {
                    Text("Regroupez vos trajets habituels par paire départ/arrivée.")
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

                // MARK: Export / Import
                Section("Trajets") {
                    Button {
                        exportType = .trips
                        exportURL = generateCSV(type: .trips)
                        showExportSheet = true
                    } label: {
                        Label("Exporter", systemImage: "arrow.up.doc")
                    }
                    Button {
                        importType = .trips
                        showImport = true
                    } label: {
                        Label("Importer", systemImage: "arrow.down.doc")
                    }
                    Button {
                        exportURL = SettingsView.sampleCSV(type: .trips)
                        showExportSheet = true
                    } label: {
                        Label("Télécharger le fichier exemple", systemImage: "doc.badge.plus")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Pleins") {
                    Button {
                        exportType = .fillups
                        exportURL = generateCSV(type: .fillups)
                        showExportSheet = true
                    } label: {
                        Label("Exporter", systemImage: "arrow.up.doc")
                    }
                    Button {
                        importType = .fillups
                        showImport = true
                    } label: {
                        Label("Importer", systemImage: "arrow.down.doc")
                    }
                    Button {
                        exportURL = SettingsView.sampleCSV(type: .fillups)
                        showExportSheet = true
                    } label: {
                        Label("Télécharger le fichier exemple", systemImage: "doc.badge.plus")
                            .foregroundStyle(.secondary)
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
            .fileImporter(
                isPresented: $showImport,
                allowedContentTypes: [.commaSeparatedText, .text],
                allowsMultipleSelection: false
            ) { result in
                guard let url = try? result.get().first else { return }
                switch importType {
                case .trips:
                    importResult = CSVImporter.importTrips(from: url, context: context, vehicle: defaultVehicle)
                case .fillups:
                    importResult = CSVImporter.importFillups(from: url, context: context, vehicle: defaultVehicle)
                    if importResult?.success == true {
                        FillupConsumptionCalculator.recalculate(context: context)
                    }
                }
            }
            .alert(importResult?.title ?? "", isPresented: .init(
                get: { importResult != nil },
                set: { if !$0 { importResult = nil } }
            )) {
                Button("OK", role: .cancel) { importResult = nil }
            } message: {
                Text(importResult?.message ?? "")
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
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        formatter.locale = Locale(identifier: "fr_FR")
        let csvContent: String

        switch type {
        case .trips:
            var rows = ["Départ;Arrivée;Distance;Conso;Prix/L;Péage;Note"]
            for trip in trips.sorted(by: { $0.departureDate < $1.departureDate }) {
                rows.append([
                    formatter.string(from: trip.departureDate),
                    formatter.string(from: trip.arrivalDate),
                    String(format: "%.1f", trip.distanceKm),
                    String(format: "%.1f", trip.consumptionL100),
                    String(format: "%.3f", trip.fuelPricePerL),
                    trip.tollCost.map { String(format: "%.2f", $0) } ?? "",
                    trip.note ?? ""
                ].joined(separator: ";"))
            }
            csvContent = rows.joined(separator: "\n")

        case .fillups:
            var rows = ["Date;Prix/L;Volume;Distance;Station;Note"]
            for fillup in fillups.sorted(by: { $0.date < $1.date }) {
                rows.append([
                    formatter.string(from: fillup.date),
                    String(format: "%.3f", fillup.pricePerLiter),
                    String(format: "%.2f", fillup.volumeL),
                    fillup.distanceUntilNext.map { String(format: "%.0f", $0) } ?? "",
                    fillup.station ?? "",
                    fillup.note ?? ""
                ].joined(separator: ";"))
            }
            csvContent = rows.joined(separator: "\n")
        }

        let filename = type == .trips ? "trajets_export.csv" : "pleins_export.csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? csvContent.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Fichiers exemple

    static func sampleCSV(type: ExportType) -> URL? {
        let lines: [String]
        let filename: String

        switch type {
        case .trips:
            filename = "exemple_trajets.csv"
            lines = [
                "Départ;Arrivée;Distance;Conso;Prix/L;Péage;Note",
                "18/09/2025 08:14;18/09/2025 08:48;24.1;4.2;1.610;;",
                "18/09/2025 16:23;18/09/2025 17:03;24.1;5.2;1.610;;Retour",
                "23/09/2025 16:45;23/09/2025 17:16;22.7;6.2;1.610;1.00;Autoroute"
            ]
        case .fillups:
            filename = "exemple_pleins.csv"
            lines = [
                "Date;Prix/L;Volume;Distance;Station;Note",
                "17/09/2025 09:00;1.610;37.79;672;Total Energie;",
                "04/10/2025 10:30;1.599;36.81;660;Intermarché;",
                "22/10/2025 08:15;1.555;38.21;673;;Prix bas"
            ]
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
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
