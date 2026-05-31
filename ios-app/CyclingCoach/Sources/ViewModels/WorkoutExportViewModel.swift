import Foundation
import SwiftUI
import CoreLocation
import MapKit

@MainActor
class WorkoutExportViewModel: ObservableObject {

    let workout: CyclingWorkout

    // State
    @Published var backgroundMode: CardBackgroundMode = .gradient
    @Published var selectedTheme:  ShareTheme  = .carbonBlack
    @Published var selectedFormat: ShareFormat = .story

    // Route
    @Published var routePoints:    [CGPoint]   = []
    @Published var hasRoute        = false
    @Published var isLoadingRoute  = false

    // Map-Hintergrund
    @Published var mapSnapshotImage: UIImage?
    @Published var isLoadingMap      = false

    // Foto-Hintergrund (UIImage wird direkt von der View gesetzt)
    @Published var userPhotoImage:  UIImage?

    // Export
    @Published var isExporting:     Bool   = false
    @Published var exportedImage:   UIImage?
    @Published var error:           String?

    private let healthKit    = HealthKitService.shared
    private var rawLocations: [CLLocation] = []

    init(workout: CyclingWorkout) {
        self.workout = workout
    }

    // Das aktuell relevante Hintergrundbild (nil = Gradient)
    var currentBackgroundImage: UIImage? {
        switch backgroundMode {
        case .gradient: return nil
        case .map:      return mapSnapshotImage
        case .photo:    return userPhotoImage
        }
    }

    // MARK: - Route laden

    func loadRoute() async {
        guard !isLoadingRoute else { return }
        isLoadingRoute = true
        defer { isLoadingRoute = false }

        do {
            rawLocations = try await healthKit.fetchWorkoutRoute(workoutID: workout.id)
            hasRoute     = rawLocations.count > 10
            updateNormalizedRoute()
        } catch {
            hasRoute     = false
            rawLocations = []
        }
    }

    func updateNormalizedRoute() {
        let routeArea = CGSize(
            width:  selectedFormat.pointSize.width,
            height: selectedFormat.pointSize.height * selectedFormat.routeHeightRatio
        )
        routePoints  = Self.normalizeLocations(rawLocations, canvasSize: routeArea, padding: 40)
        exportedImage = nil
    }

    // MARK: - Hintergrundmodus wechseln

    func switchBackground(to mode: CardBackgroundMode) async {
        backgroundMode = mode
        exportedImage  = nil
        if mode == .map && mapSnapshotImage == nil && hasRoute {
            await generateMapSnapshot()
        }
    }

    // MARK: - Satellitenkarte generieren

    func generateMapSnapshot() async {
        guard hasRoute, !rawLocations.isEmpty else { return }
        isLoadingMap = true
        defer { isLoadingMap = false }
        error = nil

        do {
            let px = selectedFormat.pointSize  // Points → bei @3x Export sind das 3× Pixel
            let snapshotPx = CGSize(width: px.width * 3, height: px.height * 3)
            mapSnapshotImage = try await createSatelliteSnapshot(
                locations:  rawLocations,
                pixelSize:  snapshotPx,
                routeColor: selectedTheme.routeUIColor,
                glowColor:  selectedTheme.glowUIColor
            )
        } catch {
            self.error = "Satellitenkarte nicht verfügbar: \(error.localizedDescription)"
            backgroundMode = .gradient   // Fallback
        }
    }

    // MARK: - Karte via MKMapSnapshotter (UIKit)

    private func createSatelliteSnapshot(
        locations:  [CLLocation],
        pixelSize:  CGSize,
        routeColor: UIColor,
        glowColor:  UIColor
    ) async throws -> UIImage {

        let region = mapRegion(for: locations,
                                aspectRatio: pixelSize.width / pixelSize.height)

        let opts             = MKMapSnapshotter.Options()
        opts.region          = region
        opts.size            = pixelSize
        opts.mapType         = .satellite
        opts.pointOfInterestFilter = .excludingAll
        opts.showsBuildings  = false

        let snapshotter = MKMapSnapshotter(options: opts)
        let snapshot: MKMapSnapshotter.Snapshot = try await withCheckedThrowingContinuation { cont in
            snapshotter.start(with: .global(qos: .userInitiated)) { snap, err in
                if let err  { cont.resume(throwing: err);   return }
                guard let snap else {
                    cont.resume(throwing: NSError(domain: "MapSnapshot", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Snapshot fehlgeschlagen"]))
                    return
                }
                cont.resume(returning: snap)
            }
        }

        return drawRoute(on: snapshot,
                         locations:  locations,
                         routeColor: routeColor,
                         glowColor:  glowColor,
                         size:       pixelSize)
    }

    /// Strecke via UIKit präzise auf das Snapshot-Bild zeichnen.
    /// snapshot.point(for:) konvertiert Koordinaten exakt in Pixelpositionen.
    private func drawRoute(
        on snapshot:   MKMapSnapshotter.Snapshot,
        locations:     [CLLocation],
        routeColor:    UIColor,
        glowColor:     UIColor,
        size:          CGSize
    ) -> UIImage {
        // Auf max 1200 Punkte ausdünnen
        let step    = max(1, locations.count / 1200)
        let thinned = stride(from: 0, to: locations.count, by: step).map { locations[$0] }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Satellitenbild
            snapshot.image.draw(in: CGRect(origin: .zero, size: size))

            // Leichte Abdunklung für Lesbarkeit
            ctx.cgContext.setFillColor(UIColor.black.withAlphaComponent(0.22).cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))

            guard thinned.count > 1 else { return }

            let pts  = thinned.map { snapshot.point(for: $0.coordinate) }
            let path = UIBezierPath()
            path.move(to: pts[0])
            pts.dropFirst().forEach { path.addLine(to: $0) }
            path.lineCapStyle  = .round
            path.lineJoinStyle = .round

            let cgCtx = ctx.cgContext

            // Äußerer Glow
            cgCtx.setShadow(offset: .zero, blur: 18, color: glowColor.withAlphaComponent(0.75).cgColor)
            glowColor.withAlphaComponent(0.35).setStroke()
            path.lineWidth = 12
            path.stroke()

            // Mittlerer Glow
            cgCtx.setShadow(offset: .zero, blur: 8, color: routeColor.withAlphaComponent(0.5).cgColor)
            routeColor.withAlphaComponent(0.55).setStroke()
            path.lineWidth = 6
            path.stroke()

            // Kernlinie
            cgCtx.setShadow(offset: .zero, blur: 0)
            routeColor.setStroke()
            path.lineWidth = 2.8
            path.stroke()

            // Start-Marker (ausgefüllter Kreis mit dunklem Kern)
            let s = pts[0]
            let outer = UIBezierPath(ovalIn: CGRect(x: s.x-8,  y: s.y-8,  width: 16, height: 16))
            routeColor.setFill(); outer.fill()
            let inner = UIBezierPath(ovalIn: CGRect(x: s.x-4,  y: s.y-4,  width: 8,  height: 8))
            UIColor.black.withAlphaComponent(0.6).setFill(); inner.fill()
        }
    }

