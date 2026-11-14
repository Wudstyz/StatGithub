import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(Store.self) private var store
    @State private var selection: String? = "overview"
    @State private var period: Period = .d30
    @State private var search = ""
    @State private var showAccount = false

    var body: some View {
        Group {
            if store.connected || store.isDemo {
                main
            } else {
                ConnectView(isSheet: false)
            }
        }
    }

    private var sidebarRows: [RepoRow] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return store.rows(period)
            .filter { q.isEmpty || $0.name.lowercased().contains(q) }
            .sorted { $0.views > $1.views }
    }

    private var main: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Vue d'ensemble", systemImage: "chart.bar.xaxis")
                    .tag("overview")
                Section("Dépôts") {
                    ForEach(sidebarRows) { r in
                        HStack {
                            Image(systemName: r.isPrivate ? "lock.fill" : "book.closed")
                                .foregroundStyle(.secondary)
                            Text(r.name).lineLimit(1)
                            Spacer()
                            Text(r.views.fr)
                                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                        .tag(r.id)
                    }
                }
            }
            .searchable(text: $search, placement: .sidebar, prompt: "Chercher un dépôt")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
            .safeAreaInset(edge: .bottom) {
                if let d = store.data.lastRefresh {
                    Text("Actualisé \(d.formatted(.relative(presentation: .named)))")
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(8)
                }
            }
        } detail: {
            Group {
                if let sel = selection, sel != "overview", let repo = store.data.repos[sel] {
                    RepoView(repo: repo, period: period)
                } else {
                    OverviewView(period: period) { selection = $0 }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { banners }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Période", selection: $period) {
                    ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
            ToolbarItem {
                if store.isLoading {
                    ProgressView(value: store.progress > 0 ? store.progress : nil)
                        .progressViewStyle(.circular).controlSize(.small)
                } else {
                    Button { Task { await store.refresh() } } label: {
                        Label("Actualiser", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isDemo)
                    .help("Actualiser les statistiques (⌘R)")
                }
            }
            ToolbarItem {
                Menu {
                    Button("Exporter l'historique en CSV…") { exportCSV() }
                    Divider()
                    Button("Compte GitHub…") { showAccount = true }
                } label: {
                    Label("Plus", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAccount) { ConnectView(isSheet: true) }
    }

    @ViewBuilder
    private var banners: some View {
        VStack(spacing: 0) {
            if store.isDemo {
                banner("Mode démonstration : ces données sont fictives.", color: .blue, action: ("Quitter la démo", { store.exitDemo() }))
            }
            if let e = store.errorMessage {
                banner(e, color: .red, action: nil)
            }
            if let n = store.notice {
                banner(n, color: .orange, action: nil)
            }
        }
    }

    private func banner(_ text: String, color: Color, action: (String, () -> Void)?) -> some View {
        HStack {
            Image(systemName: "info.circle.fill")
            Text(text)
            Spacer()
            if let action {
                Button(action.0, action: action.1).buttonStyle(.link)
            }
        }
        .font(.callout)
        .foregroundStyle(color)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(color.opacity(0.10))
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "statgithub-historique.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        if panel.runModal() == .OK, let url = panel.url {
            try? store.csv().data(using: .utf8)?.write(to: url, options: .atomic)
        }
    }
}

// MARK: - Connexion / compte

struct ConnectView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let isSheet: Bool
    @State private var token = ""
    @State private var confirmErase = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 56)).foregroundStyle(.blue)
            Text("StatGithub").font(.largeTitle.bold())

            if store.connected && isSheet {
                Text("Connecté en tant que \(store.data.login ?? "…")")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Se déconnecter") { store.disconnect(); dismiss() }
                    Button("Effacer l'historique local", role: .destructive) { confirmErase = true }
                }
                Button("Fermer") { dismiss() }.keyboardShortcut(.defaultAction)
                    .confirmationDialog("Effacer tout l'historique enregistré sur ce Mac ?",
                                        isPresented: $confirmErase) {
                        Button("Effacer", role: .destructive) { store.eraseHistory() }
                    } message: {
                        Text("GitHub ne redonne que 14 jours : le reste serait perdu.")
                    }
            } else {
                Text("Les statistiques de visiteurs de tous vos dépôts GitHub, au même endroit, avec un historique qui dépasse les 14 jours de GitHub.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 460)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Jeton d'accès GitHub").font(.headline)
                    SecureField("ghp_…", text: $token)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await store.connect(token: token) } }
                    Text("Il faut un jeton classique avec le droit « repo » : GitHub ne donne les statistiques de visites qu'avec ce droit. Le jeton reste dans le Trousseau d'accès de votre Mac et n'est envoyé qu'à GitHub.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let url = URL(string: "https://github.com/settings/tokens/new?scopes=repo&description=StatGithub") {
                        Link("Créer le jeton sur GitHub (ouvre le navigateur)", destination: url).font(.caption)
                    }
                }
                .frame(maxWidth: 460)

                if let e = store.errorMessage {
                    Text(e).font(.callout).foregroundStyle(.red)
                }

                HStack {
                    Button {
                        Task { await store.connect(token: token) }
                    } label: {
                        if store.isLoading { ProgressView().controlSize(.small) } else { Text("Se connecter") }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty || store.isLoading)
                    .keyboardShortcut(.defaultAction)

                    Button("Essayer en mode démo") {
                        store.enterDemo()
                        if isSheet { dismiss() }
                    }
                }
                if isSheet { Button("Annuler") { dismiss() } }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: store.connected) { _, c in
            if c && isSheet && !store.isLoading { dismiss() }
        }
    }
}
