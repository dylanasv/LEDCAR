import SwiftUI

struct ColorView: View {
    @EnvironmentObject var app: AppState
    @State private var bri: Double = 100
    @State private var editingFavs = false
    @State private var pickerSlot: Int?

    private let quick = ["#FF0000", "#FF3D00", "#FF8A00", "#FFD000", "#00FF40", "#00FFD0",
                         "#00B4FF", "#0030FF", "#6A00FF", "#C000FF", "#FF00A8", "#FFFFFF"]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PageHeader(title: "Couleur")
                ConnectCard()

                HueRing().padding(.vertical, 8).frame(maxWidth: .infinity).card()

                GlassSlider(title: "Luminosité", systemImage: "sun.max.fill", value: $bri, tint: app.glow) { app.setBrightness(Int($0)) }
                    .card()

                // Favoris : 3 emplacements personnalisables
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Favoris", trailing: AnyView(
                        Chip(title: editingFavs ? "Terminé" : "Modifier", active: editingFavs) { editingFavs.toggle() }))
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { i in favSlot(i) }
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Couleurs rapides")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 12) {
                        ForEach(quick, id: \.self) { hex in
                            Button { app.setHex(hex) } label: {
                                Circle().fill(Color(hex: hex))
                                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                                    .padding(4)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: app.s.mode == .color && app.s.hex == hex ? 2.5 : 0))
                                    .aspectRatio(1, contentMode: .fit)
                                    .shadow(color: Color(hex: hex).opacity(0.5), radius: 6)
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                    HStack(spacing: 8) {
                        PillButton(title: "Chaud") { app.setHex(ColorMath.rgbToHex(ColorMath.kelvinToRGB(2700))) }
                        PillButton(title: "Neutre") { app.setHex(ColorMath.rgbToHex(ColorMath.kelvinToRGB(4500))) }
                        PillButton(title: "Froid") { app.setHex(ColorMath.rgbToHex(ColorMath.kelvinToRGB(7500))) }
                    }
                }
                .card()
            }
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .onAppear { bri = Double(app.s.brightness) }
        .onChange(of: app.s.brightness) { _, v in bri = Double(v) }
        .sheet(item: Binding(get: { pickerSlot.map { SlotID(id: $0) } }, set: { pickerSlot = $0?.id })) { slot in
            ScenePicker(title: app.s.favorites[slot.id] == nil ? "Ajouter un favori" : "Remplacer le favori \(slot.id + 1)") { sc in
                app.s.favorites[slot.id] = sc
                app.flash("Favori \(slot.id + 1) : \(sc.name)")
                pickerSlot = nil
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func favSlot(_ i: Int) -> some View {
        if let sc = app.s.favorites[i] {
            Button { if editingFavs { pickerSlot = i } else { app.apply(sc) } } label: {
                SceneTile(scene: sc, height: 92, compact: true)
            }
            .buttonStyle(PressStyle())
            .overlay(alignment: .topTrailing) {
                if editingFavs {
                    Button { app.s.favorites[i] = nil } label: {
                        Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                            .frame(width: 26, height: 26).background(Circle().fill(.black.opacity(0.65)))
                    }
                    .padding(6)
                }
            }
        } else {
            Button { pickerSlot = i } label: {
                VStack(spacing: 4) {
                    Image(systemName: "plus").font(.title2)
                    Text("Ajouter").font(.caption.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).frame(height: 92)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])).foregroundStyle(.white.opacity(0.25)))
            }
            .buttonStyle(PressStyle())
        }
    }
}

struct SlotID: Identifiable { let id: Int }

/// Anneau de teinte avec pastille centrale qui montre la couleur.
struct HueRing: View {
    @EnvironmentObject var app: AppState
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, 300)
            let r = size / 2
            let thickness = r * 0.27
            let knobR = r - thickness / 2
            let a = (app.s.hue - 90) * .pi / 180
            ZStack {
                // Halo en dégradé plutôt qu'en ombres floues : ces ombres étaient recalculées à chaque pas du glisser
                Circle()
                    .fill(RadialGradient(stops: [.init(color: app.glow.opacity(0.8), location: 0.2),
                                                 .init(color: app.glow.opacity(0.35), location: 0.7),
                                                 .init(color: app.glow.opacity(0), location: 1)],
                                         center: .center, startRadius: 0, endRadius: size * 0.62))
                    .frame(width: size * 1.24, height: size * 1.24)
                    .allowsHitTesting(false)
                HueWheel(thickness: thickness)
                Circle().fill(app.glow)
                    .frame(width: size * 0.46, height: size * 0.46)
                    .overlay(Circle().fill(RadialGradient(colors: [.white.opacity(0.35), .clear], center: .topLeading, startRadius: 0, endRadius: size * 0.3)))
                VStack(spacing: 2) {
                    Text(app.s.mode == .color ? app.colorName : app.currentLabel).font(.headline).lineLimit(1).minimumScaleFactor(0.6)
                    Text(app.s.hex).font(.caption.monospaced()).opacity(0.85)
                }
                .foregroundStyle(.white).shadow(color: .black.opacity(0.45), radius: 6)
                .frame(width: size * 0.4)
                Circle().fill(Color.hue(app.s.hue))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .frame(width: 36, height: 36)
                    .scaleEffect(dragging ? 1.25 : 1)
                    .shadow(color: .black.opacity(0.5), radius: 5)
                    .offset(x: knobR * cos(a), y: knobR * sin(a))
                    .animation(.spring(duration: 0.2), value: dragging)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                dragging = true
                let dx = g.location.x - r, dy = g.location.y - r
                app.setHueSat(atan2(dy, dx) * 180 / .pi + 90, 100)
            }.onEnded { _ in dragging = false })
            .sensoryFeedback(.selection, trigger: Int(app.s.hue) / 15)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 300)
    }
}

/// Anneau de teintes : ne dépend d'aucun état, SwiftUI ne le redessine donc pas pendant le glisser.
private struct HueWheel: View, Equatable {
    var thickness: CGFloat
    var body: some View {
        Circle()
            .strokeBorder(AngularGradient(colors: Color.hueStops, center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)),
                          lineWidth: thickness)
            .drawingGroup()
    }
}

/// Feuille de sélection d'une ambiance (favoris)
struct ScenePicker: View {
    @EnvironmentObject var app: AppState
    var title: String
    var onPick: (LightScene) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Maintenant") {
                    row(app.snapshot(named: app.currentLabel))
                }
                if !app.s.scenes.isEmpty {
                    Section("Mes scènes") { ForEach(app.s.scenes) { row($0) } }
                }
                ForEach(SceneLibrary.categories.dropFirst(), id: \.self) { cat in
                    Section(cat) { ForEach(SceneLibrary.suggestions.filter { $0.category == cat }) { row($0) } }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ sc: LightScene) -> some View {
        Button { onPick(sc) } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: sc.previewColors.count > 1 ? sc.previewColors : sc.previewColors + sc.previewColors,
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sc.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                    Text(sc.subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
