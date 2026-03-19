import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Intent (action du bouton)

struct MarkDepartureIntent: AppIntent {
    static var title: LocalizedStringResource = "Marquer le départ"

    func perform() async throws -> some IntentResult {
        TripDraftStore.shared.markDeparture()
        return .result()
    }
}

// MARK: - Timeline Entry

struct DepartureEntry: TimelineEntry {
    let date: Date
    let pendingDeparture: Date?
}

// MARK: - Provider

struct DepartureProvider: TimelineProvider {

    func placeholder(in context: Context) -> DepartureEntry {
        DepartureEntry(date: .now, pendingDeparture: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DepartureEntry) -> Void) {
        completion(DepartureEntry(date: .now, pendingDeparture: TripDraftStore.shared.pendingDepartureDate))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DepartureEntry>) -> Void) {
        let entry = DepartureEntry(date: .now, pendingDeparture: TripDraftStore.shared.pendingDepartureDate)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - Widget View

struct FuelTrackerWidgetView: View {
    let entry: DepartureEntry

    var body: some View {
        if let departure = entry.pendingDeparture {
            // Départ enregistré — affiche l'heure
            VStack(spacing: 4) {
                Image(systemName: "car.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.teal)
                Text("En trajet")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                Text(departure.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.teal)
            }
        } else {
            // Pas de départ — bouton pour marquer
            Button(intent: MarkDepartureIntent()) {
                VStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.teal)
                    Text("Départ")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Widget Configuration

struct FuelTrackerWidget: Widget {
    let kind = "FuelTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DepartureProvider()) { entry in
            FuelTrackerWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("FuelTracker")
        .description("Marquez votre départ d'un tap.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    FuelTrackerWidget()
} timeline: {
    DepartureEntry(date: .now, pendingDeparture: nil)
    DepartureEntry(date: .now, pendingDeparture: .now)
}
