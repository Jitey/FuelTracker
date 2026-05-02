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
    @Query(sort: \Route.createdAt, order: .forward) private var routes: [Route]

    @State private var showAddTrip = false
    @State private var groupingPeriod: GroupingPeriod = .month
    @State private var tripToEdit: Trip? = nil
    @State private var selectedRoute: Route? = nil   // nil = tous les trajets

    // MARK: - Filtrage

    private var filteredTrips: [Trip] {
        guard let selectedRoute else { return trips }
        return trips.filter { $0.route?.id == selectedRoute.id }
    }

    // MARK: - Regroupement

    private var tripsByPeriod: [(period: Date, trips: [Trip])] {
        let calendar = Calendar.current
        switch groupingPeriod {
        case .day:
            let grouped = Dictionary(grouping: filteredTrips) { trip in
                calendar.startOfDay(for: trip.departureDate)
            }
            return grouped.map { (period: $0.key, trips: $0.value) }.sorted { $0.period > $1.period }
        case .week:
            let grouped = Dictionary(grouping: filteredTrips) { trip in
                calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: trip.departureDate)) ?? trip.departureDate
            }
            return grouped.map { (period: $0.key, trips: $0.value) }.sorted { $0.period > $1.period }
        case .month:
            let grouped = Dictionary(grouping: filteredTrips) { trip in
                calendar.startOfMonth(for: trip.departureDate)
            }
            return grouped.map { (period: $0.key, trips: $0.value) }.sorted { $0.period > $1.period }
        case .year:
            let grouped = Dictionary(grouping: filteredTrips) { trip in
                let comps = calendar.dateComponents([.year], from: trip.departureDate)
                return calendar.date(from: comps) ?? trip.departureDate
            }
            return grouped.map { (period: $0.key, trips: $0.value) }.sorted { $0.period > $1.period }
        case .all:
            return filteredTrips.isEmpty ? [] : [(period: Date.distantPast, trips: filteredTrips)]
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: Filtre route (si au moins une route existe)
                if !routes.isEmpty {
                    RouteFilterBar(routes: routes, selectedRoute: $selectedRoute)
                }

                List {
                    ForEach(tripsByPeriod, id: \.period) { section in
                        PeriodSectionView(
                            period: section.period,
                            trips: section.trips,
                            grouping: groupingPeriod,
                            tripToEdit: $tripToEdit
                        )
                    }
                }
                .listStyle(.plain)
            }
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
            .sheet(item: $tripToEdit) { trip in
                EditTripView(trip: trip)
            }
        }
    }
}

// MARK: - Barre de filtre par route

struct RouteFilterBar: View {
    let routes: [Route]
    @Binding var selectedRoute: Route?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Chip "Tous"
                FilterChip(
                    label: "Tous",
                    colorName: nil,
                    isSelected: selectedRoute == nil
                ) {
                    selectedRoute = nil
                }

                ForEach(routes) { route in
                    FilterChip(
                        label: route.origin + " ↔ " + route.destination,
                        colorName: route.colorName,
                        isSelected: selectedRoute?.id == route.id
                    ) {
                        selectedRoute = selectedRoute?.id == route.id ? nil : route
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct FilterChip: View {
    let label: String
    let colorName: String?
    let isSelected: Bool
    let action: () -> Void

    var chipColor: Color {
        colorName.map { Color($0) } ?? .teal
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let colorName {
                    RouteColorDot(colorName: colorName, size: 8)
                }
                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ? chipColor.opacity(0.15) : Color(.systemFill),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? chipColor : Color.clear, lineWidth: 1.5)
            )
            .foregroundStyle(isSelected ? chipColor : .secondary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Section périodique

struct PeriodSectionView: View {
    let period: Date
    let trips: [Trip]
    let grouping: GroupingPeriod
    @Binding var tripToEdit: Trip?

    @Environment(\.modelContext) private var context

    private var stats: MonthStats { MonthStats(trips: trips) }

    private var headerText: String {
        switch grouping {
        case .day:
            return period.formatted(.dateTime.day().month().year())
        case .week:
            return "Semaine " + period.formatted(.dateTime.week())
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
    }
}

// MARK: - Modèle stats

struct MonthStats {
    let tripCount: Int
    let totalDistance: Double
    let totalCost: Double

    init(trips: [Trip]) {
        self.tripCount     = trips.count
        self.totalDistance = trips.reduce(0) { $0 + $1.distanceKm }
        self.totalCost     = trips.reduce(0) { $0 + $1.totalCost }
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
