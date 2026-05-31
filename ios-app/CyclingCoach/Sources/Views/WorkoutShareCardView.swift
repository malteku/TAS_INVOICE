import SwiftUI

// Die eigentliche Share-Card – wird 1:1 von ImageRenderer gerendert.
// Kein GeometryReader, keine Environment-Abhängigkeiten.
struct WorkoutShareCardView: View {

    let workout: CyclingWorkout
    let routePoints: [CGPoint]
    let theme: ShareTheme
    let format: ShareFormat

    private var size: CGSize { format.pointSize }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Hintergrund
            theme.background
                .frame(width: size.width, height: size.height)

            // Route-Bereich
            routeCanvas
                .frame(width: size.width, height: size.height * format.routeHeightRatio)
                .frame(width: size.width, height: size.height, alignment: .top)

            // Subtiler Vignette-Rand
            vignetteOverlay

            // Stats-Panel unten
            statsPanel
                .frame(width: size.width)

            // Header oben
            headerBar
                .frame(width: size.width)
                .frame(width: size.width, height: size.height, alignment: .top)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: format == .story ? 0 : 20))
    }

    // MARK: - Route Canvas

    private var routeCanvas: some View {
        Canvas { ctx, canvasSize in
            guard routePoints.count > 1 else {
                // Kein GPS → abstrakte Wellenform zeichnen
                drawAbstractWave(ctx: ctx, size: canvasSize)
                return
            }

            var path = Path()
            path.move(to: routePoints[0])
            for pt in routePoints.dropFirst() {
                path.addLine(to: pt)
            }

            // Äußerer Glow (breit, transparent)
            ctx.stroke(path,
                       with: .color(theme.glowColor),
                       style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))

            // Mittlerer Glow
            ctx.stroke(path,
                       with: .color(theme.routeColor.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

            // Kernlinie
            ctx.stroke(path,
                       with: .color(theme.routeColor),
                       style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

            // Start-Punkt
            let startRect = CGRect(x: routePoints[0].x - 5, y: routePoints[0].y - 5, width: 10, height: 10)
            ctx.fill(Path(ellipseIn: startRect), with: .color(theme.routeColor))

            // End-Punkt
            if let last = routePoints.last {
                let endRect = CGRect(x: last.x - 4, y: last.y - 4, width: 8, height: 8)
                ctx.fill(Path(ellipseIn: endRect), with: .color(theme.routeColor.opacity(0.7)))
            }
        }
        .allowsHitTesting(false)
    }

    private func drawAbstractWave(ctx: GraphicsContext, size: CGSize) {
        // Artistischer Platzhalter wenn kein GPS vorhanden (Indoor-Trainer)
        let amplitude = size.height * 0.25
        let midY      = size.height * 0.5
        var path = Path()
        path.move(to: CGPoint(x: 0, y: midY))
        for x in stride(from: 0.0, through: Double(size.width), by: 2.0) {
            let progress = x / Double(size.width)
            let y = midY + amplitude * CGFloat(sin(progress * .pi * 5))
                         + amplitude * 0.4 * CGFloat(sin(progress * .pi * 11))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        ctx.stroke(path,
                   with: .color(theme.glowColor),
                   style: StrokeStyle(lineWidth: 8, lineCap: .round))
        ctx.stroke(path,
                   with: .color(theme.routeColor),
                   style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }

    // MARK: - Vignette

    private var vignetteOverlay: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .clear, theme.backgroundGradient.last?.opacity(0.7) ?? .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
    }

    // MARK: - Stats Panel

    private var statsPanel: some View {
        VStack(spacing: 0) {
            // Trennlinie mit Route-Farbe
            Rectangle()
                .fill(theme.routeColor.opacity(0.6))
                .frame(height: 1.5)

            VStack(spacing: format == .story ? 12 : 8) {
                statsGrid
                footerRow
            }
            .padding(.horizontal, 20)
            .padding(.vertical, format == .story ? 16 : 10)
            .background(theme.panelBackground)
        }
    }

    private var statsGrid: some View {
        let cols = format == .story ? 3 : 4

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: cols),
            spacing: format == .story ? 14 : 10
        ) {
            StatCell(value: String(format: "%.1f", workout.distanceKm),
                     unit: "km", label: "Distanz", theme: theme)

            StatCell(value: workout.formattedDuration,
                     unit: "", label: "Dauer", theme: theme)

            StatCell(value: String(format: "%.1f", workout.avgSpeedKmh),
                     unit: "km/h", label: "Ø Speed", theme: theme)

            if let elev = workout.elevationGainM {
                StatCell(value: "\(Int(elev))", unit: "m", label: "Höhenmeter", theme: theme)
            } else if let hr = workout.avgHeartRate {
                StatCell(value: "\(Int(hr))", unit: "bpm", label: "Ø Herzfrq.", theme: theme)
            }

            if format == .story {
                if let pwr = workout.avgPower {
                    StatCell(value: "\(Int(pwr))", unit: "W", label: "Ø Leistung", theme: theme)
                } else if let hr = workout.avgHeartRate, workout.elevationGainM != nil {
                    StatCell(value: "\(Int(hr))", unit: "bpm", label: "Ø Herzfrq.", theme: theme)
                }

                if let cal = workout.calories {
                    StatCell(value: "\(Int(cal))", unit: "kcal", label: "Kalorien", theme: theme)
                }
            }
        }
    }

    private var footerRow: some View {
        HStack {
            // Datum
            Text(workout.date.formatted(date: .long, time: .omitted))
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(theme.textSecondary)

            Spacer()

            // Quelle + App-Name
            HStack(spacing: 4) {
                Text(workout.source)
                    .font(.system(size: 10))
                Text("·")
                Text("CyclingCoach")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            // App-Icon / Name
            HStack(spacing: 6) {
                Image(systemName: "bicycle.circle.fill")
                    .foregroundStyle(theme.routeColor)
                    .font(.system(size: 14))
                Text("CyclingCoach")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            // Wochentag
            Text(workout.date.formatted(.dateTime.weekday(.wide)))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, format == .story ? 16 : 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Stat Cell

private struct StatCell: View {
    let value: String
    let unit: String
    let label: String
    let theme: ShareTheme

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.routeColor)
                }
            }
            Text(label)
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(theme.textSecondary)
        }
    }
}
