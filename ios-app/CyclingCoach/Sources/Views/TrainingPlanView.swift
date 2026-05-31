import SwiftUI

struct TrainingPlanView: View {

    @EnvironmentObject var planVM: TrainingPlanViewModel
    @EnvironmentObject var workoutsVM: WorkoutsViewModel
    @State private var showGenerator = false

    var body: some View {
        NavigationStack {
            Group {
                if planVM.plans.isEmpty {
                    emptyState
                } else {
                    planList
                }
            }
            .navigationTitle("Trainingspläne")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showGenerator = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showGenerator) {
                PlanGeneratorSheet()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Noch kein Trainingsplan",
            systemImage: "calendar.badge.plus",
            description: Text("Lass Claude einen personalisierten Plan basierend auf deiner Trainingshistorie erstellen.")
        ) {
            Button("Plan erstellen") { showGenerator = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var planList: some View {
        List {
            if let active = planVM.activePlan {
                Section("Aktiver Plan") {
                    NavigationLink(destination: PlanDetailView(plan: active)) {
                        PlanRow(plan: active, isActive: true)
                    }
                }
            }
            if planVM.plans.count > 1 {
                Section("Frühere Pläne") {
                    ForEach(planVM.plans.dropFirst()) { plan in
                        NavigationLink(destination: PlanDetailView(plan: plan)) {
                            PlanRow(plan: plan, isActive: false)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Plan Row

struct PlanRow: View {
    let plan: TrainingPlan
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(plan.title).fontWeight(.semibold)
                Spacer()
                if isActive {
                    Label("Aktiv", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            HStack(spacing: 12) {
                Label("\(plan.durationWeeks) Wochen", systemImage: "calendar")
                Label(plan.createdAt.formatted(date: .abbreviated, time: .omitted), systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Plan Detail

struct PlanDetailView: View {
    let plan: TrainingPlan

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Plan-Header
                VStack(alignment: .leading, spacing: 8) {
                    Label(plan.goal.rawValue, systemImage: "target")
                        .font(.headline)
                    HStack {
                        Label("\(plan.durationWeeks) Wochen", systemImage: "calendar")
                        Spacer()
                        Label(plan.createdAt.formatted(date: .long, time: .omitted), systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.blue.gradient.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Claude-generierter Plan
                VStack(alignment: .leading, spacing: 8) {
                    Label("KI-generierter Plan", systemImage: "brain")
                        .font(.headline)
                        .foregroundStyle(.purple)
                    MarkdownTextView(text: plan.claudeAnalysis)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Plan Generator Sheet

struct PlanGeneratorSheet: View {

    @EnvironmentObject var planVM: TrainingPlanViewModel
    @EnvironmentObject var workoutsVM: WorkoutsViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedGoal: TrainingGoal = .endurance
    @State private var durationWeeks = 8
    @State private var showResult = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Trainingsziel") {
                    Picker("Ziel", selection: $selectedGoal) {
                        ForEach(TrainingGoal.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Planungsdauer") {
                    Stepper("\(durationWeeks) Wochen", value: $durationWeeks, in: 4...24, step: 2)
                }

                Section("Basis") {
                    HStack {
                        Text("Trainings einbezogen")
                        Spacer()
                        Text("\(workoutsVM.workouts.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                if planVM.isGenerating {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Claude erstellt deinen Plan...")
                                .padding(.leading, 8)
                        }
                    }
                }

                if let err = planVM.error {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Plan erstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Erstellen") {
                        Task {
                            await planVM.generatePlan(
                                goal: selectedGoal,
                                weeks: durationWeeks,
                                workouts: workoutsVM.workouts
                            )
                            if planVM.error == nil { dismiss() }
                        }
                    }
                    .disabled(planVM.isGenerating)
                    .fontWeight(.bold)
                }
            }
        }
    }
}
