import Foundation
import SwiftUI

@MainActor
class WorkoutsViewModel: ObservableObject {

    @Published var workouts: [CyclingWorkout] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedPeriod: AnalyticsPeriod = .month
    @Published var fitnessSummary: FitnessSummary?

    private let healthKit = HealthKitService.shared

    func loadWorkouts() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            if !healthKit.isAuthorized {
                try await healthKit.requestAuthorization()
            }
            let startDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
            workouts = try await healthKit.fetchCyclingWorkouts(from: startDate)
            updateSummary()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateSummary() {
        fitnessSummary = healthKit.computeFitnessSummary(workouts: workouts, period: selectedPeriod)
    }

    var sortedWorkouts: [CyclingWorkout] {
        workouts.sorted { $0.date > $1.date }
    }

    var recentWorkouts: [CyclingWorkout] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: Date())!
        return workouts.filter { $0.date >= cutoff }
    }

    // Statistiken für Dashboard
    var totalDistanceAllTime: Double {
        workouts.reduce(0) { $0 + $1.distanceKm }
    }

    var totalHoursAllTime: Double {
        workouts.reduce(0) { $0 + $1.duration } / 3600
    }

    var longestRide: CyclingWorkout? {
        workouts.max { $0.distanceKm < $1.distanceKm }
    }

    var bestPower: Double? {
        workouts.compactMap(\.maxPower).max()
    }
}

// MARK: - Training Plan ViewModel

@MainActor
class TrainingPlanViewModel: ObservableObject {

    @Published var plans: [TrainingPlan] = []
    @Published var activePlan: TrainingPlan?
    @Published var isGenerating = false
    @Published var generatedPlanText: String?
    @Published var error: String?

    private let claude = ClaudeService.shared

    init() {
        loadSavedPlans()
    }

    func generatePlan(goal: TrainingGoal, weeks: Int, workouts: [CyclingWorkout]) async {
        guard let profile = UserProfile.current else {
            error = "Bitte erst Profil ausfüllen."
            return
        }
        isGenerating = true
        error = nil
        defer { isGenerating = false }

        do {
            let text = try await claude.generateTrainingPlan(
                goal: goal,
                durationWeeks: weeks,
                workouts: workouts,
                profile: profile
            )
            generatedPlanText = text

            // Plan in der Datenbank speichern
            let plan = TrainingPlan(
                id: UUID(),
                createdAt: Date(),
                title: "\(goal.rawValue) – \(weeks) Wochen",
                goal: goal,
                durationWeeks: weeks,
                weeks: [],    // Wird in V2 geparst
                claudeAnalysis: text
            )
            plans.insert(plan, at: 0)
            activePlan = plan
            savePlans()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func savePlans() {
        if let data = try? JSONEncoder().encode(plans) {
            UserDefaults.standard.set(data, forKey: "trainingPlans")
        }
    }

    private func loadSavedPlans() {
        guard let data = UserDefaults.standard.data(forKey: "trainingPlans"),
              let saved = try? JSONDecoder().decode([TrainingPlan].self, from: data) else { return }
        plans = saved
        activePlan = saved.first
    }
}

// MARK: - AI Analysis ViewModel

@MainActor
class AIAnalysisViewModel: ObservableObject {

    @Published var analysisText: String?
    @Published var workoutFeedback: String?
    @Published var formAssessment: String?
    @Published var isLoading = false
    @Published var error: String?

    private let claude = ClaudeService.shared
    private let healthKit = HealthKitService.shared

    func analyzeHistory(workouts: [CyclingWorkout]) async {
        guard let profile = UserProfile.current else {
            error = "Bitte erst Profil ausfüllen."
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            analysisText = try await claude.analyzeTrainingHistory(workouts, profile: profile)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func analyzeWorkout(_ workout: CyclingWorkout) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            workoutFeedback = try await claude.analyzeWorkout(workout)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func checkCurrentForm(workouts: [CyclingWorkout]) async {
        guard let profile = UserProfile.current else { return }
        let summary = healthKit.computeFitnessSummary(workouts: workouts, period: .month)
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            formAssessment = try await claude.assessCurrentForm(summary: summary, profile: profile)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
