import SwiftUI

struct RGB: Equatable, Codable {
    var r: Int, g: Int, b: Int
}

enum ColorMath {
    static func hsvToRGB(h: Double, s: Double, v: Double) -> RGB {
        let s = s / 100, v = v / 100
        func f(_ n: Double) -> Double {
            let k = (n + h / 60).truncatingRemainder(dividingBy: 6)
            return v - v * s * max(0, min(k, 4 - k, 1))
        }
        return RGB(r: Int((f(5) * 255).rounded()), g: Int((f(3) * 255).rounded()), b: Int((f(1) * 255).rounded()))
    }

    static func rgbToHSV(_ c: RGB) -> (h: Double, s: Double, v: Double) {
        let r = Double(c.r) / 255, g = Double(c.g) / 255, b = Double(c.b) / 255
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        var h = 0.0
        if d > 0 {
            if mx == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == g { h = (b - r) / d + 2 }
            else { h = (r - g) / d + 4 }
        }
        h = (h * 60 + 360).truncatingRemainder(dividingBy: 360)
        return (h.rounded(), mx > 0 ? (d / mx * 100).rounded() : 0, (mx * 100).rounded())
    }

    static func hexToRGB(_ hex: String) -> RGB? {
        var s = hex.trimmingCharacters(in: .whitespaces).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        return RGB(r: (v >> 16) & 0xFF, g: (v >> 8) & 0xFF, b: v & 0xFF)
    }

    static func rgbToHex(_ c: RGB) -> String {
        String(format: "#%02X%02X%02X", max(0, min(255, c.r)), max(0, min(255, c.g)), max(0, min(255, c.b)))
    }

    /// Température de couleur (K) → RVB (approximation de Tanner Helland)
    static func kelvinToRGB(_ k: Double) -> RGB {
        let t = k / 100
        let r = t <= 66 ? 255 : 329.698727446 * pow(t - 60, -0.1332047592)
        let g = t <= 66 ? 99.4708025861 * log(t) - 161.1195681661 : 288.1221695283 * pow(t - 60, -0.0755148492)
        let b = t >= 66 ? 255 : (t <= 19 ? 0 : 138.5177312231 * log(t - 10) - 305.0447927307)
        func c(_ x: Double) -> Int { Int(max(0, min(255, x)).rounded()) }
        return RGB(r: c(r), g: c(g), b: c(b))
    }

    static func name(h: Double, s: Double) -> String {
        if s < 12 { return "Blanc" }
        let n: [(Double, String)] = [(15, "Rouge"), (40, "Orange"), (65, "Ambre"), (80, "Jaune"), (150, "Vert"), (175, "Menthe"),
                                     (200, "Cyan"), (230, "Azur"), (255, "Bleu"), (280, "Indigo"), (305, "Violet"), (335, "Magenta"), (361, "Rouge")]
        return n.first(where: { h < $0.0 })?.1 ?? "Rouge"
    }
}

extension Color {
    init(hex: String) {
        let c = ColorMath.hexToRGB(hex) ?? RGB(r: 255, g: 255, b: 255)
        self.init(red: Double(c.r) / 255, green: Double(c.g) / 255, blue: Double(c.b) / 255)
    }
    init(rgb: RGB) {
        self.init(red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255)
    }
    static func hue(_ h: Double) -> Color { Color(hue: h / 360, saturation: 1, brightness: 1) }
    static let hueStops: [Color] = stride(from: 0.0, through: 360.0, by: 30).map { Color.hue($0) }
}
