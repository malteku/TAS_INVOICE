import SwiftUI
import PhotosUI

struct WorkoutExportView: View {

    @StateObject private var vm: WorkoutExportViewModel
    @Environment(\.dismiss) var dismiss

    // PhotosPicker State bleibt in der View (PhotosUI importiert nur hier)
    @State private var photoPickerItem: PhotosPickerItem?

    init(workout: CyclingWorkout) {
        _vm = StateObject(wrappedValue: WorkoutExportViewModel(workout: workout))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    cardPreview
                    backgroundPicker
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
            // Foto aus PhotosPicker laden
            .onChange(of: photoPickerItem) { _, item in
                Task {
                    guard let item,
                          let data  = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    vm.userPhotoImage = image
                    vm.exportedImage  = nil
                }
            }
            // Format/Theme-Änderungen ans ViewModel melden
            .onChange(of: vm.selectedFormat) { _, _ in vm.onFormatChanged() }
            .onChange(of: vm.selectedTheme)  { _, _ in vm.onThemeChanged()  }
        }
    }

    // MARK: - Card Preview

    private var cardPreview: some View {
        ZStack {
            Color(UIColor.secondarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if vm.isLoadingRoute || vm.isLoadingMap {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(vm.isLoadingMap ? "Lade Satellitenbilder…" : "Lade GPS-Route…")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(height: previewHeight)
            } else {
                WorkoutShareCardView(
                    workout:         vm.workout,
                    routePoints:     vm.routePoints,
                    theme:           vm.selectedTheme,
                    format:          vm.selectedFormat,
                    backgroundMode:  vm.backgroundMode,
                    backgroundImage: vm.currentBackgroundImage
                )
                .frame(width:  vm.selectedFormat.pointSize.width,
                       height: vm.selectedFormat.pointSize.height)
                .scaleEffect(previewScale)
                .frame(height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: vm.selectedFormat == .post ? 12 : 0))
                .shadow(color: vm.selectedTheme.routeColor.opacity(0.3), radius: 20, x: 0, y: 8)
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

    // MARK: - Hintergrund-Picker

    private var backgroundPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Hintergrund")

            HStack(spacing: 10) {
                ForEach(CardBackgroundMode.allCases) { mode in
                    backgroundModeButton(mode)
                }
            }

            // Kontext-spezifische Aktionen
            switch vm.backgroundMode {
            case .gradient:
                EmptyView()

            case .map:
                mapModeInfo

            case .photo:
                photoModeButton
            }
        }
    }

    private func backgroundModeButton(_ mode: CardBackgroundMode) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) {
                Task { await vm.switchBackground(to: mode) }
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: mode.icon)
                    .font(.title3)
                    .frame(height: 28)
                Text(mode.rawValue)
                    .font(.caption).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(vm.backgroundMode == mode
                ? vm.selectedTheme.routeColor
                : Color(UIColor.tertiarySystemBackground))
            .foregroundStyle(vm.backgroundMode == mode ? .black : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(vm.backgroundMode == mode ? .clear : Color.secondary.opacity(0.2),
                            lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var mapModeInfo: some View {
        Group {
            if !vm.hasRoute {
                Label("Kein GPS-Track vorhanden – Satellitenbild nicht verfügbar.",
                      systemImage: "location.slash")
                    .font(.caption).foregroundStyle(.orange)
            } else if vm.mapSnapshotImage == nil && !vm.isLoadingMap {
                Button {
                    Task { await vm.generateMapSnapshot() }
                } label: {
                    Label("Satellitenbilder laden", systemImage: "map.fill")
                        .font(.callout).fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            } else if vm.mapSnapshotImage != nil {
                Label("Satellitenkarte geladen ✓", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            }
        }
    }

    private var photoModeButton: some View {
        PhotosPicker(
            selection: $photoPickerItem,
            matching:  .images,
            photoLibrary: .shared()
        ) {
            HStack(spacing: 8) {
                Image(systemName: vm.userPhotoImage != nil ? "checkmark.circle.fill" : "photo.on.rectangle")
                Text(vm.userPhotoImage != nil ? "Foto ausgewählt – tippen zum Ändern" : "Foto aus Bibliothek wählen")
                    .font(.callout).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(UIColor.tertiarySystemBackground))
            .foregroundStyle(vm.userPhotoImage != nil ? vm.selectedTheme.routeColor : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
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
                Image(systemName: fmt.icon).font(.callout)
                Text(fmt.rawValue).font(.callout).fontWeight(.medium)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(vm.selectedFormat == fmt
                ? vm.selectedTheme.routeColor
                : Color(UIColor.tertiarySystemBackground))
            .foregroundStyle(vm.selectedFormat == fmt ? .black : .primary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(
                vm.selectedFormat == fmt ? .clear : Color.secondary.opacity(0.3),
                lineWidth: 1
            ))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Theme / Streckenfarbe Picker

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Bei Bild-Modi nur Streckenfarbe relevant, keine Hintergrundvorschau nötig
            sectionLabel(vm.backgroundMode == .gradient ? "Theme" : "Streckenfarbe")

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
                    // Hintergrund des Buttons: bei Bild-Modi dunkel, sonst Gradient
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            vm.backgroundMode == .gradient
                                ? AnyShapeStyle(LinearGradient(colors: theme.backgroundGradient,
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Color.black.opacity(0.85))
                        )
                        .frame(width: 72, height: 72)

                    // Mini-Route in Theme-Farbe
                    Canvas { ctx, size in
                        let pts = miniPreviewPoints(size: size)
                        guard pts.count > 1 else { return }
                        var path = Path()
                        path.move(to: pts[0])
                        pts.dropFirst().forEach { path.addLine(to: $0) }
                        ctx.stroke(path, with: .color(theme.glowColor),
                                   style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        ctx.stroke(path, with: .color(theme.routeColor),
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

    // Mini-Routenpunkte für Theme-Buttons (deterministisch)
    private func miniPreviewPoints(size: CGSize) -> [CGPoint] {
        if !vm.routePoints.isEmpty,
           let minX = vm.routePoints.map(\.x).min(), let maxX = vm.routePoints.map(\.x).max(),
           let minY = vm.routePoints.map(\.y).min(), let maxY = vm.routePoints.map(\.y).max() {
            let step   = max(1, vm.routePoints.count / 80)
            let pts    = stride(from: 0, to: vm.routePoints.count, by: step).map { vm.routePoints[$0] }
            let sc     = min((size.width - 16) / max(maxX - minX, 1),
                             (size.height - 16) / max(maxY - minY, 1)) * 0.9
            return pts.map { CGPoint(x: ($0.x - minX) * sc + 8, y: ($0.y - minY) * sc + 8) }
        }
        // S-Kurve als Fallback
        return stride(from: 0.0, through: 1.0, by: 0.05).map { t in
            CGPoint(x: t * (size.width - 16) + 8,
                    y: sin(t * .pi * 2) * (size.height * 0.3) + size.height / 2)
        }
    }

    // MARK: - Export Button

    private var exportButton: some View {
        VStack(spacing: 12) {
            // Foto-Modus: Hinweis wenn noch kein Foto gewählt
            if vm.backgroundMode == .photo && vm.userPhotoImage == nil {
                Label("Wähle erst ein Foto oben aus.", systemImage: "photo.badge.exclamationmark")
                    .font(.caption).foregroundStyle(.orange)
            }

            Button {
                Task { await vm.shareImage() }
            } label: {
                HStack(spacing: 10) {
                    if vm.isExporting {
                        ProgressView().tint(.black)
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
            .disabled(vm.isExporting
                      || vm.isLoadingMap
                      || (vm.backgroundMode == .photo && vm.userPhotoImage == nil))

            if let err = vm.error {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.red)
            }

            exportHint
        }
    }

    private var exportHint: some View {
        let text: String = {
            switch vm.backgroundMode {
            case .gradient:
                return "Exportiert als 1080px-Bild, optimiert für Instagram Story / Post."
            case .map:
                return vm.hasRoute
                    ? "Satellitenkarte mit GPS-Strecke – Bilder von Apple Maps."
                    : "Kein GPS-Track – wechsle zu Gradient oder Foto."
            case .photo:
                return "Dein Foto mit Trainingsdaten und Strecke als Overlay."
            }
        }()
        return Text(text)
            .font(.caption).foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline).fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }
}
