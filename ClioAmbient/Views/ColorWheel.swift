import SwiftUI
import UIKit

/// Roue chromatique de précision, inspirée des logiciels d'étalonnage :
/// - disque TSV calculé pixel par pixel avec la formule envoyée aux LED (ce qu'on voit = ce qui s'allume)
/// - angle = teinte (rouge en haut), distance au centre = saturation
/// - aimants avec cran haptique : bord (saturation 100 %), centre (blanc), teintes primaires et secondaires
/// - loupe au-dessus du doigt pendant le glisser, avec les valeurs exactes
/// - le doigt peut sortir du disque : il règle alors la teinte seule, à saturation maximale (plus de précision)
struct ColorWheel: View {
    @EnvironmentObject var app: AppState
    var maxSize: CGFloat = 310
    /// Appelé au début d'un glisser (pour mémoriser la couleur « avant »)
    var onBegin: () -> Void = {}

    @State private var dragging = false
    @State private var snappedHue: Double?
    @State private var atRim = false
    @State private var atCenter = false

    static let marks: [(hue: Double, label: String)] = [(0, "R"), (60, "J"), (120, "V"), (180, "C"), (240, "B"), (300, "M")]
    /// Largeur de l'aimant autour d'une teinte repère (en degrés)
    private let hueSnap = 2.5

    var body: some View {
        GeometryReader { geo in
            let box = geo.size.width
            let R = box / 2 - 34          // marge pour les repères et la pastille
            let c = CGPoint(x: box / 2, y: box / 2)
            let knob = point(hue: app.s.hue, sat: app.s.sat, c: c, R: R)

            ZStack(alignment: .topLeading) {
                Image(uiImage: WheelImage.disc)
                    .resizable().interpolation(.high)
                    .frame(width: R * 2, height: R * 2)
                    .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
                    .position(c)

                ticks(c: c, R: R)

                // Réticule central discret (repère du blanc)
                Image(systemName: "plus").font(.system(size: 10, weight: .semibold)).foregroundStyle(.black.opacity(0.25))
                    .position(c)

                Circle().fill(Color(hex: app.s.hex))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .overlay(Circle().strokeBorder(.black.opacity(0.25), lineWidth: 0.5).padding(-0.5))
                    .frame(width: 30, height: 30)
                    .scaleEffect(dragging ? 0.75 : 1)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .position(knob)

                if dragging {
                    loupe.position(loupePosition(knob: knob, box: box))
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .frame(width: box, height: box)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                if !dragging { onBegin(); withAnimation(.spring(duration: 0.2)) { dragging = true } }
                track(g.location, c: c, R: R)
            }.onEnded { _ in
                withAnimation(.spring(duration: 0.25)) { dragging = false }
                snappedHue = nil; atRim = false; atCenter = false
            })
            .accessibilityElement()
            .accessibilityLabel("Roue chromatique")
            .accessibilityValue("\(app.colorName), teinte \(Int(app.s.hue)) degrés, saturation \(Int(app.s.sat)) %")
            .accessibilityAdjustableAction { dir in
                app.setHueSat(app.s.hue + (dir == .increment ? 5 : -5), app.s.sat)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: maxSize)
        .frame(maxWidth: .infinity)
    }

    // MARK: Géométrie

    private func point(hue: Double, sat: Double, c: CGPoint, R: CGFloat) -> CGPoint {
        let a = (hue - 90) * .pi / 180
        let d = R * sat / 100
        return CGPoint(x: c.x + d * cos(a), y: c.y + d * sin(a))
    }

    private func track(_ p: CGPoint, c: CGPoint, R: CGFloat) {
        let dx = p.x - c.x, dy = p.y - c.y
        var hue = atan2(dy, dx) * 180 / .pi + 90
        if hue < 0 { hue += 360 }
        let r = hypot(dx, dy) / R

        // Aimants de saturation : bord (et au-delà) = 100 %, tout près du centre = blanc
        let rim = r >= 0.94
        let center = r <= 0.05
        let sat = rim ? 100 : center ? 0 : r * 100
        if rim && !atRim { Haptics.selection() }
        if center && !atCenter { Haptics.selection() }
        atRim = rim; atCenter = center

        // Aimants de teinte : R, J, V, C, B, M (inutiles près du centre, où la teinte ne se voit presque pas)
        var snap: Double?
        if sat > 15 {
            snap = Self.marks.map(\.hue).first { m in
                let d = abs(hue - m).truncatingRemainder(dividingBy: 360)
                return min(d, 360 - d) <= hueSnap
            }
        }
        if let snap { hue = snap }
        if snap != snappedHue, snap != nil { Haptics.selection() }
        snappedHue = snap

        app.setHueSat(hue, sat)
    }

    // MARK: Repères

    private func ticks(c: CGPoint, R: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Graduations tous les 30° ; les 6 teintes repères sont plus longues et étiquetées
            ForEach(0..<12, id: \.self) { i in
                let h = Double(i) * 30
                let major = i % 2 == 0
                let a = (h - 90) * .pi / 180
                let rr = R + (major ? 7 : 5)
                Capsule().fill(.white.opacity(major ? 0.6 : 0.3))
                    .frame(width: major ? 2 : 1.5, height: major ? 8 : 5)
                    .rotationEffect(.degrees(h))
                    .position(x: c.x + rr * cos(a), y: c.y + rr * sin(a))
            }
            ForEach(Self.marks, id: \.hue) { m in
                let a = (m.hue - 90) * .pi / 180
                let active = snappedHue == m.hue || (!dragging && app.s.hue == m.hue && app.s.sat > 15)
                Text(m.label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(active ? .white : .white.opacity(0.45))
                    .position(x: c.x + (R + 26) * cos(a), y: c.y + (R + 26) * sin(a))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Loupe

    private var loupe: some View {
        VStack(spacing: 5) {
            Circle().fill(Color(hex: app.s.hex))
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .frame(width: 58, height: 58)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 3)
            Text("\(Int(app.s.hue))° · \(Int(app.s.sat)) %")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(.black.opacity(0.65)))
        }
    }

    /// Au-dessus de la pastille (visible malgré le doigt), ou en dessous si on est en haut de la roue
    private func loupePosition(knob: CGPoint, box: CGFloat) -> CGPoint {
        let y = knob.y - 78 >= 38 ? knob.y - 78 : knob.y + 78
        return CGPoint(x: min(max(knob.x, 40), box - 40), y: y)
    }
}

/// Image du disque, calculée une seule fois.
enum WheelImage {
    static let disc: UIImage = {
        let n = 480
        let c = Double(n) / 2
        var px = [UInt8](repeating: 0, count: n * n * 4)
        for y in 0..<n {
            for x in 0..<n {
                let dx = Double(x) + 0.5 - c, dy = Double(y) + 0.5 - c
                let dist = (dx * dx + dy * dy).squareRoot()
                let alpha = max(0, min(1, c - dist))   // bord lissé sur 1 px
                guard alpha > 0 else { continue }
                var h = atan2(dy, dx) * 180 / .pi + 90
                if h < 0 { h += 360 }
                if h >= 360 { h -= 360 }
                let rgb = ColorMath.hsvToRGB(h: h, s: min(1, dist / c) * 100, v: 100)
                let i = (y * n + x) * 4
                px[i] = UInt8(Double(rgb.r) * alpha)
                px[i + 1] = UInt8(Double(rgb.g) * alpha)
                px[i + 2] = UInt8(Double(rgb.b) * alpha)
                px[i + 3] = UInt8(alpha * 255)
            }
        }
        guard let provider = CGDataProvider(data: Data(px) as CFData),
              let cg = CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4,
                               space: CGColorSpace(name: CGColorSpace.sRGB)!,
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return UIImage() }
        return UIImage(cgImage: cg, scale: 2, orientation: .up)
    }()
}

// MARK: - Réglage fin

/// Réglage au degré / au pour-cent près : − valeur +, maintien = répétition rapide.
struct NudgeStepper: View {
    var title: String
    var value: String
    var onBegin: () -> Void = {}
    var onStep: (Double) -> Void

