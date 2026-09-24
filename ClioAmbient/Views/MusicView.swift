import SwiftUI

struct MusicView: View {
    @EnvironmentObject var app: AppState
    @State private var sens: Double = 90
    @State private var pulse = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PageHeader(title: "Musique")
                ConnectCard()

                VStack(spacing: 16) {
                    SectionHeader(title: "Micro du boîtier")
                    equalizer.frame(height: 56)

                    HStack(spacing: 24) {
                        roundButton("chevron.left") { app.setMic(app.s.micMode - 1) }
                        VStack(spacing: 0) {
                            Text("\(app.s.micMode)").font(.system(size: 48, weight: .bold, design: .rounded)).contentTransition(.numericText())
                            Text("MODE").font(.caption.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
                        }
                        .frame(minWidth: 100)
                        roundButton("chevron.right") { app.setMic(app.s.micMode + 1) }
                    }
                    .animation(.snappy, value: app.s.micMode)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(1...24, id: \.self) { n in
                            Button { app.setMic(n) } label: {
                                Text("\(n)").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).frame(height: 38)
                                    .foregroundStyle(app.s.micMode == n ? .black : .white.opacity(0.75))
                                    .background(Capsule().fill(app.s.micMode == n ? .white : .white.opacity(0.1)))
                            }
                            .buttonStyle(PressStyle())
                        }
                    }

                    GlassSlider(title: "Sensibilité", systemImage: "mic.fill", value: $sens, tint: Color(hex: "#B34BFF"), height: 46) { app.setSensitivity(Int($0)) }

                    Text("Le micro est dans le module principal. Une fois caché derrière le CarPlay, monte la sensibilité vers 100 %.")
                        .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }
                .card()

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Styles simples · canal RGB")
                    HStack(spacing: 8) {
                        PillButton(title: "Saut") { app.voiceRGB(0) }
                        PillButton(title: "Souffle") { app.voiceRGB(1) }
                        PillButton(title: "Flash") { app.voiceRGB(2) }
                        PillButton(title: "Fondu") { app.voiceRGB(3) }
                    }
                }
                .card()
            }
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .onAppear { sens = Double(app.s.sensitivity); pulse = true }
    }

    private var equalizer: some View {
        let active = app.s.mode == .music && app.s.on
        return TimelineView(.animation(minimumInterval: 1 / 20, paused: !active)) { t in
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<9, id: \.self) { i in
                    let v = active ? (sin(t.date.timeIntervalSinceReferenceDate * (3 + Double(i) * 0.7) + Double(i)) + 1) / 2 : 0.15
                    Capsule().fill(LinearGradient(colors: [Color(hex: "#B34BFF"), .white], startPoint: .bottom, endPoint: .top))
                        .frame(width: 8, height: max(8, 56 * v))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func roundButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title3.weight(.bold)).foregroundStyle(.white)
                .frame(width: 56, height: 56).background(Circle().fill(.white.opacity(0.1)))
        }
        .buttonStyle(PressStyle())
        .sensoryFeedback(.selection, trigger: app.s.micMode)
    }
}
