import SwiftUI
import Charts

// MARK: - Vue d'ensemble

struct OverviewView: View {
    @Environment(Store.self) private var store
    let period: Period
    var onSelect: (String) -> Void

    @State private var sortOrder = [KeyPathComparator(\RepoRow.views, order: .reverse)]
    @State private var tableSelection: String?

    var body: some View {
        let all = store.repos
        let t = store.totals(all, period)
        let points = store.series(all, period)
        let rows = store.rows(period).sorted(using: sortOrder)
        let stars = all.reduce(0) { $0 + $1.stars }
        let forks = all.reduce(0) { $0 + $1.forks }
        let downloads = all.reduce(0) { $0 + $1.downloads }
        let commits = all.reduce(0) { $0 + $1.commits }
        let contributors = all.reduce(0) { $0 + $1.contributors }
        let pulls = all.reduce(0) { $0 + $1.openPulls }
        let issues = all.reduce(0) { $0 + $1.openIssues }
        let weeks = store.weekly(all, period)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tous mes dépôts").font(.largeTitle.bold())
                    Text("\(all.count) dépôts · compte \(store.data.login ?? "—") · chiffres \(period.label)")
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    KPI(title: "Vues", value: t.views, icon: "eye.fill", tint: .blue, sub: period.label)
                    KPI(title: "Visiteurs uniques", value: t.uniqueViews, icon: "person.2.fill", tint: .indigo, sub: "somme jour par jour")
                    KPI(title: "Clones", value: t.clones, icon: "arrow.down.doc.fill", tint: .green, sub: "\(t.uniqueClones.fr) cloneurs uniques")
                    KPI(title: "Étoiles", value: stars, icon: "star.fill", tint: .orange, sub: "total actuel")
                    KPI(title: "Forks", value: forks, icon: "tuningfork", tint: .purple, sub: "total actuel")
                    KPI(title: "Téléchargements", value: downloads, icon: "square.and.arrow.down.fill", tint: .teal, sub: "releases, depuis toujours")
                    KPI(title: "Commits", value: commits, icon: "point.topleft.down.to.point.bottomright.curvepath.fill", tint: .orange, sub: "total, tous dépôts")
                    KPI(title: "Contributeurs", value: contributors, icon: "person.3.fill", tint: .pink, sub: "somme par dépôt")
                    KPI(title: "Pull requests", value: pulls, icon: "arrow.triangle.pull", tint: .mint, sub: "ouvertes")
                    KPI(title: "Issues", value: issues, icon: "exclamationmark.circle.fill", tint: .red, sub: "ouvertes")
                }

                HStack(alignment: .top, spacing: 12) {
                    Card(title: "Visites par jour", subtitle: "Tous dépôts confondus") {
                        TrafficChart(points: points, total: \.views, unique: \.uniqueViews,
                                     totalLabel: "Vues", uniqueLabel: "Visiteurs uniques", color: .blue)
                    }
                    Card(title: "Clones par jour", subtitle: "Tous dépôts confondus") {
                        TrafficChart(points: points, total: \.clones, unique: \.uniqueClones,
                                     totalLabel: "Clones", uniqueLabel: "Cloneurs uniques", color: .green)
                    }
                }

                Card(title: "Commits par semaine", subtitle: "Tous dépôts confondus (52 dernières semaines au maximum)") {
                    CommitsChart(weeks: weeks)
                }

