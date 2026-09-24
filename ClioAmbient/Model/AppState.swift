import SwiftUI
import Combine

enum LightMode: String, Codable { case color, effect, music, custom }

struct ZoneState: Codable, Equatable {
    var on = true
    var hex = "#FF0000"
    var brightness = 100
}

struct CustomEffect: Codable, Equatable {
    var slots: [String?] = ["#FF0000", "#0050FF", nil, nil, nil, nil, nil, nil]
    var style = 3
    var direction = 0
}

struct AppSettings: Codable, Equatable {
    var applyDefaultOnConnect = true
    var haptics = true
}

/// Tout ce qui est sauvegardé entre deux lancements.
struct PersistedState: Codable {
    var on = true
    var hue: Double = 0
    var sat: Double = 100
    var hex = "#FF0000"
    var brightness = 100
    var mode: LightMode = .color
    var effect: Int? = nil
    var speed = 50
    var micMode = 1
    var sensitivity = 90
    var target: LEDZone = .dmx
    var zones: [String: ZoneState] = ["dmx": ZoneState(hex: "#FF0000"), "rgb": ZoneState(hex: "#0050FF")]
    var custom = CustomEffect()
    var settings = AppSettings()
    var scenes: [LightScene] = []
    var favorites: [LightScene?] = [SceneLibrary.suggestions[0], SceneLibrary.suggestions[8], SceneLibrary.suggestions[20]]
}

/// État de l'appli + envoi des commandes au contrôleur.
final class AppState: ObservableObject {
    let ble = BLEManager()
    @Published var s: PersistedState { didSet { scheduleSave() } }
    @Published var toast: String?

    private var saveWork: DispatchWorkItem?
    private var bag = Set<AnyCancellable>()
    private static let storeKey = "clioambient.state.v1"

