import SwiftUI
import SwiftData

enum GroupingPeriod: String, CaseIterable, Identifiable {
    case day = "Jour"
    case week = "Semaine"
    case month = "Mois"
    case year = "Année"
    case all = "Tout"
    var id: Self { self }
}

struct TripListView: View {

    @Query(sort: \Trip.departureDate, order: .reverse) private var trips: [Trip]
    @State private var showAddTrip = false
    @State private var groupingPeriod: GroupingPeriod = .month
    @State private var tripToEdit: Trip? = nil  // ← remonté ici

    private var tripsByPeriod: [(period: Date, trips: [Trip])] {
        let calendar = Calendar.current
        switch groupingPeriod {
        case .day:
            let grouped = Dictionary(grouping: trips) { trip in
                calendar.startOfDay(for: trip.departureDate)
            }
            return grouped.map { (period: $0.key, trips: $0.value) }.sorted { $0.period > $1.period }
        case .week:
            let grouped = Dictionary(grouping: trips) { trip in
                calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: trip.departureDate)) ?? trip.departureDate
            }
            return grouped.map { (period: $0.key, trips: $0.value) }.sorted { $0.period > $1.period }
        case .month:
            let grouped = Dictionary(grouping: trips) { trip in
                calendar.startOfMonth(for: trip.departureDate)
            }
            return grouped.map { (period: $0.key, trips: $0.value) }.sorted { $0.period > $1.period }
        case .year:
            let grouped = Dictionary(grouping: trips) { trip in
                let comps = calendar.dateComponents([.year], from: trip.departureDate)
                return calendar.date(from: comps) ?? trip.departureDate
            }
            return grouped.map { (period: $0.key, trips: $0.value) }.sorted { $0.period > $1.period }
        case .all:
            return trips.isEmpty ? [] : [(period: Date.distantPast, trips: trips)]
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(tripsByPeriod, id: \.period) { section in
                    PeriodSectionView(
                        period: section.period,
                        trips: section.trips,
                        grouping: groupingPeriod,
                        tripToEdit: $tripToEdit  // ← binding passé en bas
                    )
                }
            }
            .listStyle(.plain)
            .navigationTitle("Mes trajets")
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Picker("Période", selection: $groupingPeriod) {
                        ForEach(GroupingPeriod.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.menu)
                }
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
            // ← sheet géré ici sur la vue stable
            .sheet(item: $tripToEdit) { trip in
                EditTripView(trip: trip)
            }
        }
    }
}

// MARK: - Section périodique
// Note: les items du ForEach sont exposés directement à la List parente
// via @ViewBuilder pour que .swipeActions fonctionne correctement.

struct PeriodSectionView: View {
    let period: Date
    let trips: [Trip]
    let grouping: GroupingPeriod
    @Binding var tripToEdit: Trip?  // ← binding au lieu de @State local

    @Environment(\.modelContext) private var context

    private var stats: MonthStats { MonthStats(trips: trips) }

    private var headerText: String {
        switch grouping {
        case .day:
            return period.formatted(.dateTime.day().month().year())
        case .week:
            return "Semaine " + period.formatted(.dateTime.week())
//            return "Semaine du " + period.formatted(.dateTime.day().month().year())
        case .month:
            return period.formatted(.dateTime.month(.wide).year())
        case .year:
            return period.formatted(.dateTime.year())
        case .all:
            return "Tous les trajets"
        }
    }

    var body: some View {
        Section {
            ForEach(trips) { trip in
                ZStack {
                    TripRowView(trip: trip)
                    NavigationLink(value: trip) { EmptyView() }
                        .opacity(0)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        tripToEdit = trip
                    } label: {
                        Label("Modifier", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        context.delete(trip)
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerText)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(stats.tripCount) trajets · \(Int(stats.totalDistance)) km · \(stats.totalCost.formatted(.currency(code: "EUR")))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .textCase(nil)
            .padding(.leading, 16)
            .padding(.vertical, 4)
        }
        // ← .sheet supprimé d'ici
    }
}

// MARK: - Modèle stats

struct MonthStats {
    let tripCount: Int
    let totalDistance: Double
    let totalCost: Double

    init(trips: [Trip]) {
        self.tripCount    = trips.count
        self.totalDistance = trips.reduce(0) { $0 + $1.distanceKm }
        self.totalCost    = trips.reduce(0) { $0 + $1.totalCost }
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
