import Foundation
import HealthKit

@MainActor
class HealthKitService: ObservableObject {

    static let shared = HealthKitService()
    private let store = HKHealthStore()

    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var error: String?

    private let readTypes: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.heartRate),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.cyclingCadence),
        HKQuantityType(.cyclingPower),
        HKQuantityType(.cyclingSpeed),
        HKQuantityType(.flightsClimbed),
        HKQuantityType(.bodyMass),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.vo2Max),
        HKSeriesType.workoutRoute()
    ]

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthError.notAvailable
        }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
    }

    // MARK: - Workouts laden

    func fetchCyclingWorkouts(from startDate: Date, to endDate: Date = Date()) async throws -> [CyclingWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let activityPredicate = HKQuery.predicateForWorkouts(with: .cycling)
        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, activityPredicate])

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: compound,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }

        var results: [CyclingWorkout] = []
        for workout in workouts {
            let cycling = try await buildCyclingWorkout(from: workout)
            results.append(cycling)
        }
        return results
    }

    // MARK: - Workout-Details aufbauen

    private func buildCyclingWorkout(from workout: HKWorkout) async throws -> CyclingWorkout {
        async let hr   = fetchWorkoutStats(workout, type: .heartRate, unit: .count().unitDivided(by: .minute()))
        async let pwr  = fetchWorkoutStats(workout, type: .cyclingPower, unit: .watt())
        async let cad  = fetchWorkoutStats(workout, type: .cyclingCadence, unit: .count().unitDivided(by: .minute()))

        let (heartRateStats, powerStats, cadenceStats) = try await (hr, pwr, cad)

        let distance = workout.statistics(for: HKQuantityType(.distanceCycling))?
            .sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0

        let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0

        let elevation = workout.statistics(for: HKQuantityType(.flightsClimbed))?
            .sumQuantity()?.doubleValue(for: .count())

        let duration = workout.duration
        let avgSpeed = duration > 0 ? (distance / (duration / 3600)) : 0

        let source = workout.sourceRevision.source.name

        return CyclingWorkout(
            id: workout.uuid,
            date: workout.startDate,
            duration: duration,
            distanceKm: distance,
            avgHeartRate: heartRateStats?.averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())),
            maxHeartRate: heartRateStats?.maximumQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())),
            avgPower: powerStats?.averageQuantity()?.doubleValue(for: .watt()),
            maxPower: powerStats?.maximumQuantity()?.doubleValue(for: .watt()),
            avgCadence: cadenceStats?.averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())),
            elevationGainM: elevation.map { $0 * 3 },  // Näherung: 1 Etage ≈ 3m
            calories: calories,
            avgSpeedKmh: avgSpeed,
            source: source
        )
    }

    private func fetchWorkoutStats(
        _ workout: HKWorkout,
        type: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> HKStatistics? {
        let quantityType = HKQuantityType(type)
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage, .discreteMax]
            ) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: stats)
            }
            store.execute(query)
        }
    }

    // MARK: - Körperdaten

    func fetchLatestBodyMass() async -> Double? {
        let type = HKQuantityType(.bodyMass)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                let kg = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }

    func fetchRestingHeartRate() async -> Double? {
        let type = HKQuantityType(.restingHeartRate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                let bpm = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .count().unitDivided(by: .minute()))
                continuation.resume(returning: bpm)
            }
            store.execute(query)
        }
    }

    func fetchVO2Max() async -> Double? {
        let type = HKQuantityType(.vo2Max)
        let unit = HKUnit.literUnit(with: .milli)
            .unitDivided(by: HKUnit.gramUnit(with: .kilo)
            .unitMultiplied(by: HKUnit.minute()))
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                let vo2 = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: vo2)
            }
            store.execute(query)
        }
    }

    // MARK: - Fitness Summary berechnen

    func computeFitnessSummary(workouts: [CyclingWorkout], period: AnalyticsPeriod) -> FitnessSummary {
        let cutoff = Calendar.current.date(byAdding: .day, value: -period.days, to: Date())!
        let filtered = workouts.filter { $0.date >= cutoff }

        let totalDist = filtered.reduce(0) { $0 + $1.distanceKm }
        let totalDur  = filtered.reduce(0) { $0 + $1.duration } / 3600
        let totalElev = filtered.compactMap(\.elevationGainM).reduce(0, +)
        let hrValues  = filtered.compactMap(\.avgHeartRate)
        let avgHR     = hrValues.isEmpty ? nil : hrValues.reduce(0, +) / Double(hrValues.count)

        // CTL (Chronic Training Load) = 42-Tage-EWA des TSS
        // ATL (Acute Training Load) = 7-Tage-EWA des TSS
        let ctl = computeEWA(workouts: workouts, days: 42)
        let atl = computeEWA(workouts: workouts, days: 7)

        // Wöchentliche TSS-Werte
        let weeklyTSS = computeWeeklyTSS(workouts: filtered)

        // Herzfrequenzverteilung
        var zoneDist: [TrainingZone: Double] = [:]
        if let zones = UserProfile.current?.heartRateZones {
            for zone in TrainingZone.allCases {
                let count = filtered.filter { w in
                    guard let hr = w.avgHeartRate else { return false }
                    return zones.zone(for: hr) == zone
                }.count
                zoneDist[zone] = filtered.isEmpty ? 0 : Double(count) / Double(filtered.count) * 100
            }
        }

        return FitnessSummary(
            period: period,
            totalWorkouts: filtered.count,
            totalDistanceKm: totalDist,
            totalDurationHours: totalDur,
            totalElevationM: totalElev,
            avgHeartRate: avgHR,
            weeklyTSSValues: weeklyTSS,
            zonDistribution: zoneDist,
            fitnessScore: min(ctl, 100),
            fatigueScore: min(atl, 100),
            formScore: ctl - atl
        )
    }

    private func computeEWA(workouts: [CyclingWorkout], days: Int) -> Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days * 2, to: Date())!
        let recent = workouts.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        let decay = 2.0 / (Double(days) + 1.0)
        var ewa = 0.0
        for w in recent {
            let tss = w.tss ?? (w.duration / 3600 * 50) // Schätzung ohne FTP
            ewa = tss * decay + ewa * (1 - decay)
        }
        return ewa
    }

    private func computeWeeklyTSS(workouts: [CyclingWorkout]) -> [Double] {
        var weekly: [Int: Double] = [:]
        let cal = Calendar.current
        for w in workouts {
            let week = cal.component(.weekOfYear, from: w.date)
            let tss = w.tss ?? (w.duration / 3600 * 50)
            weekly[week, default: 0] += tss
        }
        return weekly.sorted { $0.key < $1.key }.map(\.value)
    }
}

enum HealthError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case noData

    var errorDescription: String? {
        switch self {
        case .notAvailable:        return "HealthKit ist auf diesem Gerät nicht verfügbar."
        case .authorizationDenied: return "Zugriff auf Health-Daten verweigert."
        case .noData:              return "Keine Rennrad-Trainings gefunden."
        }
    }
}
