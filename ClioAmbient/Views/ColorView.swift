import SwiftUI

struct ColorView: View {
    @EnvironmentObject var app: AppState
    @State private var bri: Double = 100
    @State private var editingFavs = false
    @State private var pickerSlot: Int?
    /// Couleur avant la dernière retouche à la roue (comparaison avant / après)
    @State private var previous: (hue: Double, sat: Double, hex: String)?

    private let whites: [(String, Double)] = [("Chaud", 2700), ("Neutre", 4500), ("Froid", 7500)]
    private let quick = ["#FF0000", "#FF3D00", "#FF8A00", "#FFD000", "#00FF40", "#00FFD0",
                         "#00B4FF", "#0030FF", "#6A00FF", "#C000FF", "#FF00A8", "#FFFFFF"]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PageHeader(title: "Couleur")
                ConnectCard()

                wheelCard

                GlassSlider(title: "Luminosité", systemImage: "sun.max.fill", value: $bri, tint: app.glow, detents: Detents.percent) { app.setBrightness(Int($0)) }
                    .card()

                // Favoris : 3 emplacements personnalisables
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Favoris", trailing: AnyView(
                        Chip(title: editingFavs ? "Terminé" : "Modifier", active: editingFavs) { withAnimation(.snappy) { editingFavs.toggle() } }))
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { i in favSlot(i) }
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Couleurs rapides")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 12) {
                        ForEach(quick, id: \.self) { hex in
                            let on = isCurrent(hex)
                            Button { Haptics.selection(); app.setHex(hex) } label: {
                                Circle().fill(Color(hex: hex))
                                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                                    .padding(on ? 5 : 4)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: on ? 2.5 : 0))
                                    .aspectRatio(1, contentMode: .fit)
                                    .shadow(color: Color(hex: hex).opacity(on ? 0.9 : 0.5), radius: on ? 10 : 6)
                                    .animation(.spring(duration: 0.25), value: on)
                            }
                            .buttonStyle(PressStyle())
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(whites, id: \.0) { name, k in
                            let hex = ColorMath.rgbToHex(ColorMath.kelvinToRGB(k))
                            PillButton(title: name, active: isCurrent(hex)) { app.setHex(hex) }
                        }
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
                Haptics.success()
                app.s.favorites[slot.id] = sc
                app.flash("Favori \(slot.id + 1) : \(sc.name)")
                pickerSlot = nil
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var wheelCard: some View {
        VStack(spacing: 14) {
            ColorWheel(onBegin: markPrevious)
            HStack(spacing: 12) {
                CompareSwatch(previous: previous?.hex, current: app.s.hex, onRevert: revert)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.s.mode == .color ? app.colorName : app.currentLabel).font(.headline).lineLimit(1)
                    Text(app.s.hex).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                NudgeStepper(title: "Teinte", value: "\(Int(app.s.hue))°", onBegin: markPrevious) { app.setHueSat(app.s.hue + $0, app.s.sat) }
                NudgeStepper(title: "Saturation", value: "\(Int(app.s.sat)) %", onBegin: markPrevious) { app.setHueSat(app.s.hue, app.s.sat + $0) }
            }
        }
        .card()
    }

    private func markPrevious() { previous = (app.s.hue, app.s.sat, app.s.hex) }

    /// Revient à la couleur précédente ; la couleur quittée devient la nouvelle « précédente » (bascule A/B)
    private func revert() {
        guard let p = previous else { return }
        previous = (app.s.hue, app.s.sat, app.s.hex)
        app.setHueSat(p.hue, p.sat)
    }

    private func isCurrent(_ hex: String) -> Bool { app.s.on && app.s.mode == .color && app.s.hex == hex }

    @ViewBuilder
    private func favSlot(_ i: Int) -> some View {
        if let sc = app.s.favorites[i] {
            Button {
                Haptics.selection()
                if editingFavs { pickerSlot = i } else { app.apply(sc) }
            } label: {
                SceneTile(scene: sc, height: 92, compact: true, selected: !editingFavs && app.isActive(sc))
            }
            .buttonStyle(PressStyle())
            .deleteBadge(editingFavs, compact: true) { withAnimation(.snappy) { app.s.favorites[i] = nil } }
        } else {
            Button { Haptics.tap(); pickerSlot = i } label: {
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
                Spacer()
                if app.isActive(sc) {
                    Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(.white)
                }
            }
        }
    }
}
