import SwiftUI

/// Regroupe les 210 effets DMX en familles lisibles (en français),
/// en fusionnant les paires « Avant / Arrière » et « Ouvrir / Fermer ».
struct EffectGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let palette: [String]            // couleurs hex pour l'aperçu
    var ids: [EffectDirection: Int]  // sens → id d'effet
    var search: String

    var directions: [EffectDirection] { EffectDirection.allCases.filter { ids[$0] != nil } }
    var firstID: Int { ids[directions[0]]! }
    var isFlash: Bool { category == "Flash" }
}

enum EffectDirection: String, CaseIterable, Hashable {
    case forward, backward, open, close, single
    var label: String {
        switch self {
        case .forward: return "→ Avant"
        case .backward: return "← Arrière"
        case .open: return "Ouvrir"
        case .close: return "Fermer"
        case .single: return "—"
        }
    }
    var reversed: Bool { self == .backward || self == .close }
}

enum EffectCatalog {
    static let autoID = 255
    static let rainbow = ["#FF2A2A", "#FF8A00", "#FFD21F", "#22E04A", "#1FE0FF", "#2A5BFF", "#A23BFF"]
    static let col: [String: String] = ["RD": "#FF2A2A", "GN": "#22E04A", "BU": "#2A5BFF", "YE": "#FFD21F", "CN": "#1FE0FF", "VT": "#A23BFF",
                                        "WH": "#FFFFFF", "BK": "#0B0B0B", "ON": "#FF7A00", "E": "#FF2A2A", "R": "#FF2A2A", "G": "#22E04A",
                                        "B": "#2A5BFF", "Y": "#FFD21F", "C": "#1FE0FF", "P": "#A23BFF"]
    static let fr: [String: String] = ["RD": "rouge", "GN": "vert", "BU": "bleu", "YE": "jaune", "CN": "cyan", "VT": "violet", "WH": "blanc",
                                       "BK": "noir", "ON": "orange", "E": "", "R": "rouge", "G": "vert", "B": "bleu", "Y": "jaune", "C": "cyan", "P": "violet"]
    /// (préfixe anglais, titre français, catégorie)
    static let families: [(String, String, String)] = [
        ("Curtain Swab", "Rideau balayé", "Rideau"), ("Curtain", "Rideau", "Rideau"), ("Follow Spot", "Poursuite", "Poursuite"),
        ("Horse Race", "Course", "Course"), ("Trailing", "Traînée", "Traînée"), ("Streaming", "Flux", "Flux"),
        ("Flutter", "Scintillement", "Scintillement"), ("Swab", "Balayage", "Balayage"), ("Flow", "Vague", "Vague"),
        ("Run", "Défilement", "Défilement"), ("Hop", "Saut", "Flash"), ("Strobe", "Stroboscope", "Flash"),
        ("Gradual", "Fondu", "Fondu"), ("Dreaming", "Rêve", "Couleurs"), ("6 Colors", "6 couleurs", "Couleurs"), ("7 Colors", "7 couleurs", "Couleurs"),
    ]

    static let groups: [EffectGroup] = build()
    static let byID: [Int: (EffectGroup, EffectDirection)] = {
        var m: [Int: (EffectGroup, EffectDirection)] = [:]
        for g in groups { for (d, id) in g.ids { m[id] = (g, d) } }
        return m
    }()
    static var categories: [String] {
        var seen: [String] = []
        for g in groups where !seen.contains(g.category) { seen.append(g.category) }
        return ["Tous"] + seen
    }

    static func title(for id: Int?) -> String {
        guard let id else { return "Aucun effet" }
        if id == autoID { return "Auto — tous les effets" }
        return byID[id]?.0.title ?? "Effet \(id)"
    }