    init() {
        if let d = UserDefaults.standard.data(forKey: Self.storeKey), let st = try? JSONDecoder().decode(PersistedState.self, from: d) {
            s = st
        } else {
            s = PersistedState()
        }
        ble.onConnected = { [weak self] in self?.didConnect() }
        // Relaye les changements du BLE pour rafraîchir l'UI
        ble.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &bag)
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self, let d = try? JSONEncoder().encode(self.s) else { return }
            UserDefaults.standard.set(d, forKey: Self.storeKey)
        }
        saveWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: w)
    }

    // MARK: - Valeurs dérivées

    var rgb: RGB { ColorMath.hexToRGB(s.hex) ?? RGB(r: 255, g: 0, b: 0) }
    var colorName: String { ColorMath.name(h: s.hue, s: s.sat) }

    /// Couleur d'ambiance de l'interface (reflète ce que font les LED)
    var glow: Color {
        switch s.mode {
        case .color: return Color(hex: s.hex)
        case .music: return Color(hex: "#B34BFF")
        case .custom: return Color(hex: s.custom.slots.compactMap { $0 }.first ?? s.hex)
        case .effect:
            guard let id = s.effect, let g = EffectCatalog.byID[id]?.0 else { return Color(hex: "#FF8A00") }
            return Color(hex: g.palette[min(1, g.palette.count - 1)])
        }
    }
    var glowStrength: Double { s.on ? 0.3 + 0.45 * Double(s.brightness) / 100 : 0.08 }

    // MARK: - Connexion

    private func didConnect() {
        if s.settings.applyDefaultOnConnect {
            s.on = true; s.mode = .color; s.brightness = 100
            setHex("#FF0000", send: false)
        }
        resendState()
        flash("Connecté à \(ble.deviceName ?? "LEDCAR")")
    }

    func resendState() {
        ble.send("power", LED.power(s.on, s.target))
        switch s.mode {
        case .effect:
            if let e = s.effect { ble.send("effect", LED.effect(e)); ble.send("speed", LED.speed(s.speed)) }
        case .music: ble.send("voice", LED.voice(s.micMode))
        case .custom: playCustom(silent: true)
        case .color: let c = rgb; ble.send("color", LED.color(c.r, c.g, c.b, s.target))
        }
        ble.send("bri", LED.brightness(s.brightness, s.target))
    }

    // MARK: - Commandes

    func setPower(_ on: Bool) {
        s.on = on
        ble.send("power", LED.power(on, s.target))
    }

    private func ensureOn() { if !s.on { setPower(true) } }

    func setHex(_ hex: String, send: Bool = true, keepHS: Bool = false) {
        guard let c = ColorMath.hexToRGB(hex) else { return }
        var hue: Double?, sat: Double?
        if !keepHS {
            let hsv = ColorMath.rgbToHSV(c)
            if hsv.s > 3 { hue = hsv.h }
            sat = hsv.s
        }
        applyColor(c, hue: hue, sat: sat, send: send)
    }

    func setHueSat(_ h: Double, _ sat: Double) {
        let hue = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360).rounded()
        let sat = max(0, min(100, sat)).rounded()
        // Le glisser envoie ~120 évènements/s : on ignore ceux qui ne changent rien
        if hue == s.hue, sat == s.sat, s.mode == .color, s.on { return }
        applyColor(ColorMath.hsvToRGB(h: hue, s: sat, v: 100), hue: hue, sat: sat, send: true)
    }

    /// Modifications groupées sur une copie : une seule notification SwiftUI au lieu d'une par champ.
    private func applyColor(_ c: RGB, hue: Double?, sat: Double?, send: Bool) {
        var n = s
        n.hex = ColorMath.rgbToHex(c)
        if let hue { n.hue = hue }
        if let sat { n.sat = sat }
        n.mode = .color
        if send && !n.on { n.on = true; ble.send("power", LED.power(true, n.target)) }
        s = n
        if send { ble.send("color", LED.color(c.r, c.g, c.b, n.target)) }
    }

    func setBrightness(_ p: Int) {
        let v = max(1, min(100, p))
        var n = s
        n.brightness = v
        if !n.on { n.on = true; ble.send("power", LED.power(true, n.target)) }
        s = n
        ble.send("bri", LED.brightness(v, s.target))
    }

    func playEffect(_ id: Int) {
        s.effect = id; s.mode = .effect
        ble.send("effect", LED.effect(id)); ble.send("speed", LED.speed(s.speed)); ensureOn()
    }

    func setSpeed(_ p: Int) {
        s.speed = max(1, min(100, p))
        ble.send("speed", LED.speed(s.speed))
    }

    func setMic(_ n: Int) {
        s.micMode = max(1, min(255, n)); s.mode = .music
        ble.send("voice", LED.voice(s.micMode)); ensureOn()
    }

    func setSensitivity(_ v: Int) {
        s.sensitivity = max(1, min(100, v))
        ble.send("sens", LED.sensitivity(s.sensitivity)); ble.send("sensRgb", LED.sensitivityRGB(s.sensitivity))
    }

    func voiceRGB(_ n: Int) { ble.send("voiceRgb", LED.voiceRGB(n)); ensureOn() }

    func setTarget(_ z: LEDZone) { s.target = z; resendState() }

    func zone(_ key: String) -> ZoneState { s.zones[key] ?? ZoneState() }
    func setZonePower(_ key: String, _ on: Bool) {
        guard let z = LEDZone(rawValue: key) else { return }
        s.zones[key, default: ZoneState()].on = on
        ble.send("zp" + key, LED.power(on, z))
    }
    func setZoneBrightness(_ key: String, _ p: Int) {
        guard let z = LEDZone(rawValue: key) else { return }
        s.zones[key, default: ZoneState()].brightness = p
        ble.send("zb" + key, LED.brightness(p, z))
    }
    func setZoneColorToCurrent(_ key: String) {
        guard let z = LEDZone(rawValue: key) else { return }
        s.zones[key, default: ZoneState()].hex = s.hex
        let c = rgb
        ble.send("zc" + key, LED.color(c.r, c.g, c.b, z))
    }
    func identify(_ key: String) {
        guard let z = LEDZone(rawValue: key) else { return }
        flash("Regarde quelles LED clignotent en blanc…")
        let restore = ColorMath.hexToRGB(zone(key).hex) ?? RGB(r: 255, g: 0, b: 0)
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.35) { [weak self] in
                let w = i % 2 == 0 ? 255 : 0
                self?.ble.send("zid" + key, LED.color(w, w, w, z))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            self?.ble.send("zid" + key, LED.color(restore.r, restore.g, restore.b, z))
        }
    }

    func playCustom(silent: Bool = false) {
        let cols = s.custom.slots.compactMap { $0 }.compactMap(ColorMath.hexToRGB)
        guard !cols.isEmpty else { flash("Ajoute au moins une couleur"); return }
        for (i, c) in cols.enumerated() {
            ble.send("cc\(i)", LED.customColor(index: i + 1, c.r, c.g, c.b, count: cols.count))
        }
        ble.send("cmode", LED.customMode(s.custom.style))
        ble.send("cdir", LED.direction(s.custom.direction))
        s.mode = .custom; ensureOn()
        if !silent { flash("Effet personnalisé lancé") }
    }

    // MARK: - Scènes

    func apply(_ sc: LightScene) {
        s.on = true; ble.send("power", LED.power(true, s.target))
        switch sc.mode {
        case .color: setHex(sc.hex ?? "#FF0000")
        case .effect:
            if let sp = sc.speed { s.speed = sp }
            playEffect(sc.effect ?? EffectCatalog.autoID)
        case .music:
            if let v = sc.sensitivity { setSensitivity(v) }
            setMic(sc.micMode ?? 1)
        case .custom:
            var slots: [String?] = (sc.colors ?? []).map { Optional($0) }
            while slots.count < 8 { slots.append(nil) }
            s.custom = CustomEffect(slots: Array(slots.prefix(8)), style: sc.style ?? 3, direction: sc.direction ?? 0)
            if let sp = sc.speed { setSpeed(sp) }
            playCustom(silent: true)
        }
        setBrightness(sc.brightness)
        flash("« \(sc.name) »")
    }

    func snapshot(named name: String) -> LightScene {
        switch s.mode {
        case .effect: return LightScene(name: name, mode: .effect, effect: s.effect, speed: s.speed, brightness: s.brightness)
        case .music: return LightScene(name: name, mode: .music, micMode: s.micMode, sensitivity: s.sensitivity, brightness: s.brightness)
        case .custom: return LightScene(name: name, mode: .custom, colors: s.custom.slots.compactMap { $0 }, style: s.custom.style,
                                        direction: s.custom.direction, speed: s.speed, brightness: s.brightness)
        case .color: return LightScene(name: name, mode: .color, hex: s.hex, brightness: s.brightness)
        }
    }

    var currentLabel: String {
        switch s.mode {
        case .effect: return EffectCatalog.title(for: s.effect)
        case .music: return "Musique \(s.micMode)"
        case .custom: return "Mon dégradé"
        case .color: return colorName
        }
    }

    func saveScene(named name: String) {
        let n = name.trimmingCharacters(in: .whitespaces)
        s.scenes.append(snapshot(named: n.isEmpty ? "Scène \(s.scenes.count + 1)" : n))
        flash("Scène enregistrée")
    }

    // MARK: - Retours

    func flash(_ msg: String) {
        toast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            if self?.toast == msg { self?.toast = nil }
        }
    }
}