    var body: some View {
        HStack(spacing: 0) {
            RepeatButton(systemImage: "minus", onBegin: onBegin) { onStep(-1) }
            VStack(spacing: 0) {
                Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            RepeatButton(systemImage: "plus", onBegin: onBegin) { onStep(1) }
        }
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(.white.opacity(0.08)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityAdjustableAction { onStep($0 == .increment ? 1 : -1) }
    }
}

private struct RepeatButton: View {
    var systemImage: String
    var onBegin: () -> Void
    var action: () -> Void
    @State private var pressed = false
    @State private var timer: Timer?

    var body: some View {
        Image(systemName: systemImage)
            .font(.body.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.8 : 1)
            .opacity(pressed ? 0.6 : 1)
            .animation(.spring(duration: 0.2), value: pressed)
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in
                guard !pressed else { return }
                pressed = true
                Haptics.selection()
                onBegin()
                action()
                // Maintien : après un court délai, répétition rapide
                timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                    timer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in action() }
                }
            }.onEnded { _ in
                pressed = false
                timer?.invalidate(); timer = nil
            })
    }
}

/// Pastille avant / après : la moitié gauche est la couleur précédente, la toucher y revient.
struct CompareSwatch: View {
    var previous: String?
    var current: String
    var onRevert: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        HStack(spacing: 0) {
            if let previous, previous != current {
                Button { Haptics.selection(); onRevert() } label: {
                    Rectangle().fill(Color(hex: previous))
                        .overlay(Image(systemName: "arrow.uturn.backward").font(.caption.weight(.bold))
                            .foregroundStyle(.white).shadow(color: .black.opacity(0.6), radius: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Revenir à la couleur précédente")
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            Rectangle().fill(Color(hex: current))
        }
        .frame(width: 72, height: 44)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.3), lineWidth: 1))
        .animation(.snappy(duration: 0.25), value: previous != nil && previous != current)
    }
}
