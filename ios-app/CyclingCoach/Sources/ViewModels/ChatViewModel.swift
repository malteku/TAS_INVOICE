import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {

    @Published var conversations: [Conversation] = []
    @Published var activeConversation: Conversation?
    @Published var isTyping = false
    @Published var error: String?
    @Published var inputText = ""

    private let claude = ClaudeService.shared
    private let storageKey = "chatConversations"

    init() { loadConversations() }

    // MARK: - Neue Konversation

    func newConversation(workouts: [CyclingWorkout]) {
        let conv = Conversation(
            id: UUID(),
            title: "Neue Konversation",
            messages: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        conversations.insert(conv, at: 0)
        activeConversation = conversations[0]
        saveConversations()
    }

    // MARK: - Nachricht senden

    func send(workouts: [CyclingWorkout]) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Neue Konversation anlegen falls keine aktiv
        if activeConversation == nil { newConversation(workouts: workouts) }
        guard let idx = conversationIndex() else { return }

        inputText = ""
        error = nil

        // User-Message anhängen
        let userMsg = ChatMessage(role: .user, content: text)
        conversations[idx].messages.append(userMsg)
        conversations[idx].updatedAt = Date()
        activeConversation = conversations[idx]

        // Konversationstitel aus erster Nachricht ableiten
        if conversations[idx].messages.count == 1 {
            conversations[idx].title = String(text.prefix(40))
        }

        isTyping = true
        defer { isTyping = false }

        do {
            let system = buildSystemPrompt(workouts: workouts)
            // Verlauf ohne die soeben hinzugefügte User-Message übergeben
            let history = conversations[idx].messages.dropLast().map { $0 }
            let reply = try await claude.sendChatMessage(text, history: history, systemPrompt: system)

            let assistantMsg = ChatMessage(role: .assistant, content: reply)
            conversations[idx].messages.append(assistantMsg)
            conversations[idx].updatedAt = Date()
            activeConversation = conversations[idx]
            saveConversations()
        } catch {
            self.error = error.localizedDescription
            // User-Message bei Fehler stehen lassen (kann erneut gesendet werden)
        }
    }

    // MARK: - Quick Prompt

    func send(quickPrompt: QuickPrompt, workouts: [CyclingWorkout]) async {
        inputText = quickPrompt.prompt
        await send(workouts: workouts)
    }

    // MARK: - Konversation löschen

    func delete(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        if activeConversation?.id == conversation.id {
            activeConversation = conversations.first
        }
        saveConversations()
    }

    func clearAll() {
        conversations.removeAll()
        activeConversation = nil
        saveConversations()
    }

    // MARK: - System-Prompt mit Trainingsdaten befüllen

    private func buildSystemPrompt(workouts: [CyclingWorkout]) -> String {
        let profile = UserProfile.current
        var context = """
        Du bist ein persönlicher Radsport-Coach und Experte für Trainingssteuerung, Leistungsdiagnostik und Sporternährung. \
        Du antwortest immer auf Deutsch, präzise, freundlich und praxisnah.

        Wenn der Nutzer Fragen zu seinem Training stellt, beziehe dich auf seine konkreten Daten:

        """

        if let p = profile {
            context += "**Athlet:** \(p.name.isEmpty ? "Unbekannt" : p.name), \(p.age) Jahre\n"
            if let ftp = p.ftp   { context += "**FTP:** \(Int(ftp)) Watt\n" }
            if let hr  = p.maxHeartRate { context += "**Max HF:** \(Int(hr)) bpm\n" }
            if let w   = p.weight { context += "**Gewicht:** \(Int(w)) kg\n" }
        }

        if !workouts.isEmpty {
            let recent = workouts.sorted { $0.date > $1.date }.prefix(8)
            let totalKm = workouts.reduce(0) { $0 + $1.distanceKm }
            let totalH  = workouts.reduce(0) { $0 + $1.duration } / 3600
            context += "\n**Trainingshistorie (\(workouts.count) Einheiten, \(Int(totalKm)) km gesamt, \(Int(totalH)) h):**\n"
            for w in recent {
                var line = "- \(w.date.formatted(date: .abbreviated, time: .omitted)): \(w.formattedDuration), \(String(format: "%.0f", w.distanceKm)) km"
                if let hr = w.avgHeartRate  { line += ", \(Int(hr)) bpm" }
                if let pwr = w.avgPower     { line += ", \(Int(pwr)) W" }
                if let tss = w.tss          { line += ", TSS \(Int(tss))" }
                context += line + "\n"
            }
        } else {
            context += "\nNoch keine Trainingsdaten vorhanden.\n"
        }

        context += "\nWenn du keine Daten zum Athlet hast, frage freundlich nach den relevanten Werten."
        return context
    }

    // MARK: - Persistence

    private func conversationIndex() -> Int? {
        guard let id = activeConversation?.id else { return nil }
        return conversations.firstIndex { $0.id == id }
    }

    private func saveConversations() {
        // Maximal 50 Konversationen speichern
        let toSave = Array(conversations.prefix(50))
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadConversations() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([Conversation].self, from: data) else { return }
        conversations = saved
        activeConversation = saved.first
    }
}
