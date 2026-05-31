import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum MessageRole: String, Codable {
    case user      = "user"
    case assistant = "assistant"
}

// Gespeicherte Konversation
struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date

    var preview: String {
        messages.last(where: { $0.role == .assistant })?.content
            .prefix(80)
            .description ?? "Neue Konversation"
    }
}

// Schnellzugriffs-Fragen (Quick Actions)
struct QuickPrompt: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let prompt: String
}

extension QuickPrompt {
    static let suggestions: [QuickPrompt] = [
        QuickPrompt(
            label: "Heutige Einheit",
            icon: "bicycle",
            prompt: "Was sollte ich heute trainieren, basierend auf meiner aktuellen Form und den letzten Trainings?"
        ),
        QuickPrompt(
            label: "Intervall-Tipps",
            icon: "bolt.fill",
            prompt: "Erkläre mir verschiedene Intervall-Formate für Rennradfahrer und welche für mein FTP-Level sinnvoll sind."
        ),
        QuickPrompt(
            label: "Ernährung Radfahren",
            icon: "fork.knife",
            prompt: "Was sollte ich vor, während und nach einem langen Rennrad-Training essen und trinken?"
        ),
        QuickPrompt(
            label: "Übertraining?",
            icon: "exclamationmark.triangle",
            prompt: "Wie erkenne ich Übertraining und was sind die Warnsignale, auf die ich achten sollte?"
        ),
        QuickPrompt(
            label: "FTP verbessern",
            icon: "chart.line.uptrend.xyaxis",
            prompt: "Welche Trainingseinheiten helfen am effektivsten, meinen FTP zu steigern?"
        ),
        QuickPrompt(
            label: "Tapering",
            icon: "arrow.down.right",
            prompt: "Wie funktioniert Tapering vor einem wichtigen Rennen oder Sportivo? Wie viele Tage vorher?"
        ),
    ]
}
