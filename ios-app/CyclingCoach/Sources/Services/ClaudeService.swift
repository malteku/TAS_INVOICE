import Foundation

// MARK: - Claude API Service (Anthropic API)
// Erfordert einen API-Key von console.anthropic.com
// Kosten: ~$3/Million Input-Tokens (Claude Sonnet 4)
// Free-Tier: Begrenztes Guthaben zum Testen verfügbar

@MainActor
class ClaudeService: ObservableObject {

    static let shared = ClaudeService()

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model   = "claude-sonnet-4-6"
    private let version = "2023-06-01"

    @Published var isLoading = false
    @Published var error: String?

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "claudeApiKey") ?? ""
    }

    // MARK: - Training Analysis

    func analyzeTrainingHistory(_ workouts: [CyclingWorkout], profile: UserProfile) async throws -> String {
        let summary = buildWorkoutSummary(workouts, profile: profile)
        let prompt = """
        Du bist ein professioneller Radsport-Coach mit Expertise in Leistungsdiagnostik und Trainingssteuerung.

        Analysiere die folgende Trainingshistorie eines Rennradfahrers und gib eine fundierte, strukturierte Auswertung:

        \(summary)

        Bitte analysiere:
        1. **Trainingsvolumen & Kontinuität** - Ist das Volumen angemessen?
        2. **Intensitätsverteilung** - 80/20-Regel (Polarisierung) eingehalten?
        3. **Progression** - Erkennbare Fitness-Entwicklung?
        4. **Stärken & Schwächen** - Was läuft gut, was sollte verbessert werden?
        5. **Regeneration** - Ausreichende Erholung zwischen Einheiten?
        6. **Empfehlungen** - 3 konkrete, sofort umsetzbare Verbesserungen

        Antworte auf Deutsch, präzise und umsetzbar. Nutze Markdown für Struktur.
        """

        return try await sendMessage(prompt)
    }

    // MARK: - Training Plan Generation

    func generateTrainingPlan(
        goal: TrainingGoal,
        durationWeeks: Int,
        workouts: [CyclingWorkout],
        profile: UserProfile
    ) async throws -> String {
        let history = buildWorkoutSummary(workouts.prefix(20).map { $0 }, profile: profile)
        let prompt = """
        Du bist ein professioneller Radsport-Coach. Erstelle einen detaillierten \(durationWeeks)-Wochen-Trainingsplan.

        **Ziel:** \(goal.rawValue)
        **Athlet:** \(profile.name), \(profile.age) Jahre
        \(profile.ftp.map { "**FTP:** \($0) Watt" } ?? "")
        \(profile.maxHeartRate.map { "**Max. HF:** \($0) bpm" } ?? "")
        \(profile.weight.map { "**Gewicht:** \($0) kg" } ?? "")

        **Aktuelle Trainingshistorie:**
        \(history)

        Erstelle den Plan im folgenden Format für jede Woche:

        ## Woche X: [Fokus]
        - **Montag:** [Einheit / Ruhetag]
        - **Dienstag:** [Einheit]
        - **Mittwoch:** [Einheit]
        - **Donnerstag:** [Einheit]
        - **Freitag:** [Einheit]
        - **Samstag:** [Haupteinheit]
        - **Sonntag:** [Einheit / Ruhetag]
        - **Wochen-TSS:** [Ziel]
        - **Fokus:** [Begründung]

        Berücksichtige:
        - Progressive Belastungssteigerung (3:1 Belastungs-/Erholungsrhythmus)
        - Spezifität zum Ziel (\(goal.rawValue))
        - Realistische Umsetzbarkeit (Hobbyathlet)
        - Herzfrequenz- oder Leistungszonen für jede Einheit

        Antworte ausschließlich auf Deutsch.
        """

        return try await sendMessage(prompt)
    }

    // MARK: - Workout Analysis

    func analyzeWorkout(_ workout: CyclingWorkout) async throws -> String {
        let prompt = """
        Analysiere folgendes Rennrad-Training und gib kurzes, prägnantes Feedback (max. 200 Wörter):

        - **Datum:** \(workout.date.formatted(date: .long, time: .omitted))
        - **Dauer:** \(workout.formattedDuration)
        - **Distanz:** \(String(format: "%.1f", workout.distanceKm)) km
        - **Avg. Geschwindigkeit:** \(String(format: "%.1f", workout.avgSpeedKmh)) km/h
        \(workout.avgHeartRate.map { "- **Avg. HF:** \(Int($0)) bpm" } ?? "")
        \(workout.maxHeartRate.map { "- **Max. HF:** \(Int($0)) bpm" } ?? "")
        \(workout.avgPower.map { "- **Avg. Leistung:** \(Int($0)) Watt" } ?? "")
        \(workout.maxPower.map { "- **Max. Leistung:** \(Int($0)) Watt" } ?? "")
        \(workout.avgCadence.map { "- **Avg. Kadenz:** \(Int($0)) rpm" } ?? "")
        \(workout.elevationGainM.map { "- **Höhenmeter:** \(Int($0)) m" } ?? "")
        \(workout.calories.map { "- **Kalorien:** \(Int($0)) kcal" } ?? "")
        \(workout.tss.map { "- **TSS:** \(Int($0))" } ?? "")

        Bewerte: Qualität, Intensität, Empfehlung für nächste Einheit. Antworte auf Deutsch.
        """

        return try await sendMessage(prompt)
    }

    // MARK: - Form & Recovery Check

    func assessCurrentForm(summary: FitnessSummary, profile: UserProfile) async throws -> String {
        let prompt = """
        Bewerte die aktuelle Trainingsform und Erholungsstatus des Athleten:

        **Fitness (CTL):** \(String(format: "%.0f", summary.fitnessScore))
        **Ermüdung (ATL):** \(String(format: "%.0f", summary.fatigueScore))
        **Form (TSB):** \(String(format: "%.0f", summary.formScore))

        **Letzte \(summary.period.rawValue):**
        - Trainings: \(summary.totalWorkouts)
        - Distanz: \(String(format: "%.0f", summary.totalDistanceKm)) km
        - Stunden: \(String(format: "%.1f", summary.totalDurationHours)) h
        \(summary.avgHeartRate.map { "- Avg. HF: \(Int($0)) bpm" } ?? "")

        Gib eine kurze Einschätzung (max. 150 Wörter):
        1. Ist heute ein guter Tag zum Trainieren?
        2. Welche Intensität ist sinnvoll?
        3. Ein konkreter Tipp für heute

        Antworte auf Deutsch, direkt und umsetzbar.
        """

        return try await sendMessage(prompt)
    }

    // MARK: - Multi-Turn Chat (für ChatViewModel)

    func sendChatMessage(
        _ userMessage: String,
        history: [ChatMessage],
        systemPrompt: String
    ) async throws -> String {
        var apiMessages: [[String: String]] = history.map {
            ["role": $0.role.rawValue, "content": $0.content]
        }
        apiMessages.append(["role": "user", "content": userMessage])
        return try await sendMessages(apiMessages, system: systemPrompt)
    }

    // MARK: - Private API Calls

    private func sendMessage(_ content: String) async throws -> String {
        try await sendMessages([["role": "user", "content": content]], system: nil)
    }

    private func sendMessages(_ messages: [[String: String]], system: String?) async throws -> String {
        guard !apiKey.isEmpty else {
            throw ClaudeError.noApiKey
        }

        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(version, forHTTPHeaderField: "anthropic-version")

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "messages": messages
        ]
        if let system { body["system"] = system }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.networkError("Ungültige Antwort vom Server")
        }

        if httpResponse.statusCode == 401 {
            throw ClaudeError.invalidApiKey
        }

        if httpResponse.statusCode == 429 {
            throw ClaudeError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unbekannter Fehler"
            throw ClaudeError.apiError(httpResponse.statusCode, msg)
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return decoded.content.first?.text ?? ""
    }

    // MARK: - Prompt Builder

    private func buildWorkoutSummary(_ workouts: [CyclingWorkout], profile: UserProfile) -> String {
        let last = workouts.prefix(10)
        var lines = [
            "Athlet: \(profile.name), \(profile.age) Jahre",
            profile.ftp.map { "FTP: \($0) Watt" } ?? "",
            profile.maxHeartRate.map { "Max HF: \($0) bpm" } ?? "",
            "",
            "Letzte \(last.count) Trainings:"
        ].filter { !$0.isEmpty }

        for w in last {
            var line = "- \(w.date.formatted(date: .abbreviated, time: .omitted)): \(w.formattedDuration), \(String(format: "%.0f", w.distanceKm))km"
            if let hr = w.avgHeartRate { line += ", \(Int(hr))bpm" }
            if let pwr = w.avgPower { line += ", \(Int(pwr))W" }
            if let tss = w.tss { line += ", TSS:\(Int(tss))" }
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Response Models

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let type: String
        let text: String
    }
}

enum ClaudeError: LocalizedError {
    case noApiKey
    case invalidApiKey
    case rateLimited
    case networkError(String)
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "Kein API-Key konfiguriert. Bitte in den Einstellungen eintragen."
        case .invalidApiKey:
            return "Ungültiger API-Key. Bitte in den Einstellungen überprüfen."
        case .rateLimited:
            return "API-Limit erreicht. Bitte kurz warten."
        case .networkError(let msg):
            return "Netzwerkfehler: \(msg)"
        case .apiError(let code, let msg):
            return "API-Fehler (\(code)): \(msg)"
        }
    }
}