    /// Kartenregion berechnen und auf das Seitenverhältnis der Karte zuschneiden
    private func mapRegion(for locations: [CLLocation], aspectRatio: CGFloat) -> MKCoordinateRegion {
        let lats = locations.map(\.coordinate.latitude)
        let lons = locations.map(\.coordinate.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 48, longitude: 11),
                span:   MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        let center  = CLLocationCoordinate2D(latitude: (maxLat + minLat) / 2,
                                              longitude: (maxLon + minLon) / 2)
        let pad     = 0.18
        var latD    = (maxLat - minLat) * (1 + pad * 2)
        var lonD    = (maxLon - minLon) * (1 + pad * 2)

        // Mercator-Korrektur für Seitenverhältnis
        let cosLat  = cos(center.latitude * .pi / 180)
        let geoAsp  = CGFloat(lonD * cosLat / max(latD, 0.0001))
        if geoAsp < aspectRatio { lonD = latD * Double(aspectRatio) / cosLat }
        else                    { latD = lonD * cosLat / Double(aspectRatio)  }

        return MKCoordinateRegion(
            center: center,
            span:   MKCoordinateSpan(latitudeDelta: max(latD, 0.005),
                                     longitudeDelta: max(lonD, 0.005))
        )
    }

    // MARK: - Theme/Format Änderungen

    func onThemeChanged() {
        exportedImage   = nil
        // Bei Kartenmodus: neue Karte mit anderer Routenfarbe generieren
        if backgroundMode == .map {
            mapSnapshotImage = nil
            Task { await generateMapSnapshot() }
        }
    }

    func onFormatChanged() {
        updateNormalizedRoute()
        // Karte muss in neuem Seitenverhältnis neu generiert werden
        if backgroundMode == .map {
            mapSnapshotImage = nil
            Task { await generateMapSnapshot() }
        }
    }

    // MARK: - Bild exportieren + teilen

    func exportImage() async {
        isExporting   = true
        defer { isExporting = false }
        error         = nil
        updateNormalizedRoute()

        let size = selectedFormat.pointSize
        let card = WorkoutShareCardView(
            workout:         workout,
            routePoints:     routePoints,
            theme:           selectedTheme,
            format:          selectedFormat,
            backgroundMode:  backgroundMode,
            backgroundImage: currentBackgroundImage
        )
        .frame(width: size.width, height: size.height)

        let renderer       = ImageRenderer(content: card)
        renderer.scale     = 3.0

        guard let image = renderer.uiImage else {
            self.error = "Bild konnte nicht erstellt werden."
            return
        }
        exportedImage = image
    }

    func shareImage() async {
        if exportedImage == nil { await exportImage() }
        guard let image = exportedImage else { return }

        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        av.excludedActivityTypes = [.assignToContact, .addToReadingList]
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root  = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    // MARK: - Koordinaten-Normalisierung (Mercator-korrekt, für Canvas-Modus)

    static func normalizeLocations(
        _ locations:  [CLLocation],
        canvasSize:   CGSize,
        padding:      CGFloat = 40
    ) -> [CGPoint] {
        let step    = max(1, locations.count / 800)
        let thinned = stride(from: 0, to: locations.count, by: step).map { locations[$0] }
        guard thinned.count > 1 else { return [] }

        let lats    = thinned.map { $0.coordinate.latitude }
        let lons    = thinned.map { $0.coordinate.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return [] }

        let latSpan          = max(maxLat - minLat, 0.0001)
        let lonSpan          = max(maxLon - minLon, 0.0001)
        let midLat           = (maxLat + minLat) / 2
        let latScale         = cos(midLat * .pi / 180)
        let adjustedLonSpan  = lonSpan * latScale

        let drawW    = canvasSize.width  - padding * 2
        let drawH    = canvasSize.height - padding * 2
        let scale    = min(drawW / adjustedLonSpan, drawH / latSpan)
        let actualW  = adjustedLonSpan * scale
        let actualH  = latSpan         * scale
        let offsetX  = padding + (drawW - actualW) / 2
        let offsetY  = padding + (drawH - actualH) / 2

        return thinned.map { loc in
            CGPoint(
                x: CGFloat((loc.coordinate.longitude - minLon) * latScale * scale) + offsetX,
                y: CGFloat((maxLat - loc.coordinate.latitude)  * scale)            + offsetY
            )
        }
    }
}
