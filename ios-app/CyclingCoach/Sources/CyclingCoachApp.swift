import SwiftUI

@main
struct CyclingCoachApp: App {

    @StateObject private var workoutsVM   = WorkoutsViewModel()
    @StateObject private var planVM       = TrainingPlanViewModel()
    @StateObject private var aiVM         = AIAnalysisViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutsVM)
                .environmentObject(planVM)
                .environmentObject(aiVM)
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }

            WorkoutsListView()
                .tabItem {
                    Label("Trainings", systemImage: "bicycle")
                }

            AnalysisView()
                .tabItem {
                    Label("KI-Analyse", systemImage: "brain")
                }

            TrainingPlanView()
                .tabItem {
                    Label("Plan", systemImage: "calendar.badge.plus")
                }
        }
        .tint(.blue)
    }
}
