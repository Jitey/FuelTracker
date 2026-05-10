import SwiftUI
import SwiftData

// MARK: - Création d'une route

struct CreateRouteView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var onCreated: ((Route) -> Void)? = nil

    @State private var origin: String = ""
    @State private var destination: String = ""
    @State private var selectedColor: String = RouteColor.teal.rawValue

    private var isValid: Bool {
        !origin.trimmingCharacters(in: .whitespaces).isEmpty &&
        !destination.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Points") {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.green)
                        TextField("Départ (ex: Maison)", text: $origin)
                    }
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.red)
                        TextField("Arrivée (ex: Bureau)", text: $destination)
                    }
                }

                Section("Couleur") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(RouteColor.allCases, id: \.self) { color in
                            ColorSwatch(
                                colorName: color.rawValue,
                                isSelected: selectedColor == color.rawValue
                            ) {
                                selectedColor = color.rawValue
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Aperçu
                if isValid {
                    Section("Aperçu") {
                        RoutePreviewRow(
                            origin: origin,
                            destination: destination,
                            colorName: selectedColor
                        )
                    }
                }
            }
            .navigationTitle("Nouvelle route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        createRoute()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }

    private func createRoute() {
        let route = Route(
            origin: origin.trimmingCharacters(in: .whitespaces),
            destination: destination.trimmingCharacters(in: .whitespaces),
            colorName: selectedColor
        )
        context.insert(route)
        try? context.save()
        onCreated?(route)
        dismiss()
    }
}

// MARK: - Gestion des routes (liste + édition)

struct RouteManagerView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \Route.createdAt, order: .forward) private var routes: [Route]

    @State private var showCreate = false
    @State private var routeToEdit: Route? = nil

    var body: some View {
        List {
            if routes.isEmpty {
                ContentUnavailableView(
                    "Aucune route",
                    systemImage: "arrow.triangle.swap",
                    description: Text("Créez vos trajets récurrents pour les regrouper facilement.")
                )
            } else {
                ForEach(routes) { route in
                    Button {
                        routeToEdit = route
                    } label: {
                        RouteManagerRow(route: route)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            context.delete(route)
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Mes routes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateRouteView()
        }
        .sheet(item: $routeToEdit) { route in
            EditRouteView(route: route)
        }
    }
}

// MARK: - Row dans la liste de gestion

private struct RouteManagerRow: View {
    let route: Route

    var body: some View {
        HStack(spacing: 12) {
            RouteColorDot(colorName: route.colorName, size: 14)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(route.origin)
                        .fontWeight(.medium)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(route.destination)
                        .fontWeight(.medium)
                }
                Text("\(route.trips.count) trajet\(route.trips.count > 1 ? "s" : "") · \(route.outboundCount) aller\(route.outboundCount > 1 ? "s" : "") · \(route.returnCount) retour\(route.returnCount > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Édition d'une route

struct EditRouteView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let route: Route

    @State private var origin: String
    @State private var destination: String
    @State private var selectedColor: String

    init(route: Route) {
        self.route = route
        _origin        = State(initialValue: route.origin)
        _destination   = State(initialValue: route.destination)
        _selectedColor = State(initialValue: route.colorName)
    }

    private var isValid: Bool {
        !origin.trimmingCharacters(in: .whitespaces).isEmpty &&
        !destination.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Points") {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.green)
                        TextField("Départ", text: $origin)
                    }
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.red)
                        TextField("Arrivée", text: $destination)
                    }
                }

                Section("Couleur") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(RouteColor.allCases, id: \.self) { color in
                            ColorSwatch(
                                colorName: color.rawValue,
                                isSelected: selectedColor == color.rawValue
                            ) {
                                selectedColor = color.rawValue
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Statistiques") {
                    HStack {
                        Text("Trajets aller")
                        Spacer()
                        Text("\(route.outboundCount)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Trajets retour")
                        Spacer()
                        Text("\(route.returnCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Modifier la route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        route.origin      = origin.trimmingCharacters(in: .whitespaces)
                        route.destination = destination.trimmingCharacters(in: .whitespaces)
                        route.colorName   = selectedColor
                        try? context.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }
}

// MARK: - Composants partagés

struct ColorSwatch: View {
    let colorName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(RouteColor.color(for: colorName))
                    .frame(width: 36, height: 36)
                if isSelected {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2.5)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct RoutePreviewRow: View {
    let origin: String
    let destination: String
    let colorName: String

    var body: some View {
        let color = RouteColor.color(for: colorName)
        HStack(spacing: 8) {
            RouteColorDot(colorName: colorName, size: 10)
            Text("↗")
                .font(.caption)
                .foregroundStyle(color)
            Text("\(origin) → \(destination)")
                .font(.subheadline)
            Spacer()
        }
        .padding(.vertical, 2)

        HStack(spacing: 8) {
            RouteColorDot(colorName: colorName, size: 10)
            Text("↙")
                .font(.caption)
                .foregroundStyle(color)
            Text("\(destination) → \(origin)")
                .font(.subheadline)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