                Card(title: "Dépôts", subtitle: "Cliquez sur un dépôt pour voir le détail · cliquez sur une colonne pour trier") {
                    Table(rows, selection: $tableSelection, sortOrder: $sortOrder) {
                        TableColumn("Dépôt", value: \.name) { r in
                            HStack(spacing: 6) {
                                Text(r.name)
                                if r.isPrivate {
                                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        TableColumn("Vues", value: \.views) { Text($0.views.fr).monospacedDigit() }
                        TableColumn("Uniques", value: \.uniqueViews) { Text($0.uniqueViews.fr).monospacedDigit() }
                        TableColumn("Clones", value: \.clones) { Text($0.clones.fr).monospacedDigit() }
                        TableColumn("Commits", value: \.commits) { Text($0.commits.fr).monospacedDigit() }
                        TableColumn("Étoiles", value: \.stars) { Text($0.stars.fr).monospacedDigit() }
                        TableColumn("Forks", value: \.forks) { Text($0.forks.fr).monospacedDigit() }
                        TableColumn("Téléch.", value: \.downloads) { Text($0.downloads.fr).monospacedDigit() }
                    }
                    .frame(height: CGFloat(min(max(rows.count, 3), 14)) * 28 + 40)
                    .onChange(of: tableSelection) { _, new in
                        if let new { onSelect(new) }
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    Card(title: "D'où viennent les visiteurs", subtitle: "Sources, 14 derniers jours") {
                        RankList(rows: store.topReferrers(all).prefix(8).map {
                            RankRow(id: $0.referrer, label: $0.referrer, value: $0.count, secondary: $0.uniques)
                        }, tint: .blue, valueLabel: "vues")
                    }
                    Card(title: "Pages les plus vues", subtitle: "Tous dépôts, 14 derniers jours") {
                        RankList(rows: store.topPaths(all).prefix(8).map {
                            RankRow(id: $0.path, label: $0.path, detail: nil, value: $0.count, secondary: $0.uniques)
                        }, tint: .indigo, valueLabel: "vues")
                    }
                }

                Text("GitHub ne conserve le trafic que 14 jours. StatGithub garde l'historique sur ce Mac à chaque actualisation : ouvrez l'app au moins une fois tous les 14 jours pour ne rien perdre.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Détail d'un dépôt

struct RepoView: View {
    @Environment(Store.self) private var store
    let repo: RepoRecord
    let period: Period

    var body: some View {
        let t = store.totals([repo], period)
        let points = store.series([repo], period)
        let weeks = store.weekly([repo], period)
        let starPoints = repo.starHistory.compactMap { k, v -> (Date, Int)? in
            Day.date(k).map { ($0, v) }
        }.sorted { $0.0 < $1.0 }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(repo.name).font(.largeTitle.bold())
                            if repo.isPrivate {
                                Label("Privé", systemImage: "lock.fill")
                                    .font(.caption).padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.gray.opacity(0.15), in: Capsule())
                            }
                        }
                        if let d = repo.description, !d.isEmpty {
                            Text(d).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 10) {
                            if let l = repo.language {
                                Text(l)
                            }
                            if let d = repo.pushedAt.flatMap({ ISO8601DateFormatter().date(from: $0) ?? Day.date(String($0.prefix(10))) }) {
                                Text("Dernier push \(d.formatted(.relative(presentation: .named)))")
                            }
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let url = URL(string: repo.htmlURL) {
                        Link(destination: url) { Label("Ouvrir sur GitHub", systemImage: "arrow.up.right.square") }
                            .buttonStyle(.bordered)
                    }
                }

                if !repo.trafficAvailable {
                    Label("GitHub n'a pas donné accès au trafic de ce dépôt (droits insuffisants).", systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.orange)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    KPI(title: "Vues", value: t.views, icon: "eye.fill", tint: .blue, sub: period.label)
                    KPI(title: "Visiteurs uniques", value: t.uniqueViews, icon: "person.2.fill", tint: .indigo, sub: "somme jour par jour")
                    KPI(title: "Clones", value: t.clones, icon: "arrow.down.doc.fill", tint: .green, sub: "\(t.uniqueClones.fr) cloneurs uniques")
                    KPI(title: "Étoiles", value: repo.stars, icon: "star.fill", tint: .orange)
                    KPI(title: "Forks", value: repo.forks, icon: "tuningfork", tint: .purple)
                    KPI(title: "Téléchargements", value: repo.downloads, icon: "square.and.arrow.down.fill", tint: .teal, sub: "fichiers de releases")
                    KPI(title: "Commits", value: repo.commits, icon: "point.topleft.down.to.point.bottomright.curvepath.fill", tint: .orange, sub: "total")
                    KPI(title: "Contributeurs", value: repo.contributors, icon: "person.3.fill", tint: .pink)
                    KPI(title: "Pull requests", value: repo.openPulls, icon: "arrow.triangle.pull", tint: .mint, sub: "ouvertes")
                    KPI(title: "Issues", value: repo.openIssues, icon: "exclamationmark.circle.fill", tint: .red, sub: "ouvertes")
                }

                HStack(alignment: .top, spacing: 12) {
                    Card(title: "Visites par jour") {
                        TrafficChart(points: points, total: \.views, unique: \.uniqueViews,
                                     totalLabel: "Vues", uniqueLabel: "Visiteurs uniques", color: .blue)
                    }
                    Card(title: "Clones par jour") {
                        TrafficChart(points: points, total: \.clones, unique: \.uniqueClones,
                                     totalLabel: "Clones", uniqueLabel: "Cloneurs uniques", color: .green)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    Card(title: "D'où viennent les visiteurs", subtitle: "14 derniers jours") {
                        RankList(rows: repo.referrers.prefix(10).map {
                            RankRow(id: $0.referrer, label: $0.referrer, value: $0.count, secondary: $0.uniques)
                        }, tint: .blue)
                    }
                    Card(title: "Pages les plus vues", subtitle: "14 derniers jours") {
                        RankList(rows: repo.paths.prefix(10).map {
                            RankRow(id: $0.path, label: $0.path, detail: $0.title, value: $0.count, secondary: $0.uniques)
                        }, tint: .indigo)
                    }
                }

                Card(title: "Commits par semaine", subtitle: weeks.isEmpty ? "GitHub prépare ces chiffres : actualisez dans une minute." : nil) {
                    CommitsChart(weeks: weeks)
                }

                if starPoints.count >= 2 {
                    Card(title: "Étoiles au fil du temps", subtitle: "Relevé à chaque actualisation") {
                        Chart(starPoints, id: \.0) { p in
                            LineMark(x: .value("Jour", p.0, unit: .day), y: .value("Étoiles", p.1))
                                .foregroundStyle(.orange)
                                .interpolationMethod(.monotone)
                            AreaMark(x: .value("Jour", p.0, unit: .day), y: .value("Étoiles", p.1))
                                .foregroundStyle(Color.orange.opacity(0.12))
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 160)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
