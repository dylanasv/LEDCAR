import SwiftUI
import UIKit

// MARK: - Retour haptique

/// Retours haptiques centralisés : un seul interrupteur (Réglages → Retour haptique) les coupe tous.
enum Haptics {
    static var enabled = true
    private static let selectionGen = UISelectionFeedbackGenerator()
    private static let lightGen = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private static let rigidGen = UIImpactFeedbackGenerator(style: .rigid)
    private static let notifGen = UINotificationFeedbackGenerator()

    /// Changement de sélection (pastille, scène, effet…)
    static func selection() { guard enabled else { return }; selectionGen.selectionChanged() }
    /// Appui sur un bouton d'action
    static func tap() { guard enabled else { return }; lightGen.impactOccurred() }
    /// Action marquante (alimentation)
    static func impact() { guard enabled else { return }; mediumGen.impactOccurred() }
    /// Butée d'un curseur (0 % / 100 %)
    static func edge() { guard enabled else { return }; rigidGen.impactOccurred(intensity: 0.7) }
    static func success() { guard enabled else { return }; notifGen.notificationOccurred(.success) }
}

// MARK: - Verre liquide

extension View {
    /// Carte en verre : vrai « Liquid Glass » sur iOS 26, matériau translucide sinon.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 26, tint: Color? = nil) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint.opacity(0.25)), in: .rect(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            self.modifier(FallbackGlass(cornerRadius: cornerRadius, tint: tint))
        }
        #else
        self.modifier(FallbackGlass(cornerRadius: cornerRadius, tint: tint))
        #endif
    }

    func card() -> some View {
        self.padding(18).frame(maxWidth: .infinity, alignment: .leading).glassCard()
    }
}

struct FallbackGlass: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color?
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(shape.fill(.ultraThinMaterial))
            .background(shape.fill((tint ?? .white).opacity(tint == nil ? 0.03 : 0.18)))
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.04), .white.opacity(0.16)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
    }
}

// MARK: - Fond ambiant

struct AmbientBackground: View {
    var color: Color
    var strength: Double
    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                Color(red: 0.027, green: 0.03, blue: 0.047)
                Group {
                    Glow(color: color, diameter: w * 1.1).offset(x: drift ? -w * 0.2 : -w * 0.35, y: drift ? -geo.size.height * 0.3 : -geo.size.height * 0.38)
                        .opacity(0.9)
                    Glow(color: color, diameter: w * 0.9).offset(x: drift ? w * 0.4 : w * 0.3, y: drift ? geo.size.height * 0.28 : geo.size.height * 0.2)
                        .opacity(0.5)
                    Glow(color: Color(red: 0.23, green: 0.36, blue: 1), diameter: w * 0.7).offset(x: drift ? w * 0.1 : -w * 0.05, y: geo.size.height * 0.1)
                        .opacity(0.3)
                }
                .opacity(strength)
            }
            .overlay(RadialGradient(colors: [.clear, .black.opacity(0.6)], center: .top, startRadius: w * 0.4, endRadius: geo.size.height))
            .animation(.easeInOut(duration: 0.6), value: color)
            .animation(.easeInOut(duration: 0.6), value: strength)
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) { drift = true } }
    }
}

/// Tache de lumière floue. Un dégradé radial donne le même rendu qu'un `.blur(radius: 90)`
/// sans le coût GPU d'un flou plein écran recalculé à chaque changement de couleur.
private struct Glow: View {
    var color: Color
    var diameter: CGFloat
    private let spread: CGFloat = 90

    var body: some View {
        let r = diameter / 2 + spread
        Circle()
            .fill(RadialGradient(stops: [.init(color: color, location: 0),
                                         .init(color: color.opacity(0.85), location: 0.3),
                                         .init(color: color.opacity(0.35), location: 0.6),
                                         .init(color: color.opacity(0), location: 1)],
                                 center: .center, startRadius: 0, endRadius: r))
            .frame(width: r * 2, height: r * 2)
    }
}

// MARK: - Slider en verre

struct GlassSlider: View {
    var title: String
    var systemImage: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 1...100
    var tint: Color = .white
    var height: CGFloat = 54
    var format: (Double) -> String = { "\(Int($0)) %" }
    /// Valeurs « aimantées » avec un petit cran haptique (ex. `Detents.percent`)
    var detents: [Double] = []
    var onChange: (Double) -> Void
    @State private var drag = SliderDrag()

