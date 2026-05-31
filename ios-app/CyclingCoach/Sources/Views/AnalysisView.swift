import SwiftUI

struct AnalysisView: View {

    @EnvironmentObject var aiVM: AIAnalysisViewModel
    @EnvironmentObject var workoutsVM: WorkoutsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    analysisCard
                    if let summary = workoutsVM.fitnessSummary {
                        zoneDistributionCard(summary)
                    }
                }
                .padding()
            }
            .navigationTitle("KI-Analyse")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await aiVM.analyzeHistory(workouts: workoutsVM.workouts) }
                    } label: {
                        Label("Analysieren", systemImage: "brain")
                    }
                    .disabled(aiVM.isLoading)
                }
            }
        }
    }

    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain").foregroundStyle(.purple)
                Text("Trainingsanalyse").font(.headline)
                Spacer()
                if aiVM.isLoading {
                    ProgressView().scaleEffect(0.8)
                }
            }

            if let text = aiVM.analysisText {
                MarkdownTextView(text: text)
            } else if aiVM.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Claude analysiert deine Trainingshistorie...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "brain")
                        .font(.system(size: 40))
                        .foregroundStyle(.purple.opacity(0.5))
                    Text("Tippe auf 'Analysieren' und erhalte eine detaillierte KI-Auswertung deiner kompletten Trainingshistorie.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            }

            if let err = aiVM.error {
                Label(err, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func zoneDistributionCard(_ summary: FitnessSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Herzfrequenz-Verteilung").font(.headline)

            if summary.zonDistribution.isEmpty {
                Text("Benötigt Max. HF-Einstellung im Profil.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(TrainingZone.allCases, id: \.self) { zone in
                    let pct = summary.zonDistribution[zone] ?? 0
                    ZoneBar(zone: zone, percent: pct)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ZoneBar: View {
    let zone: TrainingZone
    let percent: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(zone.rawValue).font(.caption).fontWeight(.medium)
                Spacer()
                Text(String(format: "%.0f%%", percent)).font(.caption).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(zoneColor.gradient)
                        .frame(width: geo.size.width * percent / 100)
                }
            }
            .frame(height: 8)
        }
    }

    private var zoneColor: Color {
        switch zone {
        case .recovery:  return .blue
        case .endurance: return .green
        case .tempo:     return .yellow
        case .threshold: return .orange
        case .vo2max:    return .red
        }
    }
}
