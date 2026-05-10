import SwiftUI
import SwiftData

// MARK: - Sélecteur de route inline (utilisé dans AddTripView / EditTripView)

struct RoutePickerView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Route.createdAt, order: .forward) private var routes: [Route]

    @Binding var selectedRoute: Route?
    @Binding var isReturn: Bool

    @State private var showCreateRoute = false

    var body: some View {
        NavigationStack {
            List {
                // Aucune route
                Section {
                    Button {
                        selectedRoute = nil
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                            Text("Aucune route")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedRoute == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.teal)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }

                // Routes existantes
                if !routes.isEmpty {
                    Section("Mes routes") {
                        ForEach(routes) { route in
                            RoutePickerRow(
                                route: route,
                                isSelected: selectedRoute?.id == route.id,
                                isReturn: selectedRoute?.id == route.id ? isReturn : false
                            ) { chosenIsReturn in
                                selectedRoute = route
                                isReturn = chosenIsReturn
                                dismiss()
                            }
                        }
                    }
                }

                // Créer une nouvelle route
                Section {
                    Button {
                        showCreateRoute = true
                    } label: {
                        Label("Créer une nouvelle route", systemImage: "plus.circle.fill")
                            .foregroundStyle(.teal)
                    }
                }
            }
            .navigationTitle("Choisir une route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .sheet(isPresented: $showCreateRoute) {
                CreateRouteView { newRoute in
                    selectedRoute = newRoute
                    isReturn = false
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Row d'une route avec choix aller/retour

private struct RoutePickerRow: View {
    let route: Route
    let isSelected: Bool
    let isReturn: Bool
    let onSelect: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Nom de la route
            HStack {
                RouteColorDot(colorName: route.colorName, size: 10)
                Text(route.origin)
                    .fontWeight(.medium)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(route.destination)
                    .fontWeight(.medium)
                Spacer()
            }
            .foregroundStyle(.primary)

            // Boutons aller / retour
            HStack(spacing: 8) {
                DirectionButton(
                    label: "↗ Aller",
                    subtitle: route.label,
                    isSelected: isSelected && !isReturn,
                    color: route.colorName
                ) { onSelect(false) }

                DirectionButton(
                    label: "↙ Retour",
                    subtitle: route.returnLabel,
                    isSelected: isSelected && isReturn,
                    color: route.colorName
                ) { onSelect(true) }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DirectionButton: View {
    let label: String
    let subtitle: String
    let isSelected: Bool
    let color: String
    let action: () -> Void

    private var resolvedColor: Color { RouteColor.color(for: color) }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isSelected
                    ? resolvedColor.opacity(0.15)
                    : Color(.systemFill),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? resolvedColor : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .foregroundStyle(isSelected ? resolvedColor : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dot coloré réutilisable

struct RouteColorDot: View {
    let colorName: String
    var size: CGFloat = 12

    private var color: Color {
        switch colorName {
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
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}
