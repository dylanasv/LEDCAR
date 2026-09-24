import SwiftUI

struct ScenesView: View {
    @EnvironmentObject var app: AppState
    @State private var name = ""
    @State private var editing = false
    @State private var category = "Toutes"
    @FocusState private var nameFocused: Bool

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PageHeader(title: "Scènes")
                ConnectCard()

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Enregistrer l'ambiance actuelle")
                    HStack(spacing: 8) {
                        TextField("Nom (ex. Nuit sur l'A13)", text: $name)
                            .focused($nameFocused)
                            .padding(.horizontal, 14).frame(height: 46)
                            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(.white.opacity(0.08)))
                            .submitLabel(.done)
                            .onSubmit(save)
                        Button("Enregistrer", action: save)
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.black)
                            .padding(.horizontal, 16).frame(height: 46)
                            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(.white))
                            .buttonStyle(PressStyle())
                    }
                }
                .card()

                SectionHeader(title: "Mes scènes", trailing: app.s.scenes.isEmpty ? nil : AnyView(
                    Chip(title: editing ? "Terminé" : "Modifier", active: editing) { withAnimation { editing.toggle() } }))
                    .padding(.horizontal, 4).padding(.top, 8)

                if app.s.scenes.isEmpty {
                    Text("Aucune scène perso pour l'instant — enregistre ton ambiance ci-dessus.")
                        .font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 4)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(app.s.scenes) { sc in
                            Button { if !editing { app.apply(sc) } } label: { SceneTile(scene: sc) }
                                .buttonStyle(PressStyle())
                                .overlay(alignment: .topTrailing) {
                                    if editing {
                                        Button { withAnimation { app.s.scenes.removeAll { $0.id == sc.id } } } label: {
                                            Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                                                .frame(width: 28, height: 28).background(Circle().fill(.black.opacity(0.65)))
                                        }
                                        .padding(8)
                                    }
                                }
                                .rotationEffect(.degrees(editing ? 0.8 : 0))
                                .animation(editing ? .easeInOut(duration: 0.15).repeatForever(autoreverses: true) : .default, value: editing)
                        }
                    }
                }

                SectionHeader(title: "Suggestions").padding(.horizontal, 4).padding(.top, 12)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(SceneLibrary.categories, id: \.self) { c in
                            Chip(title: c, active: c == category) { withAnimation(.snappy) { category = c } }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -16)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(SceneLibrary.suggestions.filter { category == "Toutes" || $0.category == category }) { sc in
                        Button { app.apply(sc) } label: { SceneTile(scene: sc) }.buttonStyle(PressStyle())
                    }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    private func save() {
        app.saveScene(named: name)
        name = ""; nameFocused = false
    }
}
