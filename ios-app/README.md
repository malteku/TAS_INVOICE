# CyclingCoach – iOS App

Professionelle Rennrad-Trainingsdatenbank mit Claude KI-Analyse für iPhone (iOS 18+).

## Features

| Feature | Beschreibung |
|---------|-------------|
| **Health-Import** | Liest alle Rennrad-Workouts aus Apple Health (Dauer, Distanz, HF, Leistung, Kadenz, Höhenmeter) |
| **Trainingsdatenbank** | Vollständige Historie, monatlich gruppiert, sortierbar, durchsuchbar |
| **KI-Analyse** | Claude analysiert Trainingshistorie: Volumen, Intensitätsverteilung, Progression, Empfehlungen |
| **Trainingspläne** | Claude erstellt personalisierte Wochen-Pläne basierend auf Ziel & Historie |
| **Fitness-Metriken** | CTL/ATL/TSB (Form/Fitness/Ermüdung), TSS pro Woche, HF-Zonenverteilung |
| **Workout-Feedback** | KI-Analyse jedes einzelnen Trainings mit Empfehlung für die nächste Einheit |
| **Tagesform** | Tägliche Form-Einschätzung und Trainingsempfehlung |

## Architektur

```
CyclingCoach/
├── Sources/
│   ├── CyclingCoachApp.swift          # App-Entry, TabView
│   ├── Models/
│   │   └── WorkoutModels.swift        # CyclingWorkout, TrainingPlan, UserProfile, ...
│   ├── Services/
│   │   ├── HealthKitService.swift     # HealthKit-Queries, Fitness-Metriken
│   │   └── ClaudeService.swift        # Anthropic API-Integration
│   ├── ViewModels/
│   │   └── WorkoutsViewModel.swift    # WorkoutsVM, TrainingPlanVM, AIAnalysisVM
│   ├── Views/
│   │   ├── DashboardView.swift        # Hauptübersicht, Form-Card, Charts
│   │   ├── WorkoutsListView.swift     # Trainingshistorie
│   │   ├── WorkoutDetailView.swift    # Einzeltraining + KI-Analyse
│   │   ├── AnalysisView.swift         # KI-Trainingsanalyse + Zonenverteilung
│   │   ├── TrainingPlanView.swift     # Pläne anzeigen + generieren
│   │   └── SettingsView.swift         # Profil, FTP, Max-HF, API-Key
│   └── Utils/
│       └── MarkdownTextView.swift     # Markdown-Renderer für Claude-Antworten
└── Resources/
    └── Info.plist                     # HealthKit-Permissions
```

## Einrichtung in Xcode

### Voraussetzungen
- Xcode 16+
- iPhone mit iOS 18+ (HealthKit läuft **nicht** im Simulator)
- Apple Developer Account (kostenlos reicht für eigenes Gerät)

### Schritte
1. Repository klonen / Ordner `ios-app/` öffnen
2. `CyclingCoach.xcodeproj` in Xcode öffnen
3. **Signing & Capabilities** → Development Team auswählen
4. **Capabilities** → HealthKit hinzufügen (+ Button)
5. Gerät anschließen, Build & Run (⌘R)

### Claude API-Key
1. Konto erstellen: https://console.anthropic.com
2. "API Keys" → "Create Key"
3. In der App: **Einstellungen → Claude API-Key** eintragen
4. **Kosten:** ~$3/Mio. Input-Tokens; Free-Tier ~$5 Startguthaben

> **Hinweis:** Für eine Production-App sollte der API-Key über ein eigenes Backend proxied werden, damit er nicht im Gerät liegt. Für den privaten Einsatz ist die direkte Einbindung akzeptabel.

## Datenquellen

Die App liest aus Apple Health:
- Workouts (Typ: Radfahren)
- Herzfrequenz (während Workout)
- Leistung (Cycling Power, benötigt ANT+/BLE Powermeter → Garmin/Wahoo)
- Kadenz (Cycling Cadence)
- Distanz (Distance Cycling)
- Höhenunterschied (Flights Climbed → Näherung)
- Ruheherzfrequenz, Körpergewicht, VO2max

**Kompatible Datenquellen:** Apple Watch, Garmin (via Garmin Connect), Wahoo (via Wahoo App), Zwift, Strava (über Health-Sync)

## Berechnungsgrundlagen

| Metrik | Formel |
|--------|--------|
| **TSS** | `(Dauer_h × IF² × 100)` wobei `IF = avg_Power / FTP` |
| **CTL** (Fitness) | Exponentiell gewichteter Durchschnitt TSS, 42 Tage |
| **ATL** (Ermüdung) | Exponentiell gewichteter Durchschnitt TSS, 7 Tage |
| **TSB** (Form) | `CTL - ATL` |
| **HF-Zonen** | % der Max-HF: Z1<60%, Z2<70%, Z3<80%, Z4<90%, Z5<100% |

## Roadmap / Mögliche Erweiterungen

- [ ] Apple Watch Companion App
- [ ] Strava-Integration (OAuth)
- [ ] Garmin Connect direkt (FIT-File Import)
- [ ] HealthKit schreiben (geplante Workouts eintragen)
- [ ] Wetterintegration (OpenMeteo API)
- [ ] Segment-Analyse (Favorit-Strecken vergleichen)
- [ ] Export als PDF/CSV
- [ ] Backend für API-Key-Proxying (Vapor/Supabase)