    var body: some View {
        GeometryReader { geo in
            // Pendant le glisser, le remplissage suit le doigt en continu (pas d'arrondi à l'entier)
            let shown = drag.live ?? value
            let p = (shown - range.lowerBound) / (range.upperBound - range.lowerBound)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule().fill(LinearGradient(colors: [tint.opacity(0.45), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, geo.size.width * p))
                DetentTicks(detents: detents, range: range, width: geo.size.width, height: height)
                HStack {
                    Label(title, systemImage: systemImage).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(format(value)).font(.subheadline.weight(.semibold).monospacedDigit())
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 3)
                .padding(.horizontal, 18)
            }
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let np = max(0, min(1, g.location.x / geo.size.width))
                drag.update(range.lowerBound + np * (range.upperBound - range.lowerBound), range: range, detents: detents,
                            value: $value, onChange: onChange)
            }.onEnded { _ in drag.end(value: value, onChange: onChange) })
            .scaleEffect(drag.live != nil ? 1.015 : 1)
            .animation(.spring(duration: 0.25), value: drag.live != nil)
        }
        .frame(height: height)
    }
}

enum Detents {
    /// Crans des curseurs en pourcentage (luminosité, vitesse)
    static let percent: [Double] = [10, 25, 50, 75, 100]
}

/// Petits repères sur la piste aux emplacements des crans (les butées n'en ont pas besoin)
private struct DetentTicks: View {
    var detents: [Double]
    var range: ClosedRange<Double>
    var width: CGFloat
    var height: CGFloat

    var body: some View {
        ForEach(detents.filter { $0 > range.lowerBound && $0 < range.upperBound }, id: \.self) { d in
            Capsule().fill(.white.opacity(0.3))
                .frame(width: 2, height: height * 0.22)
                .offset(x: width * (d - range.lowerBound) / (range.upperBound - range.lowerBound) - 1, y: height * 0.3)
        }
        .allowsHitTesting(false)
    }
}

/// Logique commune des curseurs : valeur continue à l'écran, envoi limité à ~30 Hz,
/// dernière valeur toujours envoyée au relâcher. Vibration aux butées et aux crans,
/// qui « aimantent » la valeur quand le doigt passe tout près.
struct SliderDrag {
    var live: Double?
    private var lastSent: Double?
    private var lastSendTime: TimeInterval = 0
    private var atEdge = false
    private var atDetent: Double?

    mutating func update(_ raw: Double, range: ClosedRange<Double>, detents: [Double] = [], value: Binding<Double>, onChange: (Double) -> Void) {
        // Zone d'aimantation : 2,5 % de la course de part et d'autre du cran
        let snap = (range.upperBound - range.lowerBound) * 0.025
        let detent = detents.first { abs(raw - $0) <= snap }
        live = detent ?? raw
        let nv = (detent ?? raw).rounded()
        if nv != value.wrappedValue { value.wrappedValue = nv }

        let edge = nv <= range.lowerBound || nv >= range.upperBound
        if edge && !atEdge { Haptics.edge() }
        else if let detent, detent != atDetent, !edge { Haptics.selection() }
        atEdge = edge
        atDetent = detent

        let now = ProcessInfo.processInfo.systemUptime
        if nv != lastSent && (now - lastSendTime > 0.033 || edge) {
            lastSent = nv; lastSendTime = now
            onChange(nv)
        }
    }

    mutating func end(value: Double, onChange: (Double) -> Void) {
        if lastSent != value { onChange(value) }
        live = nil; lastSent = nil; atEdge = false; atDetent = nil
    }
}

/// Petit slider de réglage fin (roue chromatique, RVB, Kelvin…)
struct TrackSlider: View {
    var label: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var track: LinearGradient
    var display: String
    var detents: [Double] = []
    var onChange: (Double) -> Void
    @State private var drag = SliderDrag()

