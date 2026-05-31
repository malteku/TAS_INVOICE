import SwiftUI

struct SettingsView: View {

    @StateObject private var profile = UserProfile.current ?? UserProfile()
    @ObservedObject private var claude = ClaudeService.shared
    @State private var showApiKeyInfo = false
    @State private var showResetConfirm = false
    @State private var isSaved = false

    var body: some View {
        Form {
            Section("Persönliche Daten") {
                TextField("Name", text: $profile.name)
                    .textContentType(.name)

                HStack {
                    Text("Geburtsjahr")
                    Spacer()
                    TextField("z.B. 1985", value: $profile.birthYear, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Leistungsparameter") {
                optionalDoublefield("FTP (Watt)", value: $profile.ftp, placeholder: "z.B. 250")
                optionalDoublefield("Max. Herzfrequenz (bpm)", value: $profile.maxHeartRate, placeholder: "z.B. 185")
                optionalDoublefield("Ruhe-HF (bpm)", value: $profile.restingHeartRate, placeholder: "z.B. 52")
                optionalDoublefield("Gewicht (kg)", value: $profile.weight, placeholder: "z.B. 75")
            }

            Section {
                HStack {
                    Text("Claude API-Key")
                    Spacer()
                    Button {
                        showApiKeyInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
                SecureField("sk-ant-...", text: $profile.claudeApiKey)
                    .textContentType(.password)
                    .font(.system(.body, design: .monospaced))

                if profile.claudeApiKey.isEmpty {
                    Label("Ohne API-Key sind keine KI-Analysen möglich.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Claude KI-Integration")
            } footer: {
                Text("Hole deinen API-Key unter console.anthropic.com. Die Kosten betragen ca. $3 pro Million Input-Tokens. Ein Free-Tier mit Testguthaben ist verfügbar.")
            }

            Section {
                usageRow("API-Anfragen",   value: "\(claude.usageStats.callCount)")
                usageRow("Input-Tokens",   value: formatTokens(claude.usageStats.totalInputTokens))
                usageRow("Output-Tokens",  value: formatTokens(claude.usageStats.totalOutputTokens))

                HStack {
                    Text("Geschätzte Kosten")
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatCost(claude.usageStats.estimatedCostUSD))
                        .fontWeight(.bold)
                        .foregroundStyle(claude.usageStats.estimatedCostUSD < 1 ? .green : .orange)
                }

                if let first = claude.usageStats.firstCallDate {
                    usageRow("Erfassung seit", value: first.formatted(date: .abbreviated, time: .omitted))
                }

                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Verbrauch zurücksetzen", systemImage: "arrow.counterclockwise")
                }
                .confirmationDialog("Verbrauchsdaten löschen?",
                                    isPresented: $showResetConfirm,
                                    titleVisibility: .visible) {
                    Button("Zurücksetzen", role: .destructive) { claude.resetUsage() }
                }
            } header: {
                Text("API-Verbrauch")
            } footer: {
                Text("Preise: $3/Mio. Input-Token · $15/Mio. Output-Token (claude-sonnet-4-6). Nur eine Schätzung.")
            }

            Section {
                if let zones = profile.heartRateZones {
                    heartRateZonesView(zones)
                } else {
                    Text("Trage Max. HF ein, um Zonen zu berechnen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Herzfrequenz-Zonen (berechnet)")
            }

            Section {
                Button {
                    saveProfile()
                } label: {
                    HStack {
                        Spacer()
                        if isSaved {
                            Label("Gespeichert!", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("Speichern").fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Profil & Einstellungen")
        .sheet(isPresented: $showApiKeyInfo) {
            ApiKeyInfoSheet()
        }
    }

    private func optionalDoublefield(_ label: String, value: Binding<Double?>, placeholder: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    private func heartRateZonesView(_ zones: HeartRateZones) -> some View {
        Group {
            zoneRow("Z1 Erholung", range: "< \(Int(zones.zone1Max)) bpm", color: .blue)
            zoneRow("Z2 Grundlage", range: "\(Int(zones.zone1Max))–\(Int(zones.zone2Max)) bpm", color: .green)
            zoneRow("Z3 Tempo", range: "\(Int(zones.zone2Max))–\(Int(zones.zone3Max)) bpm", color: .yellow)
            zoneRow("Z4 Schwelle", range: "\(Int(zones.zone3Max))–\(Int(zones.zone4Max)) bpm", color: .orange)
            zoneRow("Z5 VO2max", range: "> \(Int(zones.zone4Max)) bpm", color: .red)
        }
    }

    private func zoneRow(_ name: String, range: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(name).font(.caption)
            Spacer()
            Text(range).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func usageRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }

    private func formatTokens(_ count: Int) -> String {
        count >= 1_000_000
            ? String(format: "%.1f Mio.", Double(count) / 1_000_000)
            : count >= 1_000
                ? String(format: "%.1f k", Double(count) / 1_000)
                : "\(count)"
    }

    private func formatCost(_ usd: Double) -> String {
        usd < 0.001 ? "< $0,001" : String(format: "$%.4f", usd)
    }

    private func saveProfile() {
        UserDefaults.standard.set(profile.claudeApiKey, forKey: "claudeApiKey")
        profile.save()
        withAnimation { isSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { isSaved = false }
        }
    }
}

struct ApiKeyInfoSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    infoSection(
                        title: "Was ist ein API-Key?",
                        icon: "key.fill",
                        color: .blue,
                        text: "Der API-Key erlaubt der App, Claude (Anthropics KI) direkt abzufragen. Alle Analysen laufen über Anthropics sichere Server."
                    )
                    infoSection(
                        title: "Kosten & Free-Tier",
                        icon: "creditcard",
                        color: .green,
                        text: "Anthropic bietet beim ersten Konto ein kostenloses Startguthaben (~$5). Danach: ~$3 pro Million Input-Tokens (claude-sonnet-4-6). Eine typische Trainingsanalyse kostet ca. $0,01–0,05."
                    )
                    infoSection(
                        title: "Sicherheit",
                        icon: "lock.shield.fill",
                        color: .orange,
                        text: "Der Key wird nur lokal auf deinem iPhone gespeichert (Keychain-ähnlich via UserDefaults). Er wird niemals an Dritte weitergegeben."
                    )
                    infoSection(
                        title: "So holst du deinen Key",
                        icon: "arrow.right.circle.fill",
                        color: .purple,
                        text: "1. Öffne console.anthropic.com\n2. Registriere dich / melde dich an\n3. Gehe zu 'API Keys'\n4. Erstelle einen neuen Key\n5. Kopiere ihn in diese App"
                    )
                }
                .padding()
            }
            .navigationTitle("Claude API-Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func infoSection(title: String, icon: String, color: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
