import SwiftUI
import SwiftData

struct TripListView: View {

    @Query(sort: \Trip.departureDate, order: .reverse) private var trips: [Trip]
    @State private var showAddTrip = false

    private var tripsByMonth: [(month: Date, trips: [Trip])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: trips) { trip in
            calendar.startOfMonth(for: trip.departureDate)
        }
        return grouped
            .map { (month: $0.key, trips: $0.value) }
            .sorted { $0.month > $1.month }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(tripsByMonth, id: \.month) { section in
                    MonthSectionView(
                        month: section.month,
                        trips: section.trips
                    )
                }
            }
            .listStyle(.plain)
            .navigationTitle("Mes trajets")
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
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

// MARK: - Section mensuelle
// Note: les items du ForEach sont exposés directement à la List parente
// via @ViewBuilder pour que .swipeActions fonctionne correctement.

struct MonthSectionView: View {
    let month: Date
    let trips: [Trip]
    @Environment(\.modelContext) private var context
    @State private var tripToEdit: Trip? = nil

    private var stats: MonthStats { MonthStats(trips: trips) }

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
                Text(month.formatted(.dateTime.month(.wide).year()))
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
        .sheet(item: $tripToEdit) { trip in
            EditTripView(trip: trip)
        }
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
