import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {

    @Query(sort: \Trip.departureDate, order: .reverse) private var trips: [Trip]
    @Query(sort: \FuelFillup.date, order: .reverse) private var fillups: [FuelFillup]

    @State private var selectedPeriod: Period = .sixMonths

    // MARK: - Période

    enum Period: String, CaseIterable {
        case oneMonth  = "1 mois"
        case threeMonths = "3 mois"
        case sixMonths = "6 mois"
        case oneYear   = "1 an"
        case all       = "Tout"

        var startDate: Date? {
            let calendar = Calendar.current
            switch self {
            case .oneMonth:    return calendar.date(byAdding: .month, value: -1, to: .now)
            case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: .now)
            case .sixMonths:   return calendar.date(byAdding: .month, value: -6, to: .now)
            case .oneYear:     return calendar.date(byAdding: .year,  value: -1, to: .now)
            case .all:         return nil
            }
        }
    }

    // MARK: - Données filtrées

    private var filteredTrips: [Trip] {
        guard let start = selectedPeriod.startDate else { return trips }
        return trips.filter { $0.departureDate >= start }
    }

    private var filteredFillups: [FuelFillup] {
        guard let start = selectedPeriod.startDate else { return fillups }
        return fillups.filter { $0.date >= start }
    }

    // MARK: - Stats globales

    private var avgConsumption: Double? {
        let valid = filteredTrips.filter { $0.consumptionL100 > 0 }
        guard !valid.isEmpty else { return nil }
        return valid.reduce(0) { $0 + $1.consumptionL100 } / Double(valid.count)
    }

    private var avgFuelPrice: Double? {
        let valid = filteredFillups.filter { $0.pricePerLiter > 0 }
        guard !valid.isEmpty else { return nil }
        return valid.reduce(0) { $0 + $1.pricePerLiter } / Double(valid.count)
    }

    // MARK: - Données graphiques par mois

    private var monthlyData: [MonthlyStats] {
        let calendar = Calendar.current
        let allDates = (filteredTrips.map { $0.departureDate } + filteredFillups.map { $0.date })
        guard !allDates.isEmpty else { return [] }

        let tripsByMonth = Dictionary(grouping: filteredTrips) {
            calendar.startOfMonth(for: $0.departureDate)
        }
        let fillupsByMonth = Dictionary(grouping: filteredFillups) {
            calendar.startOfMonth(for: $0.date)
        }

        let allMonths = Set(
            tripsByMonth.keys.map { $0 } + fillupsByMonth.keys.map { $0 }
        ).sorted()

        return allMonths.map { month in
            let mTrips   = tripsByMonth[month] ?? []
            let mFillups = fillupsByMonth[month] ?? []

            let totalCost     = mTrips.reduce(0) { $0 + $1.totalCost }
            let totalDistance = mTrips.reduce(0) { $0 + $1.distanceKm }
            let avgConso      = mTrips.isEmpty ? nil :
                mTrips.reduce(0) { $0 + $1.consumptionL100 } / Double(mTrips.count)
            let avgPrice      = mFillups.isEmpty ? nil :
                mFillups.reduce(0) { $0 + $1.pricePerLiter } / Double(mFillups.count)

            return MonthlyStats(
                month: month,
                totalCost: totalCost,
                totalDistance: totalDistance,
                avgConsumption: avgConso,
                avgFuelPrice: avgPrice
            )
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Sélecteur de période
                    Picker("Période", selection: $selectedPeriod) {
                        ForEach(Period.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Stat cards
                    HStack(spacing: 12) {
                        StatCard(
                            label: "Conso moyenne",
                            value: avgConsumption.map { String(format: "%.1f", $0) } ?? "—",
                            unit: "L/100",
                            color: .primary
                        )
                        StatCard(
                            label: "Prix moyen/litre",
                            value: avgFuelPrice.map { String(format: "%.3f", $0) } ?? "—",
                            unit: "€/L",
                            color: .teal
                        )
                    }
                    .padding(.horizontal, 16)

                    // Graphiques
                    if monthlyData.isEmpty {
                        ContentUnavailableView(
                            "Pas encore de données",
                            systemImage: "chart.bar",
                            description: Text("Ajoutez des trajets et des pleins pour voir vos statistiques.")
                        )
                        .padding(.top, 40)
                    } else {
                        FuelPriceChartView(data: monthlyData)
                            .padding(.horizontal, 16)

                        MonthlyCostChartView(data: monthlyData)
                            .padding(.horizontal, 16)

                        MonthlyDistanceChartView(data: monthlyData)
                            .padding(.horizontal, 16)

                        MonthlyConsumptionChartView(data: monthlyData)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Dashboard")
        }
    }
}

// MARK: - Modèle données mensuelles

struct MonthlyStats: Identifiable {
    let id = UUID()
    let month: Date
    let totalCost: Double
    let totalDistance: Double
    let avgConsumption: Double?
    let avgFuelPrice: Double?

    var monthLabel: String {
        month.formatted(.dateTime.month(.abbreviated))
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(color == .teal ? Color.teal : Color.primary)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Chart : Évolution prix au litre

struct FuelPriceChartView: View {
    let data: [MonthlyStats]
    private var priceData: [MonthlyStats] { data.filter { $0.avgFuelPrice != nil } }

    var body: some View {
        ChartCard(title: "Évolution prix au litre") {
            Chart(priceData) { item in
                LineMark(
                    x: .value("Mois", item.monthLabel),
                    y: .value("Prix", item.avgFuelPrice ?? 0)
                )
                .foregroundStyle(Color.teal)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Mois", item.monthLabel),
                    y: .value("Prix", item.avgFuelPrice ?? 0)
                )
                .foregroundStyle(Color.teal.opacity(0.08))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Mois", item.monthLabel),
                    y: .value("Prix", item.avgFuelPrice ?? 0)
                )
                .foregroundStyle(Color.teal)
                .symbolSize(30)
            }
            .chartYAxis {
                AxisMarks(format: .currency(code: "EUR").precision(.fractionLength(2)))
            }
            .frame(height: 140)
        }
    }
}

// MARK: - Chart : Coût mensuel

struct MonthlyCostChartView: View {
    let data: [MonthlyStats]

    var body: some View {
        ChartCard(title: "Coût mensuel") {
            Chart(data) { item in
                BarMark(
                    x: .value("Coût", item.totalCost),
                    y: .value("Mois", item.monthLabel)
                )
                .foregroundStyle(Color.teal.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(format: .currency(code: "EUR").precision(.fractionLength(0)))
            }
            .frame(height: Double(data.count) * 36 + 16)
        }
    }
}

// MARK: - Chart : Distance mensuelle

struct MonthlyDistanceChartView: View {
    let data: [MonthlyStats]

    var body: some View {
        ChartCard(title: "Distance mensuelle") {
            Chart(data) { item in
                BarMark(
                    x: .value("Distance", item.totalDistance),
                    y: .value("Mois", item.monthLabel)
                )
                .foregroundStyle(Color.teal.opacity(0.7).gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v)) km")
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: Double(data.count) * 36 + 16)
        }
    }
}

// MARK: - Chart : Consommation mensuelle

struct MonthlyConsumptionChartView: View {
    let data: [MonthlyStats]
    private var consoData: [MonthlyStats] { data.filter { $0.avgConsumption != nil } }

    var body: some View {
        ChartCard(title: "Consommation mensuelle") {
            Chart(consoData) { item in
                BarMark(
                    x: .value("Conso", item.avgConsumption ?? 0),
                    y: .value("Mois", item.monthLabel)
                )
                .foregroundStyle(Color.teal.opacity(0.5).gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(String(format: "%.1f", v))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXScale(domain: 4...10)
            .frame(height: Double(consoData.count) * 36 + 16)
        }
    }
}

// MARK: - Conteneur carte graphique

struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            content
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .modelContainer(previewContainer)
}
