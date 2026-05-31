import SwiftUI

struct WorkoutExportView: View {

    @StateObject private var vm: WorkoutExportViewModel
    @Environment(\.dismiss) var dismiss

    init(workout: CyclingWorkout) {
        _vm = StateObject(wrappedValue: WorkoutExportViewModel(workout: workout))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    cardPreview
                    formatPicker
                    themePicker
                    exportButton
                }
                .padding()
                .padding(.bottom, 20)
            }
            .navigationTitle("Training teilen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen") { dismiss() }
                }
            }
            .task { await vm.loadRoute() }
            .onChange(of: vm.selectedFormat) { _, _ in vm.updateNormalizedRoute() }
            .onChange(of: vm.selectedTheme)  { _, _ in vm.exportedImage = nil }
        }
    }

    // MARK: - Card Preview

    private var cardPreview: some View {
        ZStack {
            // Checkerboard-Hintergrund um den Kartenrand erkennbar zu machen
            Color(UIColor.secondarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if vm.isLoadingRoute {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Lade GPS-Route…")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(height: previewHeight)
            } else {
                // Skalierte Vorschau der eigentlichen Share-Card
                WorkoutShareCardView(
                    workout: vm.workout,
                    routePoints: vm.routePoints,
                    theme: vm.selectedTheme,
                    format: vm.selectedFormat
                )
                .frame(
                    width:  vm.selectedFormat.pointSize.width,
                    height: vm.selectedFormat.pointSize.height
                )
                .scaleEffect(previewScale)
                .frame(height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: vm.selectedFormat == .post ? 12 : 0))
                .shadow(color: vm.selectedTheme.routeColor.opacity(0.25), radius: 20, x: 0, y: 8)
            }
        }
        .padding(.vertical, 8)
    }

    private var previewScale: CGFloat {
        let maxW: CGFloat = UIScreen.main.bounds.width - 48
        return min(maxW / vm.selectedFormat.pointSize.width, 1.0)
    }

    private var previewHeight: CGFloat {
        vm.selectedFormat.pointSize.height * previewScale + 16
    }

    // MARK: - Format Picker

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Format")
            HStack(spacing: 12) {
                ForEach(ShareFormat.allCases, id: \.self) { fmt in
                    formatButton(fmt)
                }
            }
        }
    }

    private func formatButton(_ fmt: ShareFormat) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { vm.selectedFormat = fmt }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: fmt.icon)
                    .font(.callout)
                Text(fmt.rawValue)
                    .font(.callout).fontWeight(.medium)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(vm.selectedFormat == fmt
                ? vm.selectedTheme.routeColor
                : Color(UIColor.tertiarySystemBackground))
            .foregroundStyle(vm.selectedFormat == fmt ? .black : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    vm.selectedFormat == fmt ? .clear : Color.secondary.opacity(0.3),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Theme Picker

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Theme")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ShareTheme.all) { theme in
                        themeButton(theme)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }

    private func themeButton(_ theme: ShareTheme) -> some View {
        Button {
            withAnimation(.spring(duration: 0.2)) { vm.selectedTheme = theme }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(
                            colors: theme.backgroundGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 72, height: 72)

                    // Mini-Route-Vorschau
                    Canvas { ctx, size in
                        var path = Path()
                        let pts = miniPreviewPoints(size: size)
                        guard pts.count > 1 else { return }
                        path.move(to: pts[0])
                        for p in pts.dropFirst() { path.addLine(to: p) }
                        ctx.stroke(path,
                                   with: .color(theme.glowColor),
                                   style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        ctx.stroke(path,
                                   with: .color(theme.routeColor),
                                   style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                    .frame(width: 72, height: 72)

                    if vm.selectedTheme == theme {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(theme.routeColor, lineWidth: 2.5)
                            .frame(width: 72, height: 72)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(theme.routeColor)
                            .background(Circle().fill(Color.black.opacity(0.6)).padding(3))
                            .offset(x: 24, y: -24)
                    }
                }

                Text("\(theme.emoji) \(theme.name)")
                    .font(.caption2).fontWeight(.medium)
                    .foregroundStyle(vm.selectedTheme == theme ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // Einfache Vorschau-Route für Theme-Buttons (s-förmige Kurve)
    private func miniPreviewPoints(size: CGSize) -> [CGPoint] {
        if !vm.routePoints.isEmpty, let minX = vm.routePoints.map(\.x).min(),
           let maxX = vm.routePoints.map(\.x).max(),
           let minY = vm.routePoints.map(\.y).min(),
           let maxY = vm.routePoints.map(\.y).max() {
            // Deterministisch ausdünnen auf max 80 Punkte (kein zufälliges Sampling)
            let step = max(1, vm.routePoints.count / 80)
            let thinned = stride(from: 0, to: vm.routePoints.count, by: step)
                .map { vm.routePoints[$0] }
            let scaleX = (size.width - 16) / max(maxX - minX, 1)
            let scaleY = (size.height - 16) / max(maxY - minY, 1)
            let scale  = min(scaleX, scaleY) * 0.9
            return thinned.map { pt in
                CGPoint(
                    x: (pt.x - minX) * scale + 8,
                    y: (pt.y - minY) * scale + 8
                )
            }
        }
        // Fallback: S-Kurve
        let pts = stride(from: 0.0, through: 1.0, by: 0.05).map { t -> CGPoint in
            CGPoint(
                x: t * (size.width - 16) + 8,
                y: sin(t * .pi * 2) * (size.height * 0.3) + size.height / 2
            )
        }
        return Array(pts)
    }

    // MARK: - Export Button

    private var exportButton: some View {
        VStack(spacing: 12) {
            Button {
                Task { await vm.shareImage() }
            } label: {
                HStack(spacing: 10) {
                    if vm.isExporting {
                        ProgressView().tint(.white)
                        Text("Erstelle Bild…")
                    } else {
                        Image(systemName: "square.and.arrow.up")
                        Text("Teilen")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(vm.selectedTheme.routeColor)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(vm.isExporting)

            if let err = vm.error {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.red)
            }

            Text(!vm.hasRoute
                 ? "Kein GPS-Track gefunden (z.B. Indoor-Trainer) – wird als abstrakte Grafik dargestellt."
                 : "Exportiert als 1080px-Bild, optimiert für Instagram Story / Post.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline).fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }
}
