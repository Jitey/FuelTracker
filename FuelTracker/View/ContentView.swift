import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Trajets", systemImage: "car.fill") {
                TripListView()
            }
            Tab("Pleins", systemImage: "fuelpump.fill") {
                FuelFillupListView()
            }
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                DashboardView()
            }
            Tab("Réglages", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