    var body: some View {
        HStack(spacing: 12) {
            Text(label).font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(width: 18)
            GeometryReader { geo in
                let p = ((drag.live ?? value) - range.lowerBound) / (range.upperBound - range.lowerBound)
                ZStack(alignment: .leading) {
                    Capsule().fill(track).frame(height: 30)
                    DetentTicks(detents: detents, range: range, width: geo.size.width, height: 30)
                        .frame(height: 30)
                    RoundedRectangle(cornerRadius: 4).fill(.white).frame(width: 8, height: 36)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .scaleEffect(drag.live != nil ? 1.15 : 1)
                        .offset(x: max(0, min(geo.size.width - 8, geo.size.width * p - 4)))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                    let np = max(0, min(1, g.location.x / geo.size.width))
                    drag.update(range.lowerBound + np * (range.upperBound - range.lowerBound), range: range, detents: detents,
                                value: $value, onChange: onChange)
                }.onEnded { _ in drag.end(value: value, onChange: onChange) })
                .animation(.spring(duration: 0.2), value: drag.live != nil)
            }
            .frame(height: 38)
            Text(display).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 52, alignment: .trailing)
        }
    }
}

// MARK: - Pastilles

struct Chip: View {
    var title: String
    var active: Bool
    var action: () -> Void
    var body: some View {
        Button { Haptics.selection(); action() } label: {
            Text(title)
                .font(.subheadline.weight(active ? .semibold : .medium))
                .padding(.horizontal, 14).frame(height: 36)
                .foregroundStyle(active ? .black : .white.opacity(0.75))
                .background(Capsule().fill(active ? .white : .white.opacity(0.1)))
                .animation(.snappy(duration: 0.2), value: active)
        }
        .buttonStyle(PressStyle())
    }
}

/// Bouton d'action. `active` le met en surbrillance quand il représente l'état courant.
struct PillButton: View {
    var title: String
    var systemImage: String? = nil
    var active = false
    var action: () -> Void
    var body: some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).lineLimit(1).minimumScaleFactor(0.8)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity).frame(height: 46)
            .foregroundStyle(active ? .black : .white)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(active ? .white : .white.opacity(0.1)))
            .animation(.snappy(duration: 0.2), value: active)
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct SectionHeader: View {
    var title: String
    var trailing: AnyView? = nil
    var body: some View {
        HStack {
            Text(title.uppercased()).font(.footnote.weight(.semibold)).tracking(0.8).foregroundStyle(.secondary)
            Spacer()
            trailing
        }
    }
}

// MARK: - Tuile de scène

