import SwiftUI

// MARK: - Share Themes

struct ShareTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let backgroundGradient: [Color]
    let routeColor: Color
    let glowColor: Color
    let textPrimary: Color
    let textSecondary: Color
    let panelBackground: Color
    let dividerColor: Color

    static let all: [ShareTheme] = [.carbonBlack, .oceanBlue, .sunset, .midnight, .forest]

    // Dunkles Tech-Feeling (Garmin-Stil)
    static let carbonBlack = ShareTheme(
        id: "carbon",
        name: "Carbon",
        emoji: "⚫",
        backgroundGradient: [Color(r: 13, g: 13, b: 13), Color(r: 20, g: 24, b: 48)],
        routeColor: Color(r: 0, g: 255, b: 135),
        glowColor: Color(r: 0, g: 255, b: 135).opacity(0.3),
        textPrimary: .white,
        textSecondary: Color(r: 160, g: 160, b: 180),
        panelBackground: Color(r: 18, g: 18, b: 28).opacity(0.95),
        dividerColor: Color(r: 40, g: 40, b: 60)
    )

    // Tiefseeblau
    static let oceanBlue = ShareTheme(
        id: "ocean",
        name: "Ocean",
        emoji: "🌊",
        backgroundGradient: [Color(r: 10, g: 25, b: 60), Color(r: 20, g: 80, b: 130)],
        routeColor: Color(r: 100, g: 210, b: 255),
        glowColor: Color(r: 100, g: 210, b: 255).opacity(0.3),
        textPrimary: .white,
        textSecondary: Color(r: 150, g: 200, b: 230),
        panelBackground: Color(r: 8, g: 20, b: 50).opacity(0.95),
        dividerColor: Color(r: 30, g: 70, b: 110)
    )

    // Energetischer Sonnenuntergang
    static let sunset = ShareTheme(
        id: "sunset",
        name: "Sunset",
        emoji: "🌅",
        backgroundGradient: [Color(r: 20, g: 5, b: 5), Color(r: 120, g: 40, b: 10), Color(r: 200, g: 80, b: 20)],
        routeColor: Color(r: 255, g: 215, b: 0),
        glowColor: Color(r: 255, g: 150, b: 0).opacity(0.4),
        textPrimary: .white,
        textSecondary: Color(r: 255, g: 200, b: 150),
        panelBackground: Color(r: 20, g: 8, b: 0).opacity(0.92),
        dividerColor: Color(r: 100, g: 40, b: 10)
    )

    // Mystisches Violett
    static let midnight = ShareTheme(
        id: "midnight",
        name: "Midnight",
        emoji: "🌌",
        backgroundGradient: [Color(r: 10, g: 2, b: 30), Color(r: 50, g: 10, b: 80), Color(r: 100, g: 20, b: 120)],
        routeColor: Color(r: 224, g: 64, b: 251),
        glowColor: Color(r: 224, g: 64, b: 251).opacity(0.35),
        textPrimary: .white,
        textSecondary: Color(r: 200, g: 150, b: 220),
        panelBackground: Color(r: 12, g: 3, b: 35).opacity(0.95),
        dividerColor: Color(r: 60, g: 15, b: 90)
    )

    // Naturverbunden Grün
    static let forest = ShareTheme(
        id: "forest",
        name: "Forest",
        emoji: "🌲",
        backgroundGradient: [Color(r: 5, g: 20, b: 10), Color(r: 15, g: 50, b: 30), Color(r: 10, g: 60, b: 20)],
        routeColor: Color(r: 0, g: 230, b: 118),
        glowColor: Color(r: 0, g: 200, b: 80).opacity(0.35),
        textPrimary: .white,
        textSecondary: Color(r: 140, g: 200, b: 160),
        panelBackground: Color(r: 5, g: 18, b: 10).opacity(0.95),
        dividerColor: Color(r: 20, g: 60, b: 35)
    )

    // Computed gradient
    var background: LinearGradient {
        LinearGradient(
            colors: backgroundGradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Share Format

enum ShareFormat: String, CaseIterable {
    case story = "Story"
    case post  = "Post"

    // Kartenmaß in Points; ImageRenderer rendert bei scale=3 → 3× Pixel
    var pointSize: CGSize {
        switch self {
        case .story: return CGSize(width: 360, height: 640)   // → 1080×1920 px
        case .post:  return CGSize(width: 360, height: 360)   // → 1080×1080 px
        }
    }

    var icon: String {
        switch self {
        case .story: return "rectangle.portrait.fill"
        case .post:  return "square.fill"
        }
    }

    // Route-Bereich als Anteil der Kartenhöhe
    var routeHeightRatio: CGFloat {
        switch self {
        case .story: return 0.60
        case .post:  return 0.72
        }
    }
}

// MARK: - Background Mode

enum CardBackgroundMode: String, CaseIterable, Identifiable {
    case gradient = "Gradient"
    case map      = "Karte"
    case photo    = "Foto"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gradient: return "paintpalette.fill"
        case .map:      return "map.fill"
        case .photo:    return "photo.fill"
        }
    }

    var hint: String {
        switch self {
        case .gradient: return "Farbiger Hintergrund mit Route"
        case .map:      return "Satellitenkarte aus GPS-Daten"
        case .photo:    return "Eigenes Foto aus der Bibliothek"
        }
    }
}

// MARK: - Color Helper

extension Color {
    init(r: Int, g: Int, b: Int) {
        self.init(
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255
        )
    }
}

extension ShareTheme {
    // Für UIKit-Zeichnung (MKMapSnapshotter Route)
    var routeUIColor: UIColor { UIColor(routeColor) }
    var glowUIColor:  UIColor { UIColor(glowColor)  }
}