    /// Équivalent d'un effet Symphonie pour le canal RGB : les effets multicolores deviennent un programme
    /// 7 couleurs (saut pour les flashs, fondu sinon), les effets à une ou deux couleurs leur couleur dominante.
    static func rgbCompanion(for id: Int) -> RGBCompanion {
        guard let (g, _) = byID[id] else { return .mode(RGBMode.fade7) }
        let chroma = g.palette.filter { $0 != "#000000" && $0 != "#0B0B0B" }
        var distinct: [String] = []
        for c in chroma where !distinct.contains(c) { distinct.append(c) }
        if Set(distinct) == [col["RD"]!, col["GN"]!, col["BU"]!] { return .mode(g.isFlash ? RGBMode.jump3 : RGBMode.fade3) }
        if distinct.count >= 3 { return .mode(g.isFlash ? RGBMode.jump7 : RGBMode.fade7) }
        // « blanc · bleu · blanc » : c'est le bleu qui donne le ton
        let main = distinct.first { $0 != "#FFFFFF" } ?? distinct.first
        guard let main, let c = ColorMath.hexToRGB(main) else { return .mode(RGBMode.fade7) }
        return .color(c)
    }

    private static func build() -> [EffectGroup] {
        var order: [String] = []
        var map: [String: EffectGroup] = [:]
        for (id, name) in rawEffects {
            var rest = name
            var dir: EffectDirection = .single
            for (prefix, d) in [("Forward ", EffectDirection.forward), ("Backward ", .backward), ("Open ", .open), ("Close ", .close)] where rest.hasPrefix(prefix) {
                dir = d; rest = String(rest.dropFirst(prefix.count)); break
            }
            let fam = families.first(where: { rest == $0.0 || rest.hasPrefix($0.0 + " ") }) ?? ("", "Chenillard", "Couleurs")
            let colorPart = String(rest.dropFirst(fam.0.count)).trimmingCharacters(in: .whitespaces)
            let upper = colorPart.uppercased()
            var palette: [String]
            var label = ""
            if upper.contains("7 COLOR") || (colorPart.isEmpty && (fam.0 == "Dreaming" || fam.0 == "7 Colors")) {
                if let r = upper.range(of: " ON ") {
                    let bg = col[String(upper[r.upperBound...]).trimmingCharacters(in: .whitespaces)] ?? "#000000"
                    palette = [bg] + rainbow + [bg]
                    label = "7 couleurs sur " + (fr[String(upper[r.upperBound...]).trimmingCharacters(in: .whitespaces)] ?? "")
                } else {
                    palette = rainbow
                    label = upper.contains("7 COLOR") ? "7 couleurs" : ""
                }
            } else if upper.contains(" ON ") {
                let parts = upper.components(separatedBy: " ON ").map { $0.trimmingCharacters(in: .whitespaces) }
                let a = parts[0], b = parts.count > 1 ? parts[1] : parts[0]
                palette = [col[b] ?? "#000000", col[a] ?? "#FFFFFF", col[b] ?? "#000000", col[b] ?? "#000000"]
                label = "\(fr[a] ?? a) sur \(fr[b] ?? b)"
            } else if !colorPart.isEmpty {
                let toks = upper.split(whereSeparator: { $0 == "/" || $0 == " " }).map(String.init).filter { col[$0] != nil }
                palette = toks.compactMap { col[$0] }
                label = toks.compactMap { fr[$0] }.filter { !$0.isEmpty }.joined(separator: " · ")
                if fam.0 == "6 Colors", let first = palette.first { palette = [first] + rainbow.prefix(5) }
            } else {
                palette = rainbow
            }
            if palette.count == 1 { palette = [palette[0], "#000000", palette[0], "#000000"] }
            if palette.isEmpty { palette = rainbow }

            var key = fam.0 + "|" + upper
            while let g = map[key], g.ids[dir] != nil { key += "+" }
            if map[key] == nil {
                map[key] = EffectGroup(id: key, title: fam.1 + (label.isEmpty ? "" : " " + label), category: fam.2,
                                       palette: palette, ids: [:], search: "")
                order.append(key)
            }
            map[key]!.ids[dir] = id
            map[key]!.search += " " + name.lowercased()
        }
        return order.compactMap { k in
            guard var g = map[k] else { return nil }
            g.search = (g.title + " " + g.category + " " + g.search).lowercased().folding(options: .diacriticInsensitive, locale: .current)
            return g
        }
    }
}
