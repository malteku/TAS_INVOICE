import SwiftUI
import Charts

struct DashboardView: View {

    @EnvironmentObject var workoutsVM: WorkoutsViewModel
    @EnvironmentObject var aiVM: AIAnalysisViewModel
    @State private var showFormSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    periodPicker
                    formCard
                    statsGrid
                    weeklyChart
                    recentWorkoutsList
                }
                .padding()
            }
            .navigationTitle("CyclingCoach")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "person.circle")
                    }
                }
            }
            .task { await workoutsVM.loadWorkouts() }
            .sheet(isPresented: $showFormSheet) { FormAssessmentSheet() }
        }
    }

    // MARK: - Subviews

    private var periodPicker: some View {
        Picker("Zeitraum", selection: $workoutsVM.selectedPeriod) {
            ForEach([AnalyticsPeriod.week, .month, .quarter, .year], id: \.self) {
                Text($0.rawValue).tag($0)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: workoutsVM.selectedPeriod) { _, _ in workoutsVM.updateSummary() }
    }

    private var formCard: some View {
        Button { showFormSheet = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aktuelle Form").font(.headline)
                    if let s = workoutsVM.fitnessSummary {
                        HStack(spacing: 16) {
                            FormBadge(label: "Fitness", value: s.fitnessScore, color: .blue)
                            FormBadge(label: "Ermüdung", value: s.fatigueScore, color: .orange)
                            FormBadge(label: "Form", value: s.formScore, color: formColor(s.formScore))
                        }
                    }
                }
                Spacer()
                Image(systemName: "brain")
                    .font(.title2)
                    .foregroundStyle(.purple)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let s = workoutsVM.fitnessSummary {
                StatCard(title: "Trainings", value: "\(s.totalWorkouts)", unit: "", icon: "bicycle", color: .green)
                StatCard(title: "Distanz", value: String(format: "%.0f", s.totalDistanceKm), unit: "km", icon: "map", color: .blue)
                StatCard(title: "Zeit", value: String(format: "%.1f", s.totalDurationHours), unit: "h", icon: "clock", color: .orange)
                StatCard(title: "Höhenmeter", value: String(format: "%.0f", s.totalElevationM), unit: "m", icon: "mountain.2", color: .red)
            }
        }
    }

    @ViewBuilder
    private var weeklyChart: some View {
        if let s = workoutsVM.fitnessSummary, !s.weeklyTSSValues.isEmpty {
            VStack(alignment: .leading) {
                Text("Wöchentlicher Trainingsstress (TSS)")
                    .font(.headline)
                Chart {
                    ForEach(Array(s.weeklyTSSValues.enumerated()), id: \.offset) { i, tss in
                        BarMark(
                            x: .value("Woche", "W\(i + 1)"),
                            y: .value("TSS", tss)
                        )
                        .foregroundStyle(Color.blue.gradient)
                    }
                }
                .frame(height: 160)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var recentWorkoutsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Letzte Trainings")
                .font(.headline)
            ForEach(workoutsVM.sortedWorkouts.prefix(5)) { workout in
                NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                    WorkoutRowView(workout: workout)
                }
                .buttonStyle(.plain)
            }
            if workoutsVM.isLoading {
                ProgressView("Lade Health-Daten...")
                    .frame(maxWidth: .infinity)
            }
            if let err = workoutsVM.error {
                Label(err, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    private func formColor(_ form: Double) -> Color {
        switch form {
        case 10...:  return .green
        case -10..<10: return .yellow
        default:     return .red
        }
    }
}

// MARK: - Helper Views

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.title2).fontWeight(.bold)
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FormBadge: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%.0f", value))
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct WorkoutRowView: View {
    let workout: CyclingWorkout

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 12) {
                    Label(workout.formattedDuration, systemImage: "clock")
                    Label(String(format: "%.1f km", workout.distanceKm), systemImage: "map")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let pwr = workout.avgPower {
                    Text("\(Int(pwr))W").font(.headline).foregroundStyle(.orange)
                }
                if let hr = workout.avgHeartRate {
                    Text("\(Int(hr))♥").font(.caption).foregroundStyle(.red)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FormAssessmentSheet: View {
    @EnvironmentObject var workoutsVM: WorkoutsViewModel
    @EnvironmentObject var aiVM: AIAnalysisViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if aiVM.isLoading {
                        ProgressView("Claude analysiert deine Form...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let text = aiVM.formAssessment {
                        MarkdownTextView(text: text)
                    } else {
                        ContentUnavailableView(
                            "Form analysieren",
                            systemImage: "brain",
                            description: Text("Claude bewertet deinen aktuellen Trainingsstatus.")
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Heutige Form")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Analysieren") {
                        Task { await aiVM.checkCurrentForm(workouts: workoutsVM.workouts) }
                    }
                    .disabled(aiVM.isLoading)
                }
            }
        }
        .task { await aiVM.checkCurrentForm(workouts: workoutsVM.workouts) }
    }
}
