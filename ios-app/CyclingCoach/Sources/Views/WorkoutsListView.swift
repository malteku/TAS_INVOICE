import SwiftUI

struct WorkoutsListView: View {

    @EnvironmentObject var workoutsVM: WorkoutsViewModel
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .dateDesc

    var filteredWorkouts: [CyclingWorkout] {
        let sorted = sortedWorkouts
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter {
            $0.date.formatted().localizedStandardContains(searchText) ||
            $0.source.localizedStandardContains(searchText)
        }
    }

    private var sortedWorkouts: [CyclingWorkout] {
        switch sortOrder {
        case .dateDesc:     return workoutsVM.workouts.sorted { $0.date > $1.date }
        case .dateAsc:      return workoutsVM.workouts.sorted { $0.date < $1.date }
        case .distanceDesc: return workoutsVM.workouts.sorted { $0.distanceKm > $1.distanceKm }
        case .durationDesc: return workoutsVM.workouts.sorted { $0.duration > $1.duration }
        case .powerDesc:    return workoutsVM.workouts.sorted { ($0.avgPower ?? 0) > ($1.avgPower ?? 0) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if workoutsVM.isLoading && workoutsVM.workouts.isEmpty {
                    ProgressView("Lade Trainings aus HealthKit...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if workoutsVM.workouts.isEmpty {
                    emptyState
                } else {
                    workoutList
                }
            }
            .navigationTitle("Alle Trainings")
            .searchable(text: $searchText, prompt: "Datum oder Quelle suchen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sortierung", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) {
                                Label($0.label, systemImage: $0.icon).tag($0)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
        }
    }

    private var workoutList: some View {
        List {
            // Monatliche Gruppierung
            ForEach(groupedByMonth, id: \.key) { group in
                Section(group.key) {
                    ForEach(group.value) { workout in
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            WorkoutRowView(workout: workout)
                                .listRowInsets(EdgeInsets())
                                .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            // Gesamt-Statistiken am Ende
            Section("Gesamt") {
                HStack {
                    Label("Trainings", systemImage: "bicycle")
                    Spacer()
                    Text("\(workoutsVM.workouts.count)").fontWeight(.bold)
                }
                HStack {
                    Label("Distanz", systemImage: "map")
                    Spacer()
                    Text(String(format: "%.0f km", workoutsVM.totalDistanceAllTime)).fontWeight(.bold)
                }
                HStack {
                    Label("Zeit", systemImage: "clock")
                    Spacer()
                    Text(String(format: "%.0f h", workoutsVM.totalHoursAllTime)).fontWeight(.bold)
                }
                if let best = workoutsVM.bestPower {
                    HStack {
                        Label("Max Leistung", systemImage: "bolt.fill")
                        Spacer()
                        Text("\(Int(best)) W").fontWeight(.bold).foregroundStyle(.orange)
                    }
                }
                if let longest = workoutsVM.longestRide {
                    HStack {
                        Label("Längste Tour", systemImage: "trophy")
                        Spacer()
                        Text(String(format: "%.0f km", longest.distanceKm)).fontWeight(.bold).foregroundStyle(.yellow)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Keine Rennrad-Trainings",
            systemImage: "bicycle",
            description: Text("Starte ein Training mit deiner Apple Watch oder verbinde Garmin/Wahoo mit der Health App.")
        ) {
            Button("Erneut laden") {
                Task { await workoutsVM.loadWorkouts() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var groupedByMonth: [(key: String, value: [CyclingWorkout])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "de_DE")
        var groups: [String: [CyclingWorkout]] = [:]
        for w in filteredWorkouts {
            let key = formatter.string(from: w.date)
            groups[key, default: []].append(w)
        }
        return groups.sorted { a, b in
            let df = DateFormatter()
            df.dateFormat = "MMMM yyyy"
            df.locale = Locale(identifier: "de_DE")
            return (df.date(from: a.key) ?? Date()) > (df.date(from: b.key) ?? Date())
        }
    }
}

enum SortOrder: String, CaseIterable {
    case dateDesc, dateAsc, distanceDesc, durationDesc, powerDesc

    var label: String {
        switch self {
        case .dateDesc:     return "Neueste zuerst"
        case .dateAsc:      return "Älteste zuerst"
        case .distanceDesc: return "Distanz (abst.)"
        case .durationDesc: return "Dauer (abst.)"
        case .powerDesc:    return "Leistung (abst.)"
        }
    }

    var icon: String {
        switch self {
        case .dateDesc, .dateAsc: return "calendar"
        case .distanceDesc: return "map"
        case .durationDesc: return "clock"
        case .powerDesc: return "bolt"
        }
    }
}
