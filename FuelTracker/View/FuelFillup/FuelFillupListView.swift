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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {

                    FillupMonthSummaryView(stats: visibleMonthStats, month: visibleMonth)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    ForEach(fillupsByMonth, id: \.month) { section in
                        FillupSectionView(
                            month: section.month,
                            fillups: section.fillups,
                            onVisible: { visibleMonth = section.month }
                        )
                        .padding(.bottom, 8)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Pleins d'essence")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .padding(.horizontal, 16)
                .onAppear { onVisible() }

            ForEach(fillups) { fillup in
                NavigationLink(destination: FuelFillupDetailView(fillup: fillup)) {
                    FuelFillupRowView(fillup: fillup)
                        .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
            }
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
