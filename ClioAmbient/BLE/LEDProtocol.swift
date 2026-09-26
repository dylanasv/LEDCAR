import Foundation
import CoreBluetooth

/// Protocole du contrôleur LEDCAR-01 (voir protocole-ledcar-01.md).
/// Toutes les trames font 9 octets et s'écrivent sur la caractéristique FFE1.
enum LEDZone: String, Codable, CaseIterable, Identifiable {
    case dmx, rgb, sync
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dmx: return "Symphonie"
        case .rgb: return "RGB"
        case .sync: return "Les deux"
        }
    }
}

enum LEDUUID {
    static let service = CBUUID(string: "FFE0")
    static let write = CBUUID(string: "FFE1")
    static let notify = CBUUID(string: "FFF4")
    static let namePrefix = "LEDCAR"
}

enum LED {
    /// Famille « Symphonie / DMX » : 7B … BF
    static func f7B(_ b: [Int]) -> Data { Data(([0x7B] + b + [0xBF]).map { UInt8(clamping: $0) }) }
    /// Famille « RGB » : 7E … EF
    static func f7E(_ b: [Int]) -> Data { Data(([0x7E] + b + [0xEF]).map { UInt8(clamping: $0) }) }
    private static func sc(_ p: Int) -> Int { Int((Double(p) * 32 / 100).rounded()) }

    static func power(_ on: Bool, _ z: LEDZone = .dmx) -> Data {
        switch z {
        case .rgb: return f7E([0xFF, 4, on ? 1 : 0, 255, 255, 255, 255])
        case .sync: return f7B([0xFF, 4, on ? 7 : 6, 255, 255, 255, 255])
        case .dmx: return f7B([0xFF, 4, on ? 1 : 0, 255, 255, 255, 255])
        }
    }
    static func color(_ r: Int, _ g: Int, _ b: Int, _ z: LEDZone = .dmx) -> Data {
        switch z {
        case .rgb: return f7E([0xFF, 5, 3, r, g, b, 0xFF])
        case .sync: return f7B([1, 7, r, g, b, 0, 0xFF])
        case .dmx: return f7B([0, 7, r, g, b, 0, 0xFF])
        }
    }
    static func brightness(_ p: Int, _ z: LEDZone = .dmx) -> Data {
        switch z {
        case .rgb: return f7E([0xFF, 1, p, 0, 255, 255, 255])
        case .sync: return f7B([0xFF, 1, sc(p), p, 2, 255, 255])
        case .dmx: return f7B([0xFF, 1, sc(p), p, 0, 255, 255])
        }
    }
    static func effect(_ id: Int) -> Data { f7B([0xFF, 3, id, 255, 255, 255, 255]) }
    static func speed(_ p: Int) -> Data { f7B([0xFF, 2, p, 0xFF, 0, 255, 255]) }
    static func direction(_ d: Int) -> Data { f7B([0xFF, 0x0D, d, 255, 255, 255, 255]) }
    static func voice(_ n: Int) -> Data { f7B([0xFF, 0x0B, n, 0, 255, 255, 255]) }
    static func sensitivity(_ s: Int) -> Data { f7B([0xFF, 0x0C, s, 0, 255, 255, 255]) }
    static func voiceRGB(_ n: Int) -> Data { f7E([0, 0x0E, n, 255, 255, 255, 255]) }
    /// Programme animé intégré au canal RGB (famille ELK-BLEDOM, voir `RGBMode`)
    static func modeRGB(_ m: Int) -> Data { f7E([0xFF, 3, m, 3, 255, 255, 255]) }
    static func speedRGB(_ p: Int) -> Data { f7E([0xFF, 2, p, 0, 255, 255, 255]) }
    static func sensitivityRGB(_ s: Int) -> Data { f7E([0xFF, 7, s, 255, 255, 255, 255]) }
    static func customColor(index: Int, _ r: Int, _ g: Int, _ b: Int, count: Int) -> Data { f7B([index, 0x0E, 253, r, g, b, count]) }
    static func customMode(_ style: Int) -> Data { f7B([0xFF, 0x13, style, 255, 255, 255, 255]) }

    /// Réglage des barres Symphonie (appli d'origine, `setConfigSPI`) : nombre de LED sur lequel le contrôleur
    /// étale ses effets, et ordre des couleurs (1 RGB, 2 RBG, 3 GRB, 4 GBR, 5 BRG, 6 BGR).
    /// Trame confirmée sur une vraie config « 132 pixels, GRB » : 7B FF 05 04 00 84 03 FF BF.
    static func configSPI(pixels: Int, order: Int) -> Data { f7B([0xFF, 5, 4, 0, pixels, order, 0xFF]) }

    static func hex(_ d: Data) -> String { d.map { String(format: "%02X", $0) }.joined(separator: " ") }
}

/// Programmes animés du canal RGB (bandes simples, une couleur à la fois).
/// Codes de la famille ELK-BLEDOM, dont le canal 7E…EF reprend déjà les trames couleur et luminosité.
enum RGBMode {
    static let jump3 = 0x87        // saut rouge · vert · bleu
    static let jump7 = 0x88        // saut 7 couleurs
    static let fade3 = 0x89        // fondu rouge · vert · bleu
    static let fade7 = 0x8A        // fondu 7 couleurs (arc-en-ciel)
    static let flash7 = 0x95       // flash 7 couleurs
}

/// Ce que doit faire le canal RGB pour accompagner ce qui tourne sur la Symphonie.
enum RGBCompanion: Equatable {
    case color(RGB)
    /// Programme animé, précédé de sa couleur principale : si le contrôleur ignore le programme,
    /// les LED RGB suivent quand même la Symphonie au lieu de garder la couleur précédente.
    case mode(Int, main: RGB)
    case music(Int)
}
