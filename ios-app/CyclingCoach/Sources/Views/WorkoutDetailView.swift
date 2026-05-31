import SwiftUI

struct WorkoutDetailView: View {

    let workout: CyclingWorkout
    @EnvironmentObject var aiVM: AIAnalysisViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                metricsGrid
                if let zone = workout.intensityZone {
                    zoneCard(zone)
                }
                aiSection
            }
            .padding()
        }
        .navigationTitle(workout.date.formatted(date: .long, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        HStack(spacing: 24) {
            VStack {
                Text(String(format: "%.1f", workout.distanceKm))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text("km").font(.title3).foregroundStyle(.secondary)
            }
            Divider().frame(height: 60)
            VStack {
                Text(workout.formattedDuration)
                    .font(.title).fontWeight(.bold)
                Text("Dauer").font(.caption).foregroundStyle(.secondary)
            }
            Divider().frame(height: 60)
            VStack {
                Text(String(format: "%.1f", workout.avgSpeedKmh))
                    .font(.title).fontWeight(.bold)
                Text("km/h ø").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.gradient.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let hr = workout.avgHeartRate {
                MetricTile(label: "Ø Herzfrequenz", value: "\(Int(hr))", unit: "bpm",
                           icon: "heart.fill", color: .red)
            }
            if let maxHr = workout.maxHeartRate {
                MetricTile(label: "Max Herzfrequenz", value: "\(Int(maxHr))", unit: "bpm",
                           icon: "heart.fill", color: .red)
            }
            if let pwr = workout.avgPower {
                MetricTile(label: "Ø Leistung", value: "\(Int(pwr))", unit: "W",
                           icon: "bolt.fill", color: .orange)
            }
            if let maxPwr = workout.maxPower {
                MetricTile(label: "Max Leistung", value: "\(Int(maxPwr))", unit: "W",
                           icon: "bolt.fill", color: .orange)
            }
            if let cad = workout.avgCadence {
                MetricTile(label: "Ø Kadenz", value: "\(Int(cad))", unit: "rpm",
                           icon: "arrow.clockwise", color: .green)
            }
            if let elev = workout.elevationGainM {
                MetricTile(label: "Höhenmeter", value: "\(Int(elev))", unit: "m",
                           icon: "mountain.2.fill", color: .purple)
            }
            if let cal = workout.calories {
                MetricTile(label: "Kalorien", value: "\(Int(cal))", unit: "kcal",
                           icon: "flame.fill", color: .yellow)
            }
            if let tss = workout.tss {
                MetricTile(label: "TSS", value: "\(Int(tss))", unit: "",
                           icon: "chart.bar.fill", color: .blue)
            }
        }
    }

    private func zoneCard(_ zone: TrainingZone) -> some View {
        HStack {
            Image(systemName: "speedometer")
            Text("Trainingszone: \(zone.rawValue)")
                .fontWeight(.medium)
            Spacer()
            Text("Quelle: \(workout.source)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(zoneColor(zone).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain")
                    .foregroundStyle(.purple)
                Text("Claude Analyse")
                    .font(.headline)
                Spacer()
                Button("Analysieren") {
                    Task { await aiVM.analyzeWorkout(workout) }
                }
                .buttonStyle(.bordered)
                .disabled(aiVM.isLoading)
            }

            if aiVM.isLoading {
                ProgressView("Analysiere Training...")
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if let feedback = aiVM.workoutFeedback {
                MarkdownTextView(text: feedback)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Tippe auf 'Analysieren' für KI-Feedback zu diesem Training.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let err = aiVM.error {
                Label(err, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    private func zoneColor(_ zone: TrainingZone) -> Color {
        switch zone {
        case .recovery:  return .blue
        case .endurance: return .green
        case .tempo:     return .yellow
        case .threshold: return .orange
        case .vo2max:    return .red
        }
    }
}

struct MetricTile: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(color)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
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
