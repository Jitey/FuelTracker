import SwiftUI
import SwiftData

struct FuelFillupListView: View {

    @Query(sort: \FuelFillup.date, order: .reverse) private var fillups: [FuelFillup]
    @State private var showAddFillup = false

    private var fillupsByMonth: [(month: Date, fillups: [FuelFillup])] {
        let grouped = Dictionary(grouping: fillups) { fillup in
            Calendar.current.startOfMonth(for: fillup.date)
        }
        return grouped
            .map { (month: $0.key, fillups: $0.value) }
            .sorted { $0.month > $1.month }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(fillupsByMonth, id: \.month) { section in
                    FillupSectionView(
                        month: section.month,
                        fillups: section.fillups
                    )
                }
            }
            .listStyle(.plain)
            .navigationTitle("Pleins d'essence")
            .navigationDestination(for: FuelFillup.self) { fillup in
                FuelFillupDetailView(fillup: fillup)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddFillup = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddFillup) {
                AddFuelFillupView()
            }
        }
    }
}

// MARK: - Section mensuelle

struct FillupSectionView: View {
    let month: Date
    let fillups: [FuelFillup]
    @Environment(\.modelContext) private var context

    private var stats: FillupMonthStats { FillupMonthStats(fillups: fillups) }

    var body: some View {
        Section {
            ForEach(fillups) { fillup in
                ZStack {
                    FuelFillupRowView(fillup: fillup)
                    NavigationLink(value: fillup) { EmptyView() }
                        .opacity(0)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        context.delete(fillup)
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
                Text("\(stats.fillupCount) pleins · \(String(format: "%.1f L", stats.totalVolume)) · \(stats.totalSpent.formatted(.currency(code: "EUR")))")
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

struct FillupMonthStats {
    let fillupCount: Int
    let totalVolume: Double
    let totalSpent: Double

    init(fillups: [FuelFillup]) {
        self.fillupCount = fillups.count
        self.totalVolume = fillups.reduce(0) { $0 + $1.volumeL }
        self.totalSpent  = fillups.reduce(0) { $0 + $1.totalPrice }
    }
}

// MARK: - Preview

#Preview {
    FuelFillupListView()
        .modelContainer(previewContainer)
}
