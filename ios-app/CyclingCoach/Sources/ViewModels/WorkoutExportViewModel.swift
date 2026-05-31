import Foundation
import SwiftUI
import CoreLocation

@MainActor
class WorkoutExportViewModel: ObservableObject {

    let workout: CyclingWorkout

    @Published var isLoadingRoute = false
    @Published var routePoints: [CGPoint] = []      // normalisiert für die Karte
    @Published var hasRoute = false
    @Published var selectedTheme: ShareTheme = .carbonBlack
    @Published var selectedFormat: ShareFormat = .story
    @Published var isExporting = false
    @Published var exportedImage: UIImage?
    @Published var error: String?

    private let healthKit = HealthKitService.shared
    private var rawLocations: [CLLocation] = []

    init(workout: CyclingWorkout) {
        self.workout = workout
    }

    // MARK: - Route laden

    func loadRoute() async {
        guard !isLoadingRoute else { return }
        isLoadingRoute = true
        defer { isLoadingRoute = false }

        do {
            rawLocations = try await healthKit.fetchWorkoutRoute(workoutID: workout.id)
            hasRoute = rawLocations.count > 10
            updateNormalizedRoute()
        } catch {
            // Kein GPS-Track (Ergometer, Indoor) → kein Fehler
            hasRoute = false
            rawLocations = []
        }
    }

    func updateNormalizedRoute() {
        let routeArea = CGSize(
            width:  selectedFormat.pointSize.width,
            height: selectedFormat.pointSize.height * selectedFormat.routeHeightRatio
        )
        routePoints = Self.normalizeLocations(rawLocations, canvasSize: routeArea, padding: 40)
    }

    // MARK: - Bild exportieren

    func exportImage() async {
        isExporting = true
        defer { isExporting = false }
        error = nil

        updateNormalizedRoute()

        let size = selectedFormat.pointSize
        let card = WorkoutShareCardView(
            workout: workout,
            routePoints: routePoints,
            theme: selectedTheme,
            format: selectedFormat
        )
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0   // @3x → 1080-Breite

        guard let image = renderer.uiImage else {
            self.error = "Bild konnte nicht erstellt werden."
            return
        }
        exportedImage = image
    }

    // MARK: - Teilen

    func shareImage() async {
        if exportedImage == nil { await exportImage() }
        guard let image = exportedImage else { return }

        await MainActor.run {
            let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            av.excludedActivityTypes = [.assignToContact, .addToReadingList]
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(av, animated: true)
            }
        }
    }

    // MARK: - Koordinaten-Normalisierung (Mercator-korrekt)

    static func normalizeLocations(
        _ locations: [CLLocation],
        canvasSize: CGSize,
        padding: CGFloat = 40
    ) -> [CGPoint] {
        // Auf max 800 Punkte ausdünnen (Performance)
        let step = max(1, locations.count / 800)
        let thinned = stride(from: 0, to: locations.count, by: step).map { locations[$0] }
        guard thinned.count > 1 else { return [] }

        let lats = thinned.map { $0.coordinate.latitude }
        let lons = thinned.map { $0.coordinate.longitude }

        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return [] }

        let latSpan = max(maxLat - minLat, 0.0001)
        let lonSpan = max(maxLon - minLon, 0.0001)

        // Mercator: Längengrade werden äquatornah breiter
        let midLat  = (maxLat + minLat) / 2
        let latScale = cos(midLat * .pi / 180)
        let adjustedLonSpan = lonSpan * latScale

        let drawW = canvasSize.width  - padding * 2
        let drawH = canvasSize.height - padding * 2

        let scale   = min(drawW / adjustedLonSpan, drawH / latSpan)
        let actualW = adjustedLonSpan * scale
        let actualH = latSpan         * scale

        // Route zentrieren
        let offsetX = padding + (drawW - actualW) / 2
        let offsetY = padding + (drawH - actualH) / 2

        return thinned.map { loc in
            let x = CGFloat((loc.coordinate.longitude - minLon) * latScale * scale) + offsetX
            let y = CGFloat((maxLat - loc.coordinate.latitude)  * scale)            + offsetY
            return CGPoint(x: x, y: y)
        }
    }
}
