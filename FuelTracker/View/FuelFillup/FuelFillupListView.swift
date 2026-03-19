import SwiftUI
import SwiftData

struct FuelFillupListView: View {

    @Query(sort: \FuelFillup.date, order: .reverse) private var fillups: [FuelFillup]
    @State private var visibleMonth: Date = Calendar.current.startOfMonth(for: .now)
    @State private var showAddFillup = false

    private var fillupsByMonth: [(month: Date, fillups: [FuelFillup])] {
        let grouped = Dictionary(grouping: fillups) { fillup in
            Calendar.current.startOfMonth(for: fillup.date)
        }
        return grouped
            .map { (month: $0.key, fillups: $0.value) }
            .sorted { $0.month > $1.month }
    }

    private var visibleMonthStats: FillupMonthStats {
        let monthFillups = fillups.filter {
            Calendar.current.startOfMonth(for: $0.date) == visibleMonth
        }
        return FillupMonthStats(fillups: monthFillups)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FillupMonthSummaryView(stats: visibleMonthStats, month: visibleMonth)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                List {
                    ForEach(fillupsByMonth, id: \.month) { section in
                        FillupSectionView(
                            month: section.month,
                            fillups: section.fillups,
                            onVisible: { visibleMonth = section.month }
                        )
                    }
                }
                .listStyle(.plain)
            }
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

// MARK: - Résumé mensuel

struct FillupMonthSummaryView: View {
    let stats: FillupMonthStats
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
                    value: "\(stats.fillupCount)",
                    label: "pleins"
                )
                SummaryStatCard(
                    value: String(format: "%.1f L", stats.totalVolume),
                    label: "volume total"
                )
                SummaryStatCard(
                    value: stats.totalSpent.formatted(.currency(code: "EUR")),
                    label: "dépensé",
                    accentColor: .teal
                )
            }
        }
    }
}

// MARK: - Section mensuelle

struct FillupSectionView: View {
    let month: Date
    let fillups: [FuelFillup]
    let onVisible: () -> Void
    @Environment(\.modelContext) private var context

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
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .foregroundStyle(.primary)
                .textCase(nil)
                .padding(.leading, 16)
                .onAppear { onVisible() }
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
