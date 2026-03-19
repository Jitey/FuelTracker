import SwiftUI
import SwiftData

struct FuelFillupRowView: View {
    let fillup: FuelFillup

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Ligne principale : date + prix total
            HStack(alignment: .firstTextBaseline) {
                Text(fillup.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                Text(fillup.totalPrice.formatted(.currency(code: "EUR")))
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.teal)
            }

            // Ligne secondaire : volume + prix/litre + conso si dispo
            HStack(spacing: 8) {
                Label(String(format: "%.2f L", fillup.volumeL), systemImage: "fuelpump")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Circle()
                    .fill(.secondary.opacity(0.4))
                    .frame(width: 3, height: 3)

                Text(fillup.pricePerLiter.formatted(.currency(code: "EUR")) + "/L")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let conso = fillup.avgConsumption {
                    Circle()
                        .fill(.secondary.opacity(0.4))
                        .frame(width: 3, height: 3)
                    Text(String(format: "%.1f L/100", conso))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Station (si renseignée)
            if let station = fillup.station, !station.isEmpty {
                Label(station, systemImage: "mappin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#Preview {
    FuelFillupRowView(fillup: SampleData.sampleFillup)
        .padding()
        .modelContainer(previewContainer)
}
