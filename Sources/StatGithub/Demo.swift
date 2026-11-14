import Foundation

/// Données fictives pour essayer l'app sans compte GitHub.
enum Demo {
    struct RNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    static func make() -> AppData {
        var rng = RNG(state: 2024)
        let owner = "demo-user"
        let specs: [(String, String, String, Double, Bool)] = [
            ("mon-super-outil", "Un outil en ligne de commande très pratique", "Swift", 60, false),
            ("site-portfolio", "Mon site personnel", "HTML", 38, false),
            ("app-meteo", "Application météo minimaliste", "Swift", 26, false),
            ("convertisseur-images", "Convertit des images par lots", "Python", 18, false),
            ("bot-discord", "Un petit bot pour mon serveur", "JavaScript", 12, false),
            ("notes-de-cours", "Mes notes, en Markdown", "Markdown", 7, false),
            ("jeu-snake", "Le classique, en 200 lignes", "JavaScript", 5, false),
            ("projet-prive", "Brouillon non publié", "Swift", 2, true),
        ]
        let cal = Day.utc
        let today = cal.startOfDay(for: Date())
        var repos: [String: RepoRecord] = [:]

        for (name, desc, lang, base, priv) in specs {
            var rec = RepoRecord(
                fullName: "\(owner)/\(name)", name: name, description: desc, language: lang,
                isPrivate: priv, htmlURL: "https://github.com/\(owner)/\(name)",
                stars: Int(base * 2.4) + Int.random(in: 0...9, using: &rng),
                forks: Int(base / 5) + Int.random(in: 0...3, using: &rng),
                openIssues: Int.random(in: 0...6, using: &rng))
            rec.commits = Int(base * 6) + Int.random(in: 5...60, using: &rng)
            rec.contributors = max(1, Int(base / 12)) + Int.random(in: 0...2, using: &rng)
            rec.openPulls = Int.random(in: 0...3, using: &rng)
            rec.pushedAt = Day.string(today)
            for w in 0..<52 {
                let ws = cal.date(byAdding: .day, value: -7 * w, to: today)!
                rec.weeklyCommits[Day.string(ws)] = Int(Double.random(in: 0...1, using: &rng) * base / 6) + (w < 10 ? 2 : 0)
            }
            let spike = Int.random(in: 20...80, using: &rng)
            for back in 0..<120 {
                let date = cal.date(byAdding: .day, value: -back, to: today)!
                let weekday = cal.component(.weekday, from: date)
                let weekend = (weekday == 1 || weekday == 7) ? 0.6 : 1.0
                let growth = 1.0 + Double(120 - back) / 240.0
                var views = base * Double.random(in: 0.5...1.5, using: &rng) * weekend * growth
                if abs(back - spike) < 2 { views *= 3 }
                let v = Int(views)
                let c = Int(views * Double.random(in: 0.3...0.7, using: &rng))
                rec.daily[Day.string(date)] = DayStat(
                    views: v, uniqueViews: max(v > 0 ? 1 : 0, Int(Double(v) * 0.45)),
                    clones: c, uniqueClones: max(c > 0 ? 1 : 0, Int(Double(c) * 0.5)))
                if back % 6 == 0 {
                    rec.starHistory[Day.string(date)] = max(0, rec.stars - back / 4)
                }
            }
            let total = Int(base * 14)
            rec.referrers = [
                Referrer(referrer: "Google", count: total * 4 / 10, uniques: total * 3 / 10),
                Referrer(referrer: "github.com", count: total * 25 / 100, uniques: total / 8),
                Referrer(referrer: "reddit.com", count: total / 10, uniques: total / 14),
                Referrer(referrer: "news.ycombinator.com", count: total / 14, uniques: total / 20),
                Referrer(referrer: "Twitter", count: total / 20, uniques: total / 30),
                Referrer(referrer: "DuckDuckGo", count: total / 25, uniques: total / 40),
            ].filter { $0.count > 0 }
            rec.paths = [
                PopularPath(path: "/\(owner)/\(name)", title: "\(owner)/\(name): \(desc)", count: total * 6 / 10, uniques: total / 3),
                PopularPath(path: "/\(owner)/\(name)/releases", title: "Releases · \(owner)/\(name)", count: total / 5, uniques: total / 8),
                PopularPath(path: "/\(owner)/\(name)/issues", title: "Issues · \(owner)/\(name)", count: total / 12, uniques: total / 20),
            ].filter { $0.count > 0 }
            rec.downloads = Int(base * 11) + Int.random(in: 0...40, using: &rng)
            repos[rec.fullName] = rec
        }
        return AppData(login: owner, lastRefresh: Date(), repos: repos)
    }
}
