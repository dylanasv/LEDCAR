import SwiftUI

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
                Circle().fill(color).frame(width: w * 1.1).offset(x: drift ? -w * 0.2 : -w * 0.35, y: drift ? -geo.size.height * 0.3 : -geo.size.height * 0.38)
                    .opacity(0.9)
                Circle().fill(color).frame(width: w * 0.9).offset(x: drift ? w * 0.4 : w * 0.3, y: drift ? geo.size.height * 0.28 : geo.size.height * 0.2)
                    .opacity(0.5)
                Circle().fill(Color(red: 0.23, green: 0.36, blue: 1)).frame(width: w * 0.7).offset(x: drift ? w * 0.1 : -w * 0.05, y: geo.size.height * 0.1)
                    .opacity(0.3)
            }
            .blur(radius: 90)
            .opacity(strength)
            .overlay(RadialGradient(colors: [.clear, .black.opacity(0.6)], center: .top, startRadius: w * 0.4, endRadius: geo.size.height))
            .animation(.easeInOut(duration: 0.6), value: color)
            .animation(.easeInOut(duration: 0.6), value: strength)
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) { drift = true } }
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
    var onChange: (Double) -> Void
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let p = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule().fill(LinearGradient(colors: [tint.opacity(0.45), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, geo.size.width * p))
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
                dragging = true
                let np = max(0, min(1, g.location.x / geo.size.width))
                let nv = (range.lowerBound + np * (range.upperBound - range.lowerBound)).rounded()
                if nv != value { value = nv; onChange(nv) }
            }.onEnded { _ in dragging = false })
            .scaleEffect(dragging ? 1.015 : 1)
            .animation(.spring(duration: 0.25), value: dragging)
        }
        .frame(height: height)
        .sensoryFeedback(.selection, trigger: Int(value) / 10)
    }
}

/// Petit slider de réglage fin (roue chromatique, RVB, Kelvin…)
struct TrackSlider: View {
    var label: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var track: LinearGradient
    var display: String
    var onChange: (Double) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(label).font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(width: 18)
            GeometryReader { geo in
                let p = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                ZStack(alignment: .leading) {
                    Capsule().fill(track)
                    RoundedRectangle(cornerRadius: 4).fill(.white).frame(width: 8, height: 30)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .offset(x: max(0, min(geo.size.width - 8, geo.size.width * p - 4)))
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                    let np = max(0, min(1, g.location.x / geo.size.width))
                    let nv = (range.lowerBound + np * (range.upperBound - range.lowerBound)).rounded()
                    if nv != value { value = nv; onChange(nv) }
                })
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
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(active ? .semibold : .medium))
                .padding(.horizontal, 14).frame(height: 36)
                .foregroundStyle(active ? .black : .white.opacity(0.75))
                .background(Capsule().fill(active ? .white : .white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

struct PillButton: View {
    var title: String
    var systemImage: String? = nil
    var prominent = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).lineLimit(1).minimumScaleFactor(0.8)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity).frame(height: 46)
            .foregroundStyle(prominent ? .black : .white)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(prominent ? .white : .white.opacity(0.1)))
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
    var showDelete = false
    var onDelete: (() -> Void)? = nil

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
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if showDelete, let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                        .frame(width: 28, height: 28).background(Circle().fill(.black.opacity(0.6)))
                }
                .padding(8)
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
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
            Button { app.setPower(!app.s.on) } label: {
                Image(systemName: "power").font(.title2.weight(.semibold)).foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(app.s.on ? app.glow : .white.opacity(0.08)))
                    .shadow(color: app.s.on ? app.glow.opacity(0.7) : .clear, radius: 16)
            }
            .buttonStyle(PressStyle())
            .sensoryFeedback(.impact(weight: .medium), trigger: app.s.on)
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
                if app.ble.found.count > 1 {
                    ForEach(app.ble.found) { f in
                        PillButton(title: "\(f.name)  ·  \(f.rssi) dBm", systemImage: "dot.radiowaves.left.and.right") { app.ble.connect(f.id) }
                    }
                } else {
                    Button { app.ble.startScan() } label: {
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
        case .unauthorized: return "Autorise le Bluetooth dans Réglages → Clio Ambient."
        case .connecting: return "Le contrôleur doit être allumé et à portée."
        default: return app.ble.found.count > 1 ? "Plusieurs contrôleurs trouvés, choisis le tien :" : "Allume le contrôleur, puis lance la recherche."
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
