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
            .navigationTitle("Mes trajets")
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 8) {
                        Picker("Période", selection: $groupingPeriod) {
                            ForEach(GroupingPeriod.allCases) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(.menu)

                        if !routes.isEmpty {
                            RouteFilterButton(routes: routes, selectedRoute: $selectedRoute)
                        }
                    }
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

// MARK: - Bouton filtre route (toolbar)

struct RouteFilterButton: View {
    let routes: [Route]
    @Binding var selectedRoute: Route?

    private var isActive: Bool { selectedRoute != nil }

    private var activeColor: Color {
        guard let r = selectedRoute else { return .accentColor }
        switch r.colorName {
        case "blue":   return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink":   return .pink
        case "red":    return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green":  return .green
        case "mint":   return .mint
        default:       return .teal
        }
    }

    var body: some View {
        Menu {
            // Toutes les routes
            Button {
                withAnimation { selectedRoute = nil }
            } label: {
                Label("Tous les trajets", systemImage: selectedRoute == nil ? "checkmark" : "list.bullet")
            }

            Divider()

            ForEach(routes) { route in
                Button {
                    withAnimation { selectedRoute = route }
                } label: {
                    // Checkmark si route active
                    if selectedRoute?.id == route.id {
                        Label(route.origin + " ↔ " + route.destination, systemImage: "checkmark")
                    } else {
                        Text(route.origin + " ↔ " + route.destination)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .foregroundStyle(isActive ? activeColor : .secondary)
                if let route = selectedRoute {
                    Text(route.origin + " ↔ " + route.destination)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(activeColor)
                        .lineLimit(1)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isActive)
        }
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