struct SceneTile: View {
    var scene: LightScene
    var height: CGFloat = 108
    var compact = false
    /// Scène actuellement appliquée : contour lumineux + coche
    var selected = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 22, style: .continuous) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: scene.previewColors.count > 1 ? scene.previewColors : scene.previewColors + scene.previewColors,
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.35), .clear], center: UnitPoint(x: 0.25, y: 0.15), startRadius: 0, endRadius: 120)
            LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .bottom, endPoint: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(scene.name).font(compact ? .subheadline.weight(.bold) : .headline).lineLimit(1)
                Text(scene.subtitle).font(compact ? .caption2 : .caption).opacity(0.8).lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(compact ? 10 : 14)
        }
        .frame(height: height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white, lineWidth: selected ? 3 : 0))
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(.black)
                    .frame(width: 24, height: 24).background(Circle().fill(.white))
                    .shadow(color: .black.opacity(0.3), radius: 3)
                    .padding(compact ? 6 : 8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .shadow(color: selected ? (scene.previewColors.first ?? .white).opacity(0.7) : .black.opacity(0.35), radius: selected ? 16 : 14, y: selected ? 4 : 8)
        .animation(.spring(duration: 0.3), value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension View {
    /// Croix de suppression affichée en mode édition (hors du bouton de la tuile pour rester cliquable)
    func deleteBadge(_ shown: Bool, compact: Bool = false, action: @escaping () -> Void) -> some View {
        overlay(alignment: .topTrailing) {
            if shown {
                Button { Haptics.tap(); action() } label: {
                    Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                        .frame(width: 28, height: 28).background(Circle().fill(.black.opacity(0.65)))
                }
                .padding(compact ? 6 : 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// MARK: - En-tête commun

struct PageHeader: View {
    @EnvironmentObject var app: AppState
    var title: String

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.largeTitle.weight(.bold))
                HStack(spacing: 7) {
                    Circle().fill(statusColor).frame(width: 8, height: 8).shadow(color: statusColor, radius: 5)
                    Text(app.ble.isConnected ? (app.ble.deviceName ?? "Connecté") : app.ble.status.label)
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { Haptics.impact(); app.setPower(!app.s.on) } label: {
                Image(systemName: "power").font(.title2.weight(.semibold)).foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(app.s.on ? app.glow : .white.opacity(0.08)))
                    .shadow(color: app.s.on ? app.glow.opacity(0.7) : .clear, radius: 16)
            }
            .buttonStyle(PressStyle())
            .disabled(!app.ble.isConnected)
            .opacity(app.ble.isConnected ? 1 : 0.4)
        }
        .padding(.top, 8)
    }

    var statusColor: Color {
        switch app.ble.status {
        case .connected: return .green
        case .scanning, .connecting: return .orange
        default: return .gray
        }
    }
}

/// Carte affichée tant que le contrôleur n'est pas connecté.
struct ConnectCard: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        if !app.ble.isConnected {
            VStack(spacing: 12) {
                Text(title).font(.headline)
                Text(hint).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if app.ble.found.count > 1 || (app.ble.picking && !app.ble.found.isEmpty) {
                    ForEach(app.ble.found) { f in
                        PillButton(title: "\(f.name)  ·  \(f.rssi) dBm", systemImage: "dot.radiowaves.left.and.right") { app.ble.connect(f.id) }
                    }
                    if app.ble.status != .scanning {
                        Button("Relancer la recherche") { Haptics.tap(); app.ble.startScan() }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    }
                } else {
                    Button { Haptics.tap(); app.ble.startScan() } label: {
                        HStack {
                            if app.ble.status == .scanning || app.ble.status == .connecting { ProgressView().tint(.black) }
                            Text(app.ble.status == .scanning ? "Recherche…" : "Rechercher le contrôleur")
                        }
                        .font(.headline).foregroundStyle(.black)
                        .padding(.horizontal, 26).frame(height: 52)
                        .background(Capsule().fill(.white))
                    }
                    .buttonStyle(PressStyle())
                    .disabled(app.ble.status == .scanning || app.ble.status == .bluetoothOff)
                }
            }
            .padding(22).frame(maxWidth: .infinity).glassCard()
        }
    }
    var title: String {
        switch app.ble.status {
        case .bluetoothOff: return "Bluetooth désactivé"
        case .unauthorized: return "Accès Bluetooth refusé"
        case .connecting: return "Connexion en cours…"
        default: return "Contrôleur non connecté"
        }
    }
    var hint: String {
        switch app.ble.status {
        case .bluetoothOff: return "Active le Bluetooth dans le Centre de contrôle."
        case .unauthorized: return "Autorise le Bluetooth dans Réglages → AURA."
        case .connecting: return "Le contrôleur doit être allumé et à portée."
        default:
            if app.ble.picking { return app.ble.found.isEmpty ? "Recherche des contrôleurs à portée…" : "Choisis le contrôleur :" }
            return app.ble.found.count > 1 ? "Plusieurs contrôleurs trouvés, choisis le tien :" : "Allume le contrôleur, puis lance la recherche."
        }
    }
}

/// Aperçu animé d'un effet (dégradé qui défile ou clignote)
struct EffectPreview: View {
    var palette: [String]
    var animate: Bool
    var reversed: Bool
    var blink: Bool
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let colors = (palette + [palette.first ?? "#FFFFFF"]).map(Color.init(hex:))
            let strip = LinearGradient(colors: colors + colors.dropFirst(), startPoint: .leading, endPoint: .trailing)
            Rectangle().fill(strip)
                .frame(width: geo.size.width * 2)
                .offset(x: -geo.size.width * (reversed ? 1 - phase : phase))
                .brightness(blink && animate && phase.truncatingRemainder(dividingBy: 0.5) > 0.25 ? -0.8 : 0)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { start() }
        .onChange(of: animate) { _, _ in start() }
    }

    private func start() {
        phase = 0
        guard animate else { return }
        withAnimation(.linear(duration: blink ? 0.7 : 2.4).repeatForever(autoreverses: false)) { phase = 1 }
    }
}
