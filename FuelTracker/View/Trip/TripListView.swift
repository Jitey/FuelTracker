import SwiftUI
import SwiftData

struct TripListView: View {

    @Query(sort: \Trip.departureDate, order: .reverse) private var trips: [Trip]
    @State private var visibleMonth: Date = Calendar.current.startOfMonth(for: .now)
    @State private var showAddTrip = false

    // Groupement des trajets par mois
    private var tripsByMonth: [(month: Date, trips: [Trip])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: trips) { trip in
            calendar.startOfMonth(for: trip.departureDate)
        }
        return grouped
            .map { (month: $0.key, trips: $0.value) }
            .sorted { $0.month > $1.month }
    }

    // Stats du mois visible
    private var visibleMonthStats: MonthStats {
        let monthTrips = trips.filter {
            Calendar.current.startOfMonth(for: $0.departureDate) == visibleMonth
        }
        return MonthStats(trips: monthTrips)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {

                    // Résumé du mois visible
                    MonthSummaryView(stats: visibleMonthStats, month: visibleMonth)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // Sections par mois
                    ForEach(tripsByMonth, id: \.month) { section in
                        MonthSectionView(
                            month: section.month,
                            trips: section.trips,
                            onVisible: { visibleMonth = section.month }
                        )
                        .padding(.bottom, 8)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Mes trajets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddTrip = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddTrip) {
                AddTripView()
            }
        }
    }
}

// MARK: - Résumé mensuel

struct MonthSummaryView: View {
    let stats: MonthStats
    let month: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            HStack(spacing: 10) {
                SummaryStatCard(
                    value: "\(stats.tripCount)",
                    label: "trajets"
                )
                SummaryStatCard(
                    value: stats.totalDistance.formatted(.number.precision(.fractionLength(0))) + " km",
                    label: "distance"
                )
                SummaryStatCard(
                    value: stats.totalCost.formatted(.currency(code: "EUR")),
                    label: "coût total",
                    accentColor: .teal
                )
            }
        }
    }
}

struct SummaryStatCard: View {
    let value: String
    let label: String
    var accentColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(accentColor == .teal ? Color.teal : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Section mensuelle

struct MonthSectionView: View {
    let month: Date
    let trips: [Trip]
    let onVisible: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .padding(.horizontal, 16)
                .onAppear { onVisible() }

            ForEach(trips) { trip in
                NavigationLink(destination: TripDetailView(trip: trip)) {
                    TripRowView(trip: trip)
                        .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Modèle stats

struct MonthStats {
    let tripCount: Int
    let totalDistance: Double
    let totalCost: Double

    init(trips: [Trip]) {
        self.tripCount = trips.count
        self.totalDistance = trips.reduce(0) { $0 + $1.distanceKm }
        self.totalCost = trips.reduce(0) { $0 + $1.totalCost }
    }
}

// MARK: - Extension Calendar

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

// MARK: - Preview

#Preview {
    TripListView()
        .modelContainer(previewContainer)
}
