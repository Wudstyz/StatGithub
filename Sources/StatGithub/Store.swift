import Foundation
import Observation

@MainActor
@Observable
final class Store {
    var data = AppData()
    var isDemo = false
    var connected = false
    var isLoading = false
    var progress = 0.0
    var errorMessage: String?
    var notice: String?

    private let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StatGithub", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("historique.json")
    }()

    init() {
        loadFromDisk()
        connected = Keychain.read() != nil
        if CommandLine.arguments.contains("--demo") { enterDemo() }
    }

    // MARK: Persistance

    private func loadFromDisk() {
        guard let d = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(AppData.self, from: d) else { return }
        data = decoded
    }

    private func save() {
        guard !isDemo else { return }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard let d = try? enc.encode(data) else { return }
        try? d.write(to: fileURL, options: .atomic)
    }

    // MARK: Connexion

    func connect(token: String) async {
        let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        errorMessage = nil
        isLoading = true
        let login: String
        do {
            login = try await GitHubClient(token: t).user()
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return
        }
        isLoading = false
        Keychain.save(t)
        if data.login != login { data = AppData() }
        data.login = login
        isDemo = false
        connected = true
        loadFromDiskIfSameUser()
        await refresh()
    }

    private func loadFromDiskIfSameUser() {
        guard data.repos.isEmpty, let d = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(AppData.self, from: d),
              decoded.login == data.login else { return }
        data = decoded
    }

    func disconnect() {
        Keychain.delete()
        connected = false
        errorMessage = nil
    }

    func eraseHistory() {
        try? FileManager.default.removeItem(at: fileURL)
        data = AppData()
    }

    func enterDemo() {
        data = Demo.make()
        isDemo = true
        errorMessage = nil
    }

    func exitDemo() {
        isDemo = false
        data = AppData()
        loadFromDisk()
    }

    // MARK: Actualisation

    func refresh() async {
        if isDemo { return }
        guard let token = Keychain.read() else { connected = false; return }
        guard !isLoading else { return }
        isLoading = true
        progress = 0
        errorMessage = nil
        notice = nil
        defer { isLoading = false; progress = 0 }

        let client = GitHubClient(token: token)
        do {
            data.login = try await client.user()
            let repos = try await client.repos().filter { !$0.fork }
            var done = 0
            var noTraffic = 0
            var seen = Set<String>()
            var index = 0
            while index < repos.count {
                let chunk = Array(repos[index..<min(index + 6, repos.count)])
                index += 6
                let results = await withTaskGroup(of: RepoFetch.self) { group -> [RepoFetch] in
                    for r in chunk { group.addTask { await client.fetch(r) } }
                    var out: [RepoFetch] = []
                    for await f in group { out.append(f) }
                    return out
                }
                for f in results {
                    merge(f)
                    seen.insert(f.info.fullName)
                    if f.views == nil && f.clones == nil { noTraffic += 1 }
                    done += 1
                }
                progress = Double(done) / Double(max(repos.count, 1))
            }
            // Dépôts supprimés ou transférés : on les retire de la liste.
            for key in data.repos.keys where !seen.contains(key) { data.repos[key] = nil }
            data.lastRefresh = Date()
            save()
            if await client.rateLimited {
                errorMessage = GitHubFailure.rateLimited.localizedDescription
            } else if await client.unauthorized {
                errorMessage = GitHubFailure.unauthorized.localizedDescription
            } else if noTraffic > 0 && noTraffic == repos.count {
                errorMessage = "GitHub refuse l'accès au trafic. Le jeton doit avoir le droit « repo » (jeton classique)."
            } else if noTraffic > 0 {
                notice = "Trafic indisponible pour \(noTraffic) dépôt(s) (droits insuffisants)."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func merge(_ f: RepoFetch) {
        let i = f.info
        var rec = data.repos[i.fullName] ?? RepoRecord(
            fullName: i.fullName, name: i.name, description: i.description, language: i.language,
            isPrivate: i.isPrivate, htmlURL: i.htmlURL, stars: i.stars, forks: i.forks, openIssues: i.openIssues)
        rec.name = i.name
        rec.description = i.description
        rec.language = i.language
        rec.isPrivate = i.isPrivate
        rec.htmlURL = i.htmlURL
        rec.stars = i.stars
        rec.forks = i.forks
        rec.pushedAt = i.pushedAt
        if let n = f.openPulls { rec.openPulls = n }
        // open_issues_count de GitHub inclut les pull requests.
        rec.openIssues = max(0, i.openIssues - rec.openPulls)
        if let n = f.commits { rec.commits = n }
        if let n = f.contributors { rec.contributors = n }
        for w in f.weeks ?? [] {
            rec.weeklyCommits[Day.string(Date(timeIntervalSince1970: TimeInterval(w.week)))] = w.total
        }
        rec.downloads = f.downloads
        rec.trafficAvailable = (f.views != nil || f.clones != nil)
        for e in f.views?.views ?? [] {
            let k = String(e.timestamp.prefix(10))
            rec.daily[k, default: DayStat()].views = e.count
            rec.daily[k, default: DayStat()].uniqueViews = e.uniques
        }
        for e in f.clones?.clones ?? [] {
            let k = String(e.timestamp.prefix(10))
            rec.daily[k, default: DayStat()].clones = e.count
            rec.daily[k, default: DayStat()].uniqueClones = e.uniques
        }
        if let r = f.referrers { rec.referrers = r.map { Referrer(referrer: $0.referrer, count: $0.count, uniques: $0.uniques) } }
        if let p = f.paths { rec.paths = p.map { PopularPath(path: $0.path, title: $0.title, count: $0.count, uniques: $0.uniques) } }
        rec.starHistory[Day.today] = i.stars
        data.repos[i.fullName] = rec
    }

    // MARK: Agrégats

    var repos: [RepoRecord] { Array(data.repos.values) }

    /// Liste des jours (UTC) couverts par la période, du plus ancien au plus récent.
    func dayList(_ period: Period) -> [String] {
        let cal = Day.utc
        let end = cal.startOfDay(for: Date())
        var start: Date
        if let n = period.days {
            start = cal.date(byAdding: .day, value: -(n - 1), to: end)!
        } else {
            let earliest = data.repos.values.flatMap { $0.daily.keys }.min().flatMap(Day.date)
            start = earliest ?? cal.date(byAdding: .day, value: -13, to: end)!
        }
        if start > end { start = end }
        var out: [String] = []
        var d = start
        while d <= end {
            out.append(Day.string(d))
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return out
    }

    func series(_ list: [RepoRecord], _ period: Period) -> [DayPoint] {
        dayList(period).map { key in
            var p = DayPoint(day: Day.date(key) ?? Date())
            for r in list {
                guard let s = r.daily[key] else { continue }
                p.views += s.views
                p.uniqueViews += s.uniqueViews
                p.clones += s.clones
                p.uniqueClones += s.uniqueClones
            }
            return p
        }
    }

    func totals(_ list: [RepoRecord], _ period: Period) -> Totals {
        let pts = series(list, period)
        return Totals(views: pts.reduce(0) { $0 + $1.views },
                      uniqueViews: pts.reduce(0) { $0 + $1.uniqueViews },
                      clones: pts.reduce(0) { $0 + $1.clones },
                      uniqueClones: pts.reduce(0) { $0 + $1.uniqueClones })
    }

    func rows(_ period: Period) -> [RepoRow] {
        repos.map { r in
            let t = totals([r], period)
            return RepoRow(id: r.fullName, name: r.name, isPrivate: r.isPrivate, views: t.views,
                           uniqueViews: t.uniqueViews, clones: t.clones, stars: r.stars,
                           forks: r.forks, downloads: r.downloads, commits: r.commits)
        }
    }

    /// Commits par semaine (52 dernières semaines conservées), restreints à la période.
    func weekly(_ list: [RepoRecord], _ period: Period) -> [WeekPoint] {
        let first = dayList(period).first.flatMap(Day.date) ?? Date.distantPast
        let cutoff = Day.utc.date(byAdding: .day, value: -6, to: first) ?? first
        var acc: [String: Int] = [:]
        for r in list { for (k, v) in r.weeklyCommits { acc[k, default: 0] += v } }
        return acc.compactMap { k, v -> WeekPoint? in
            guard let d = Day.date(k), d >= cutoff else { return nil }
            return WeekPoint(day: d, commits: v)
        }.sorted { $0.day < $1.day }
    }

    func topReferrers(_ list: [RepoRecord]) -> [Referrer] {
        var acc: [String: Referrer] = [:]
        for r in list {
            for x in r.referrers {
                var cur = acc[x.referrer] ?? Referrer(referrer: x.referrer, count: 0, uniques: 0)
                cur.count += x.count
                cur.uniques += x.uniques
                acc[x.referrer] = cur
            }
        }
        return acc.values.sorted { $0.count > $1.count }
    }

    func topPaths(_ list: [RepoRecord]) -> [PopularPath] {
        var out: [PopularPath] = []
        for r in list {
            for p in r.paths {
                out.append(PopularPath(path: p.path, title: p.title, count: p.count, uniques: p.uniques))
            }
        }
        return out.sorted { $0.count > $1.count }
    }

    // MARK: Export

    func csv() -> String {
        var lines = ["jour,depot,vues,visiteurs_uniques,clones,cloneurs_uniques"]
        for r in repos.sorted(by: { $0.fullName < $1.fullName }) {
            for (day, s) in r.daily.sorted(by: { $0.key < $1.key }) {
                lines.append("\(day),\(r.fullName),\(s.views),\(s.uniqueViews),\(s.clones),\(s.uniqueClones)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
