import SwiftUI

struct AdvancedView: View {
    @EnvironmentObject var app: AppState
    @State private var hue: Double = 0
    @State private var sat: Double = 100
    @State private var bri: Double = 100
    @State private var kelvin: Double = 6500
    @State private var speed: Double = 100
    @State private var r: Double = 255
    @State private var g: Double = 0
    @State private var b: Double = 0
    @State private var hexText = "#FF0000"
    @State private var showRGB = false
    @State private var showConsole = false
    @State private var raw = ""
    @FocusState private var hexFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PageHeader(title: "Avancé")
                ConnectCard()
                wheelCard
                zonesCard
                customCard
                settingsCard
            }
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .onAppear(perform: syncFromState)
        .onChange(of: app.s.hex) { _, _ in syncFromState() }
        .onChange(of: app.s.brightness) { _, v in bri = Double(v) }
        .onChange(of: app.s.speed) { _, v in speed = Double(v) }
    }

    private func syncFromState() {
        hue = app.s.hue; sat = app.s.sat; bri = Double(app.s.brightness); speed = Double(app.s.speed)
        let c = app.rgb; r = Double(c.r); g = Double(c.g); b = Double(c.b)
        if !hexFocused { hexText = app.s.hex }
    }

    // MARK: Roue chromatique
    private var wheelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Roue chromatique")
            ColorWheel(maxSize: 290).padding(.vertical, 4)

            TrackSlider(label: "T", value: $hue, range: 0...359,
                        track: LinearGradient(colors: Color.hueStops, startPoint: .leading, endPoint: .trailing),
                        display: "\(Int(hue))°", detents: ColorWheel.marks.map(\.hue).filter { $0 > 0 }) { app.setHueSat($0, sat) }
            TrackSlider(label: "S", value: $sat, range: 0...100,
                        track: LinearGradient(colors: [.white, Color.hue(hue)], startPoint: .leading, endPoint: .trailing),
                        display: "\(Int(sat)) %", detents: [25, 50, 75]) { app.setHueSat(hue, $0) }
            TrackSlider(label: "L", value: $bri, range: 1...100,
                        track: LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing),
                        display: "\(Int(bri)) %", detents: Detents.percent) { app.setBrightness(Int($0)) }
            TrackSlider(label: "K", value: $kelvin, range: 1800...10000,
                        track: LinearGradient(colors: [Color(hex: "#FF8A1C"), Color(hex: "#FFD6A5"), .white, Color(hex: "#CFE0FF"), Color(hex: "#9FBFFF")], startPoint: .leading, endPoint: .trailing),
                        display: "\(Int(kelvin))K") { app.setHex(ColorMath.rgbToHex(ColorMath.kelvinToRGB($0))) }

            DisclosureGroup(isExpanded: $showRGB) {
                VStack(spacing: 4) {
                    TrackSlider(label: "R", value: $r, range: 0...255, track: LinearGradient(colors: [.black, .red], startPoint: .leading, endPoint: .trailing),
                                display: "\(Int(r))") { app.setHex(ColorMath.rgbToHex(RGB(r: Int($0), g: Int(g), b: Int(b)))) }
                    TrackSlider(label: "V", value: $g, range: 0...255, track: LinearGradient(colors: [.black, .green], startPoint: .leading, endPoint: .trailing),
                                display: "\(Int(g))") { app.setHex(ColorMath.rgbToHex(RGB(r: Int(r), g: Int($0), b: Int(b)))) }
                    TrackSlider(label: "B", value: $b, range: 0...255, track: LinearGradient(colors: [.black, .blue], startPoint: .leading, endPoint: .trailing),
                                display: "\(Int(b))") { app.setHex(ColorMath.rgbToHex(RGB(r: Int(r), g: Int(g), b: Int($0)))) }
                }
                .padding(.top, 6)
            } label: {
                Text("Canaux RVB").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            }
            .tint(.secondary)

            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: app.s.hex)).frame(width: 46, height: 46)
                TextField("#FF0000", text: $hexText)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .focused($hexFocused)
                    .padding(.horizontal, 14).frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.08)))
                    .onSubmit(applyHex)
                Button(action: applyHex) {
                    Text("OK").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .frame(width: 56, height: 46)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.12)))
                }
                .buttonStyle(PressStyle())
            }
        }
        .card()
    }

    private func applyHex() {
        var t = hexText.trimmingCharacters(in: .whitespaces)
        if !t.hasPrefix("#") { t = "#" + t }
        if ColorMath.hexToRGB(t) != nil {
            Haptics.tap(); app.setHex(t); hexFocused = false
        } else {
            Haptics.edge(); app.flash("Code couleur invalide (ex. #FF3300)")
        }
    }

    // MARK: Zones
    private var zonesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Zones")
            Text("Le contrôleur a deux sorties pilotables séparément : **Symphonie** (bandes adressables, effets) et **RGB** (bandes simples). « Identifier » fait clignoter les LED branchées sur chaque sortie.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("Couleurs, effets, musique et scènes pilotent :").font(.footnote).foregroundStyle(.secondary)
            Picker("Cible", selection: Binding(get: { app.s.target }, set: { Haptics.selection(); app.setTarget($0) })) {
                ForEach(LEDZone.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            ZoneRow(key: "dmx", title: "Symphonie", subtitle: "Bandes adressables · effets")
            ZoneRow(key: "rgb", title: "RGB", subtitle: "Bandes simples")
        }
        .card()
    }

    // MARK: Effet personnalisé
    private var customCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Effet personnalisé")
            Text("Touche une case pour y mettre la couleur actuelle, touche-la à nouveau pour la vider.")
                .font(.footnote).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(0..<8, id: \.self) { i in
                    let c = app.s.custom.slots[i]
                    Button {
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.2)) { app.s.custom.slots[i] = c == nil ? app.s.hex : nil }
                    } label: {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(c.map { Color(hex: $0) } ?? Color.white.opacity(0.07))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(.white.opacity(c == nil ? 0.15 : 0.35), lineWidth: 1))
                            .overlay { if c == nil { Image(systemName: "plus").foregroundStyle(.secondary) } }
                    }
                    .buttonStyle(PressStyle())
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(CustomStyle.all) { st in
                    let on = app.s.custom.style == st.id
                    Button { Haptics.selection(); app.s.custom.style = st.id } label: {
                        Text(st.name).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity).frame(height: 36)
                            .foregroundStyle(on ? .black : .white.opacity(0.8))
                            .background(Capsule().fill(on ? .white : .white.opacity(0.1)))
                            .animation(.snappy(duration: 0.2), value: on)
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            GlassSlider(title: "Vitesse", systemImage: "speedometer", value: $speed, tint: app.glow, height: 42,
                        detents: Detents.percent) { app.setSpeed(Int($0)) }
            HStack(spacing: 8) {
                Picker("Sens", selection: $app.s.custom.direction) {
                    Text("→ Avant").tag(0); Text("← Arrière").tag(1)
                }
                .pickerStyle(.segmented)
                Button { Haptics.tap(); app.playCustom() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: app.s.mode == .custom && app.s.on ? "checkmark" : "play.fill").font(.caption.weight(.bold))
                        Text(app.s.mode == .custom && app.s.on ? "Actif" : "Lancer")
                    }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.black)
                    .padding(.horizontal, 16).frame(height: 34).background(Capsule().fill(.white))
                    .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(PressStyle())
            }
        }
        .card()
    }

    // MARK: Réglages
    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Réglages").padding(.bottom, 8)
            Toggle(isOn: $app.s.settings.applyDefaultOnConnect) {
                VStack(alignment: .leading) {
                    Text("État au démarrage").font(.body.weight(.semibold))
                    Text("Allume en rouge à 100 % à chaque connexion").font(.caption).foregroundStyle(.secondary)
                }
            }
            .tint(.green)
            .padding(.vertical, 8)
            Divider().opacity(0.3)
            Toggle(isOn: $app.s.settings.haptics) {
                VStack(alignment: .leading) {
                    Text("Retour haptique").font(.body.weight(.semibold))
                    Text("Vibrations légères au toucher").font(.caption).foregroundStyle(.secondary)
                }
            }
            .tint(.green)
            .padding(.vertical, 8)
            Divider().opacity(0.3)
            HStack {
                VStack(alignment: .leading) {
                    Text("Contrôleur").font(.body.weight(.semibold))
                    Text(app.ble.deviceName ?? "—").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if app.ble.isConnected {
                    Button("Déconnecter") { app.ble.disconnect() }.buttonStyle(.bordered).tint(.white)
                } else {
                    Button("Rechercher") { app.ble.startScan() }.buttonStyle(.bordered).tint(.white)
                }
            }
            .padding(.vertical, 8)
            Divider().opacity(0.3)
            DisclosureGroup(isExpanded: $showConsole) {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("7B FF 04 01 FF FF FF FF BF", text: $raw)
                            .font(.system(.footnote, design: .monospaced))
                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                            .padding(.horizontal, 12).frame(height: 40)
                            .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08)))
                        Button("Envoyer", action: sendRaw).buttonStyle(.bordered).tint(.white)
                    }
                    ConsoleLog(console: app.ble.console)
                }
                .padding(.top, 8)
            } label: {
                Text("Console développeur").font(.body.weight(.semibold))
            }
            .tint(.secondary)
            .padding(.vertical, 8)
        }
        .card()
    }

    private func sendRaw() {
        let bytes = raw.uppercased().split(whereSeparator: { !$0.isHexDigit }).joined()
        let chars = Array(bytes)
        guard chars.count == 18 else { app.flash("Une trame fait 9 octets"); return }
        let data = Data(stride(from: 0, to: 18, by: 2).compactMap { UInt8(String(chars[$0...$0 + 1]), radix: 16) })
        app.ble.send("raw\(Date().timeIntervalSince1970)", data)
    }
}

