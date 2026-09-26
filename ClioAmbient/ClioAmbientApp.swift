import SwiftUI

@main
struct ClioAmbientApp: App {
    @StateObject private var app = AppState()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.dark)
        }
        // L'appli peut être fermée juste après un choix : la dernière ambiance doit être écrite tout de suite
        .onChange(of: phase) { _, p in if p != .active { app.saveNow() } }
    }
}

struct RootView: View {
    @EnvironmentObject var app: AppState
    @State private var tab = 0

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $tab) {
                ColorView().background { AmbientBackground(color: app.glow, strength: app.glowStrength) }
                    .tabItem { Label("Couleur", systemImage: "circle.circle.fill") }.tag(0)
                EffectsView().background { AmbientBackground(color: app.glow, strength: app.glowStrength) }
                    .tabItem { Label("Effets", systemImage: "sparkles") }.tag(1)
                MusicView().background { AmbientBackground(color: app.glow, strength: app.glowStrength) }
                    .tabItem { Label("Musique", systemImage: "music.note") }.tag(2)
                ScenesView().background { AmbientBackground(color: app.glow, strength: app.glowStrength) }
                    .tabItem { Label("Scènes", systemImage: "square.grid.2x2.fill") }.tag(3)
                AdvancedView().background { AmbientBackground(color: app.glow, strength: app.glowStrength) }
                    .tabItem { Label("Avancé", systemImage: "slider.horizontal.3") }.tag(4)
            }
            .tint(.white)
            .onChange(of: tab) { _, _ in Haptics.selection() }

            if let t = app.toast {
                Text(t)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .glassCard(cornerRadius: 20)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.spring(duration: 0.4), value: app.toast)
        .onAppear {
            // Fond transparent pour laisser voir l'ambiance derrière les onglets
            UITabBar.appearance().backgroundColor = .clear
        }
    }
}
