import Foundation

// MARK: - Données stockées (une entrée par jour, conservées au-delà des 14 jours de GitHub)

struct DayStat: Codable, Hashable {
    var views = 0
    var uniqueViews = 0
    var clones = 0
    var uniqueClones = 0
}

struct Referrer: Codable, Hashable, Identifiable {
    var referrer: String
    var count: Int
    var uniques: Int
    var id: String { referrer }
}

struct PopularPath: Codable, Hashable, Identifiable {
    var path: String
    var title: String
    var count: Int
    var uniques: Int
    var id: String { path }
}

struct RepoRecord: Codable, Hashable, Identifiable {
    var fullName: String
    var name: String
    var description: String?
    var language: String?
    var isPrivate: Bool
    var htmlURL: String
    var stars: Int
    var forks: Int
    var openIssues: Int            // issues ouvertes (hors pull requests)
    var trafficAvailable = true
    var daily: [String: DayStat] = [:]
    var referrers: [Referrer] = []
    var paths: [PopularPath] = []
    var downloads = 0
    var starHistory: [String: Int] = [:]
    var commits = 0                // total des commits de la branche par défaut
    var contributors = 0
    var openPulls = 0
    var pushedAt: String?
    var weeklyCommits: [String: Int] = [:]   // début de semaine (jour) -> commits
    var id: String { fullName }

    init(fullName: String, name: String, description: String?, language: String?, isPrivate: Bool,
         htmlURL: String, stars: Int, forks: Int, openIssues: Int) {
        self.fullName = fullName; self.name = name; self.description = description
        self.language = language; self.isPrivate = isPrivate; self.htmlURL = htmlURL
        self.stars = stars; self.forks = forks; self.openIssues = openIssues
    }

    // Lecture tolérante : un ancien historique (sans les nouveaux champs) reste lisible.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        fullName = try c.decode(String.self, forKey: .fullName)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        language = try c.decodeIfPresent(String.self, forKey: .language)
        isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        htmlURL = try c.decodeIfPresent(String.self, forKey: .htmlURL) ?? ""
        stars = try c.decodeIfPresent(Int.self, forKey: .stars) ?? 0
        forks = try c.decodeIfPresent(Int.self, forKey: .forks) ?? 0
        openIssues = try c.decodeIfPresent(Int.self, forKey: .openIssues) ?? 0
        trafficAvailable = try c.decodeIfPresent(Bool.self, forKey: .trafficAvailable) ?? true
        daily = try c.decodeIfPresent([String: DayStat].self, forKey: .daily) ?? [:]
        referrers = try c.decodeIfPresent([Referrer].self, forKey: .referrers) ?? []
        paths = try c.decodeIfPresent([PopularPath].self, forKey: .paths) ?? []
        downloads = try c.decodeIfPresent(Int.self, forKey: .downloads) ?? 0
        starHistory = try c.decodeIfPresent([String: Int].self, forKey: .starHistory) ?? [:]
        commits = try c.decodeIfPresent(Int.self, forKey: .commits) ?? 0
        contributors = try c.decodeIfPresent(Int.self, forKey: .contributors) ?? 0
        openPulls = try c.decodeIfPresent(Int.self, forKey: .openPulls) ?? 0
        pushedAt = try c.decodeIfPresent(String.self, forKey: .pushedAt)
        weeklyCommits = try c.decodeIfPresent([String: Int].self, forKey: .weeklyCommits) ?? [:]
    }
}

struct WeekPoint: Identifiable {
    var day: Date
    var commits: Int
    var id: Date { day }
}

struct AppData: Codable {
    var login: String?
    var lastRefresh: Date?
    var repos: [String: RepoRecord] = [:]
}

// MARK: - Périodes et jours

enum Period: String, CaseIterable, Identifiable {
    case d7 = "7 j", d14 = "14 j", d30 = "30 j", d90 = "90 j", all = "Tout"
    var id: String { rawValue }
    var days: Int? {
        switch self {
        case .d7: return 7
        case .d14: return 14
        case .d30: return 30
        case .d90: return 90
        case .all: return nil
        }
    }
    var label: String {
        switch self {
        case .all: return "depuis le début de l'historique"
        default: return "sur \(days ?? 0) jours"
        }
    }
}

enum Day {
    static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = utc
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func string(_ d: Date) -> String { formatter.string(from: d) }
    static func date(_ s: String) -> Date? { formatter.date(from: s) }
    static var today: String { string(Date()) }
}

// MARK: - Agrégats

struct DayPoint: Identifiable {
    var day: Date
    var views = 0
    var uniqueViews = 0
    var clones = 0
    var uniqueClones = 0
    var id: Date { day }
}

struct Totals {
    var views = 0
    var uniqueViews = 0
    var clones = 0
    var uniqueClones = 0
}

struct RepoRow: Identifiable, Hashable {
    var id: String
    var name: String
    var isPrivate: Bool
    var views: Int
    var uniqueViews: Int
    var clones: Int
    var stars: Int
    var forks: Int
    var downloads: Int
    var commits: Int
}

extension Int {
    var fr: String { self.formatted(.number) }
}
