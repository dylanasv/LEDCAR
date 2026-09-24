import SwiftUI

struct EffectsView: View {
    @EnvironmentObject var app: AppState
    @State private var query = ""
    @State private var category = "Tous"
    @State private var speed: Double = 50

    private var current: (EffectGroup, EffectDirection)? { app.s.effect.flatMap { EffectCatalog.byID[$0] } }

    private var items: [EffectGroup] {
        let words = query.lowercased().folding(options: .diacriticInsensitive, locale: .current).split(separator: " ").map(String.init)
        return EffectCatalog.groups.filter { g in
            (category == "Tous" || g.category == category) && words.allSatisfy { g.search.contains($0) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PageHeader(title: "Effets")
                ConnectCard()

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Rechercher un effet, une couleur…", text: $query)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    }
                }
                .padding(.horizontal, 14).frame(height: 48)
                .glassCard(cornerRadius: 16)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(EffectCatalog.categories, id: \.self) { c in
                                Chip(title: c, active: c == category) {
                                    withAnimation(.snappy) { category = c; proxy.scrollTo(c, anchor: .center) }
                                }
                                .id(c)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                    .padding(.horizontal, -16)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(items) { g in effectCard(g) }
                }
                if items.isEmpty {
                    Text("Aucun effet trouvé").foregroundStyle(.secondary).padding(.vertical, 30)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) { nowPlaying }
        .onAppear { speed = Double(app.s.speed) }
    }

    private func effectCard(_ g: EffectGroup) -> some View {
        let isCurrent = current?.0.id == g.id
        let dir = isCurrent ? current!.1 : g.directions[0]
        return Button {
            app.playEffect(isCurrent ? app.s.effect! : g.firstID)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                EffectPreview(palette: g.palette, animate: isCurrent, reversed: dir.reversed, blink: g.isFlash)
                    .frame(height: 40)
                Text(g.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .lineLimit(2).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                Text(g.category + (g.directions.count > 1 ? " · 2 sens" : "")).font(.caption).foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(isCurrent ? 0.16 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(isCurrent ? 0.7 : 0.08), lineWidth: isCurrent ? 1.5 : 1))
            .shadow(color: isCurrent ? app.glow.opacity(0.4) : .clear, radius: 14)
        }
        .buttonStyle(PressStyle())
        .sensoryFeedback(.selection, trigger: isCurrent)
    }

    private var nowPlaying: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("En cours").font(.caption).foregroundStyle(.secondary)
                    Text(app.s.mode == .effect ? EffectCatalog.title(for: app.s.effect) : "Aucun effet")
                        .font(.headline).lineLimit(1)
                }
                Spacer()
                Chip(title: "Auto", active: app.s.mode == .effect && app.s.effect == EffectCatalog.autoID) {
                    app.playEffect(EffectCatalog.autoID)
                }
            }
            if let cur = current, cur.0.directions.count > 1, app.s.mode == .effect {
                Picker("Sens", selection: Binding(get: { cur.1 }, set: { d in if let id = cur.0.ids[d] { app.playEffect(id) } })) {
                    ForEach(cur.0.directions, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            GlassSlider(title: "Vitesse", systemImage: "speedometer", value: $speed, tint: app.glow, height: 42) { app.setSpeed(Int($0)) }
        }
        .padding(14)
        .glassCard(cornerRadius: 24)
        .padding(.horizontal, 12).padding(.bottom, 6)
        .disabled(!app.ble.isConnected)
    }
}
