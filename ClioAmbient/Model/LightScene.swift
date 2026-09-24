import SwiftUI

enum SceneMode: String, Codable {
    case color, custom, effect, music
}

/// Une ambiance enregistrée (scène perso, suggestion ou favori).
struct LightScene: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var category: String = "Mes scènes"
    var mode: SceneMode
    var hex: String? = nil
    var colors: [String]? = nil
    var style: Int? = nil
    var direction: Int? = nil
    var effect: Int? = nil
    var speed: Int? = nil
    var micMode: Int? = nil
    var sensitivity: Int? = nil
    var brightness: Int = 100
    var gradient: [String]? = nil

    var previewColors: [Color] {
        if let g = gradient { return g.map(Color.init(hex:)) }
        switch mode {
        case .color: return [Color(hex: hex ?? "#FF0000"), Color(hex: hex ?? "#FF0000").opacity(0.55)]
        case .custom: return (colors ?? ["#FFFFFF"]).map(Color.init(hex:))
        case .music: return [Color(hex: "#6A11CB"), Color(hex: "#FF2A8A")]
        case .effect:
            let pal = effect.flatMap { EffectCatalog.byID[$0]?.0.palette } ?? EffectCatalog.rainbow
            return pal.map(Color.init(hex:))
        }
    }

    var subtitle: String {
        switch mode {
        case .color: return "Couleur · \(brightness) %"
        case .custom:
            let s = CustomStyle.all.first(where: { $0.id == (style ?? 3) })?.name ?? "Dégradé"
            return "\(s) · \((colors ?? []).count) couleurs"
        case .music: return "Musique · mode \(micMode ?? 1)"
        case .effect: return effect == EffectCatalog.autoID ? "Effet · Auto" : "Effet · " + EffectCatalog.title(for: effect)
        }
    }
}

struct CustomStyle: Identifiable {
    let id: Int
    let name: String
    static let all: [CustomStyle] = [
        .init(id: 0, name: "Saut"), .init(id: 1, name: "Souffle"), .init(id: 2, name: "Flash"), .init(id: 3, name: "Fondu"),
        .init(id: 4, name: "Empilement"), .init(id: 5, name: "Rideau"), .init(id: 6, name: "Souffle 2"), .init(id: 7, name: "Course"),
    ]
}

enum SceneLibrary {
    private static func color(_ id: String, _ name: String, _ hex: String, _ bri: Int, _ grad: [String]) -> LightScene {
        LightScene(id: id, name: name, category: "Unies", mode: .color, hex: hex, brightness: bri, gradient: grad)
    }
    private static func grad(_ id: String, _ name: String, _ colors: [String], style: Int = 3, speed: Int = 30, bri: Int = 90, cat: String = "Dégradés") -> LightScene {
        LightScene(id: id, name: name, category: cat, mode: .custom, colors: colors, style: style, direction: 0, speed: speed, brightness: bri)
    }
    private static func fx(_ id: String, _ name: String, _ effect: Int, speed: Int, bri: Int = 100) -> LightScene {
        LightScene(id: id, name: name, category: "Animées", mode: .effect, effect: effect, speed: speed, brightness: bri)
    }

    static let suggestions: [LightScene] = [
        color("s-rouge", "Rouge sport", "#FF0000", 100, ["#FF4B4B", "#C00000", "#5A0000"]),
        color("s-nuit", "Nuit bleue", "#1A3CFF", 45, ["#4D74FF", "#1A3CFF", "#060F55"]),
        color("s-violet", "Violet lounge", "#8A2BE2", 60, ["#C07BFF", "#8A2BE2", "#3A0D6B"]),
        color("s-chaud", "Blanc chaud", "#FFB46B", 70, ["#FFE2C2", "#FFB46B", "#8A4F1C"]),
        color("s-ambre", "Ambre rétro", "#FF7A00", 55, ["#FFC06B", "#FF7A00", "#7A2F00"]),
        color("s-menthe", "Menthe glacée", "#00FFB0", 70, ["#B4FFF0", "#00FFB0", "#00664A"]),
        color("s-rose", "Rose néon", "#FF1F8F", 80, ["#FF8CC6", "#FF1F8F", "#6B003A"]),
        color("s-cyan", "Bleu arctique", "#00C8FF", 75, ["#BFF1FF", "#00C8FF", "#004A66"]),

        grad("s-sunset", "Coucher de soleil", ["#FF4E00", "#FF0F6A", "#8A00FF"], speed: 35),
        grad("s-aurora", "Aurore boréale", ["#00FF9C", "#00D4FF", "#7A2BFF"], speed: 25, bri: 85),
        grad("s-ocean", "Océan", ["#0030FF", "#00A2FF", "#00FFD5"], bri: 85),
        grad("s-miami", "Miami", ["#FF2EA6", "#B14BFF", "#00E5FF"], speed: 35),
        grad("s-cyber", "Cyberpunk", ["#FF00C8", "#6A00FF", "#00F0FF"], speed: 45, bri: 100),
        grad("s-lave", "Lave", ["#FF0000", "#FF4D00", "#FF9900"], bri: 100),
        grad("s-foret", "Forêt", ["#00A84F", "#3CFF5A", "#C8FF00"], speed: 25, bri: 80),
        grad("s-bonbon", "Bonbon", ["#FF7AD9", "#B37AFF", "#7AD7FF"], bri: 80),
        grad("s-glace", "Glacier", ["#FFFFFF", "#9FE8FF", "#2A7BFF"], speed: 25, bri: 80),
        grad("s-braise", "Braise", ["#FF2A00", "#FF7A00", "#FFC400"], style: 1),
        grad("s-royal", "Royal", ["#1A2BFF", "#7A00FF", "#FFC400"], speed: 25, bri: 85),
        grad("s-pastel", "Pastel", ["#FFB3C7", "#FFE29A", "#B5F5C8", "#A8D8FF"], speed: 25, bri: 70),

        fx("s-rainbow", "Arc-en-ciel", EffectCatalog.autoID, speed: 40),
        fx("s-vague", "Vague bleue", 165, speed: 45, bri: 90),
        fx("s-k2000", "Scanner rouge", 101, speed: 60),
        fx("s-rideau", "Rideau 7 couleurs", 57, speed: 50),
        fx("s-flux", "Flux jaune · cyan", 51, speed: 50, bri: 90),
        grad("s-gyro", "Gyrophare", ["#FF0000", "#0030FF"], style: 2, speed: 70, bri: 100, cat: "Animées"),

        LightScene(id: "s-soiree", name: "Soirée", category: "Musique", mode: .music, micMode: 1, sensitivity: 95, brightness: 100, gradient: ["#6A11CB", "#FF2A8A"]),
        LightScene(id: "s-club", name: "Club", category: "Musique", mode: .music, micMode: 2, sensitivity: 100, brightness: 100, gradient: ["#00E5FF", "#6A00FF", "#FF00C8"]),
    ]

    static var categories: [String] {
        var seen: [String] = []
        for s in suggestions where !seen.contains(s.category) { seen.append(s.category) }
        return ["Toutes"] + seen
    }
}