/// Une sortie du contrôleur (Symphonie ou RGB)
struct ZoneRow: View {
    @EnvironmentObject var app: AppState
    var key: String
    var title: String
    var subtitle: String
    @State private var bri: Double = 100

    var body: some View {
        let z = app.zone(key)
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Circle().fill(Color(hex: z.hex)).frame(width: 30, height: 30).shadow(color: Color(hex: z.hex), radius: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.body.weight(.semibold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { z.on }, set: { Haptics.selection(); app.setZonePower(key, $0) })).labelsHidden().tint(.green)
            }
            GlassSlider(title: "Luminosité", systemImage: "sun.max", value: $bri, tint: Color(hex: z.hex), height: 40, detents: Detents.percent) { app.setZoneBrightness(key, Int($0)) }
            HStack(spacing: 8) {
                PillButton(title: "Couleur actuelle", systemImage: "paintbrush.fill") { app.setZoneColorToCurrent(key) }
                PillButton(title: "Identifier", systemImage: "lightbulb.max") { app.identify(key) }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.05)))
        .onAppear { bri = Double(z.brightness) }
        .onChange(of: z.brightness) { _, v in bri = Double(v) }
    }
}

/// Journal BLE : observe directement la console pour ne pas redessiner le reste de l'appli à chaque trame.
private struct ConsoleLog: View {
    @ObservedObject var console: BLEConsole

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(console.lines) { l in
                        Text(l.text).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).id(l.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            .frame(height: 180)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.35)))
            .onChange(of: console.lines.last?.id) { _, id in if let id { proxy.scrollTo(id, anchor: .bottom) } }
        }
    }
}
