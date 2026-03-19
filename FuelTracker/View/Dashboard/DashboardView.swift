import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {

    @Query(sort: \Trip.departureDate, order: .reverse) private var trips: [Trip]
    @Query(sort: \FuelFillup.date, order: .reverse) private var fillups: [FuelFillup]

    @State private var selectedPeriod: Period = .sixMonths

    // MARK: - Période

    enum Period: String, CaseIterable {
        case oneMonth    = "1 mois"
        case threeMonths = "3 mois"
        case sixMonths   = "6 mois"
        case oneYear     = "1 an"
        case all         = "Tout"

        var startDate: Date? {
            let cal = Calendar.current
            switch self {
            case .oneMonth:    return cal.date(byAdding: .month, value: -1,  to: .now)
            case .threeMonths: return cal.date(byAdding: .month, value: -3,  to: .now)
            case .sixMonths:   return cal.date(byAdding: .month, value: -6,  to: .now)
            case .oneYear:     return cal.date(byAdding: .year,  value: -1,  to: .now)
            case .all:         return nil
            }
        }

        var granularity: Granularity {
            switch self {
            case .oneMonth, .threeMonths: return .week
            case .sixMonths, .oneYear:    return .month
            case .all:                    return .quarter
            }
        }

        var visiblePoints: Int {
            switch self {
            case .oneMonth:    return 4
            case .threeMonths: return 6
            default:           return 6
            }
        }
    }

    enum Granularity { case week, month, quarter }

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

    // MARK: - Agrégation dynamique

    private var aggregatedData: [PeriodStats] {
        let cal = Calendar.current

        func bucketStart(_ date: Date) -> Date {
            switch selectedPeriod.granularity {
            case .week:
                return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            case .month:
                return cal.startOfMonth(for: date)
            case .quarter:
                let month = cal.component(.month, from: date)
                let qMonth = ((month - 1) / 3) * 3 + 1
                var comps = cal.dateComponents([.year], from: date)
                comps.month = qMonth
                comps.day = 1
                return cal.date(from: comps) ?? date
            }
        }

        let tripsByBucket   = Dictionary(grouping: filteredTrips)   { bucketStart($0.departureDate) }
        let fillupsByBucket = Dictionary(grouping: filteredFillups) { bucketStart($0.date) }
        let allBuckets      = Set(Array(tripsByBucket.keys) + Array(fillupsByBucket.keys)).sorted()

        return allBuckets.map { bucket in
            let bTrips   = tripsByBucket[bucket]   ?? []
            let bFillups = fillupsByBucket[bucket] ?? []
            let avgConso = bTrips.isEmpty   ? nil : bTrips.reduce(0)   { $0 + $1.consumptionL100 } / Double(bTrips.count)
            let avgPrice = bFillups.isEmpty ? nil : bFillups.reduce(0) { $0 + $1.pricePerLiter }   / Double(bFillups.count)
            return PeriodStats(
                bucketStart:    bucket,
                granularity:    selectedPeriod.granularity,
                totalCost:      bTrips.reduce(0) { $0 + $1.totalCost },
                totalDistance:  bTrips.reduce(0) { $0 + $1.distanceKm },
                avgConsumption: avgConso,
                avgFuelPrice:   avgPrice
            )
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    Picker("Période", selection: $selectedPeriod) {
                        ForEach(Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    HStack(spacing: 12) {
                        StatCard(label: "Conso moyenne",
                                 value: avgConsumption.map { String(format: "%.1f", $0) } ?? "—",
                                 unit: "L/100", color: .primary)
                        StatCard(label: "Prix moyen/litre",
                                 value: avgFuelPrice.map { String(format: "%.3f", $0) } ?? "—",
                                 unit: "€/L", color: .teal)
                    }
                    .padding(.horizontal, 16)

                    if aggregatedData.isEmpty {
                        ContentUnavailableView(
                            "Pas encore de données",
                            systemImage: "chart.bar",
                            description: Text("Ajoutez des trajets et des pleins pour voir vos statistiques.")
                        )
                        .padding(.top, 40)
                    } else {
                        FuelPriceChartView(
                            data: aggregatedData.filter { $0.avgFuelPrice != nil },
                            visiblePoints: selectedPeriod.visiblePoints
                        )
                        .padding(.horizontal, 16)

                        CustomBarChartView(
                            title: "Coût mensuel",
                            data: aggregatedData,
                            value: \.totalCost,
                            formatter: { String(format: "%.0f €", $0) }
                        )
                        .padding(.horizontal, 16)

                        CustomBarChartView(
                            title: "Distance mensuelle",
                            data: aggregatedData,
                            value: \.totalDistance,
                            formatter: { String(format: "%.0f km", $0) }
                        )
                        .padding(.horizontal, 16)

                        CustomBarChartView(
                            title: "Consommation moy.",
                            data: aggregatedData,
                            value: { $0.avgConsumption ?? 0 },
                            formatter: { String(format: "%.1f L/100", $0) },
                            skipZero: true
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Dashboard")
        }
    }
}

// MARK: - Modèle période agrégée

struct PeriodStats: Identifiable {
    let id = UUID()
    let bucketStart: Date
    let granularity: DashboardView.Granularity
    let totalCost: Double
    let totalDistance: Double
    let avgConsumption: Double?
    let avgFuelPrice: Double?

    var label: String {
        switch granularity {
        case .week:
            return bucketStart.formatted(.dateTime.day().month(.abbreviated))
        case .month:
            return bucketStart.formatted(.dateTime.month(.abbreviated))
        case .quarter:
            let month = Calendar.current.component(.month, from: bucketStart)
            let q = (month - 1) / 3 + 1
            let year = bucketStart.formatted(.dateTime.year(.twoDigits))
            return "T\(q) \(year)"
        }
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

// MARK: - Courbe prix au litre (Swift Charts + scroll)

struct FuelPriceChartView: View {
    let data: [PeriodStats]
    let visiblePoints: Int

    var body: some View {
        ChartCard(title: "Évolution prix au litre") {
            Chart(data) { item in
                LineMark(
                    x: .value("Période", item.label),
                    y: .value("Prix", item.avgFuelPrice ?? 0)
                )
                .foregroundStyle(Color.teal)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Période", item.label),
                    y: .value("Prix", item.avgFuelPrice ?? 0)
                )
                .foregroundStyle(Color.teal.opacity(0.08))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Période", item.label),
                    y: .value("Prix", item.avgFuelPrice ?? 0)
                )
                .foregroundStyle(Color.teal)
                .symbolSize(25)
            }
            .chartYAxis {
                AxisMarks(format: .currency(code: "EUR").precision(.fractionLength(2)))
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visiblePoints)
            .frame(height: 160)
        }
    }
}

// MARK: - Barres horizontales custom

struct CustomBarChartView: View {
    let title: String
    let data: [PeriodStats]
    let value: (PeriodStats) -> Double
    let formatter: (Double) -> String
    var skipZero: Bool = false

    private var displayData: [PeriodStats] {
        let d = skipZero ? data.filter { value($0) > 0 } : data
        return d.reversed()
    }

    private var maxValue: Double {
        displayData.map { value($0) }.max() ?? 1
    }

    private let rowHeight: CGFloat  = 22
    private let rowSpacing: CGFloat = 8
    private let labelWidth: CGFloat = 46
    private let valueWidth: CGFloat = 76
    private let visibleRows: Int    = 5

    private var totalRows: Int { displayData.count }

    private var visibleHeight: CGFloat {
        CGFloat(min(totalRows, visibleRows)) * (rowHeight + rowSpacing)
    }

    var body: some View {
        ChartCard(title: title) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: rowSpacing) {
                    ForEach(displayData) { item in
                        let val   = value(item)
                        let ratio = maxValue > 0 ? val / maxValue : 0
                        let isMax = val == maxValue && val > 0

                        HStack(spacing: 8) {
                            Text(item.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: labelWidth, alignment: .trailing)
                                .lineLimit(1)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(.systemFill))
                                        .frame(height: rowHeight)

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(isMax ? Color.teal : Color.teal.opacity(0.55))
                                        .frame(
                                            width: max(4, geo.size.width * ratio),
                                            height: rowHeight
                                        )
                                        .animation(.easeOut(duration: 0.35), value: ratio)
                                }
                            }
                            .frame(height: rowHeight)

                            Text(formatter(val))
                                .font(.caption2)
                                .fontWeight(isMax ? .semibold : .regular)
                                .foregroundStyle(isMax ? Color.teal : .secondary)
                                .frame(width: valueWidth, alignment: .leading)
                                .lineLimit(1)
                        }
                        .frame(height: rowHeight)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: visibleHeight)
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
