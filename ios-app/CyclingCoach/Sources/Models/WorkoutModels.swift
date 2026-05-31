import Foundation
import HealthKit

// MARK: - Core Workout Model

struct CyclingWorkout: Identifiable, Codable {
    let id: UUID
    let date: Date
    let duration: TimeInterval        // Sekunden
    let distanceKm: Double
    let avgHeartRate: Double?
    let maxHeartRate: Double?
    let avgPower: Double?             // Watt (wenn Leistungsmesser vorhanden)
    let maxPower: Double?
    let avgCadence: Double?
    let elevationGainM: Double?
    let calories: Double?
    let avgSpeedKmh: Double
    let source: String                // z.B. "Garmin", "Apple Watch"

    // Berechnete Felder
    var tss: Double? {                // Training Stress Score (benötigt FTP)
        guard let power = avgPower, let ftp = UserProfile.current?.ftp else { return nil }
        let intensityFactor = power / ftp
        let tssValue = (duration / 3600) * intensityFactor * intensityFactor * 100
        return tssValue
    }

    var intensityZone: TrainingZone? {
        guard let hr = avgHeartRate, let zones = UserProfile.current?.heartRateZones else { return nil }
        return zones.zone(for: hr)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)min" : "\(minutes)min"
    }
}

// MARK: - Training Zones

struct HeartRateZones: Codable {
    var zone1Max: Double   // Erholung
    var zone2Max: Double   // Grundlage
    var zone3Max: Double   // Tempo
    var zone4Max: Double   // Schwelle
    var zone5Max: Double   // VO2max

    func zone(for heartRate: Double) -> TrainingZone {
        switch heartRate {
        case ..<zone1Max: return .recovery
        case ..<zone2Max: return .endurance
        case ..<zone3Max: return .tempo
        case ..<zone4Max: return .threshold
        default:          return .vo2max
        }
    }
}

enum TrainingZone: String, Codable, CaseIterable {
    case recovery   = "Z1 Erholung"
    case endurance  = "Z2 Grundlage"
    case tempo      = "Z3 Tempo"
    case threshold  = "Z4 Schwelle"
    case vo2max     = "Z5 VO2max"

    var color: String {
        switch self {
        case .recovery:  return "blue"
        case .endurance: return "green"
        case .tempo:     return "yellow"
        case .threshold: return "orange"
        case .vo2max:    return "red"
        }
    }
}

// MARK: - User Profile

class UserProfile: ObservableObject, Codable {
    static var current: UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: "userProfile"),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else { return nil }
        return profile
    }

    @Published var name: String
    @Published var birthYear: Int
    @Published var restingHeartRate: Double?
    @Published var maxHeartRate: Double?
    @Published var ftp: Double?           // Functional Threshold Power in Watt
    @Published var weight: Double?        // kg
    @Published var claudeApiKey: String

    var heartRateZones: HeartRateZones? {
        guard let max = maxHeartRate else { return nil }
        return HeartRateZones(
            zone1Max: max * 0.60,
            zone2Max: max * 0.70,
            zone3Max: max * 0.80,
            zone4Max: max * 0.90,
            zone5Max: max
        )
    }

    var age: Int { Calendar.current.component(.year, from: Date()) - birthYear }

    init(name: String = "", birthYear: Int = 1990, claudeApiKey: String = "") {
        self.name = name
        self.birthYear = birthYear
        self.claudeApiKey = claudeApiKey
    }

    // Codable
    enum CodingKeys: String, CodingKey {
        case name, birthYear, restingHeartRate, maxHeartRate, ftp, weight, claudeApiKey
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        birthYear = try c.decode(Int.self, forKey: .birthYear)
        restingHeartRate = try c.decodeIfPresent(Double.self, forKey: .restingHeartRate)
        maxHeartRate = try c.decodeIfPresent(Double.self, forKey: .maxHeartRate)
        ftp = try c.decodeIfPresent(Double.self, forKey: .ftp)
        weight = try c.decodeIfPresent(Double.self, forKey: .weight)
        claudeApiKey = try c.decode(String.self, forKey: .claudeApiKey)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(birthYear, forKey: .birthYear)
        try c.encodeIfPresent(restingHeartRate, forKey: .restingHeartRate)
        try c.encodeIfPresent(maxHeartRate, forKey: .maxHeartRate)
        try c.encodeIfPresent(ftp, forKey: .ftp)
        try c.encodeIfPresent(weight, forKey: .weight)
        try c.encode(claudeApiKey, forKey: .claudeApiKey)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "userProfile")
        }
    }
}

// MARK: - Training Plan

struct TrainingPlan: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let title: String
    let goal: TrainingGoal
    let durationWeeks: Int
    let weeks: [TrainingWeek]
    let claudeAnalysis: String        // AI-generierte Begründung

    var currentWeek: TrainingWeek? {
        let weeksSinceStart = Calendar.current.dateComponents([.weekOfYear], from: createdAt, to: Date()).weekOfYear ?? 0
        guard weeksSinceStart < weeks.count else { return nil }
        return weeks[weeksSinceStart]
    }
}

struct TrainingWeek: Identifiable, Codable {
    let id: UUID
    let weekNumber: Int
    let targetTSS: Double
    let sessions: [PlannedSession]
    let focus: String
}

struct PlannedSession: Identifiable, Codable {
    let id: UUID
    let dayOfWeek: Int               // 1=Mo, 7=So
    let type: SessionType
    let durationMin: Int
    let targetZone: TrainingZone
    let description: String
}

enum SessionType: String, Codable {
    case endurance    = "Grundlage"
    case intervals    = "Intervalle"
    case recovery     = "Erholung"
    case threshold    = "Schwellentraining"
    case race         = "Wettkampf"
    case rest         = "Ruhetag"
}

enum TrainingGoal: String, Codable, CaseIterable {
    case generalFitness  = "Allgemeine Fitness"
    case endurance       = "Ausdauer aufbauen"
    case thresholdPower  = "FTP verbessern"
    case weightLoss      = "Gewichtsreduktion"
    case racePrep        = "Wettkampfvorbereitung"
}

// MARK: - Analytics Summary

struct FitnessSummary: Codable {
    let period: AnalyticsPeriod
    let totalWorkouts: Int
    let totalDistanceKm: Double
    let totalDurationHours: Double
    let totalElevationM: Double
    let avgHeartRate: Double?
    let weeklyTSSValues: [Double]
    let zonDistribution: [TrainingZone: Double]   // Prozent
    let fitnessScore: Double                       // 0-100, basierend auf CTL
    let fatigueScore: Double                       // 0-100, basierend auf ATL
    let formScore: Double                          // TSB = CTL - ATL
}

enum AnalyticsPeriod: String, Codable {
    case week  = "7 Tage"
    case month = "30 Tage"
    case quarter = "90 Tage"
    case year  = "1 Jahr"

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
}
