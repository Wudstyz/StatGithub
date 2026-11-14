import Foundation

enum GitHubFailure: LocalizedError {
    case unauthorized
    case rateLimited
    case notAccessible
    case other(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Jeton refusé par GitHub (invalide, expiré ou sans droits)."
        case .rateLimited: return "Limite de requêtes GitHub atteinte. Réessayez dans une heure."
        case .notAccessible: return "Accès refusé par GitHub pour cette ressource."
        case .other(let m): return m
        }
    }
}

// MARK: - Réponses de l'API

struct RepoDTO: Decodable {
    let fullName: String
    let name: String
    let description: String?
    let language: String?
    let isPrivate: Bool
    let htmlURL: String
    let stars: Int
    let forks: Int
    let openIssues: Int
    let fork: Bool
    let archived: Bool
    let pushedAt: String?

    enum CodingKeys: String, CodingKey {
        case pushedAt = "pushed_at"
        case fullName = "full_name", name, description, language
        case isPrivate = "private", htmlURL = "html_url"
        case stars = "stargazers_count", forks = "forks_count"
        case openIssues = "open_issues_count", fork, archived
    }
}

struct TrafficDTO: Decodable {
    struct Entry: Decodable {
        let timestamp: String
        let count: Int
        let uniques: Int
    }
    let views: [Entry]?
    let clones: [Entry]?
}

struct ReferrerDTO: Decodable {
    let referrer: String
    let count: Int
    let uniques: Int
}

struct PathDTO: Decodable {
    let path: String
    let title: String
    let count: Int
    let uniques: Int
}

struct ReleaseDTO: Decodable {
    struct Asset: Decodable {
        let downloadCount: Int
        enum CodingKeys: String, CodingKey { case downloadCount = "download_count" }
    }
    let assets: [Asset]
}

struct WeekDTO: Decodable {
    let week: Int
    let total: Int
}

struct UserDTO: Decodable { let login: String }

/// Tout ce qu'on récupère pour un dépôt en une passe.
struct RepoFetch {
    var info: RepoDTO
    var views: TrafficDTO?
    var clones: TrafficDTO?
    var referrers: [ReferrerDTO]?
    var paths: [PathDTO]?
    var downloads: Int
    var commits: Int?
    var contributors: Int?
    var openPulls: Int?
    var weeks: [WeekDTO]?
}

// MARK: - Client

actor GitHubClient {
    private let token: String
    private let session = URLSession(configuration: .ephemeral)
    private(set) var rateLimited = false
    private(set) var unauthorized = false

    init(token: String) { self.token = token }

    private func response(_ path: String, query: [URLQueryItem] = []) async throws -> (Data, HTTPURLResponse) {
        var c = URLComponents(string: "https://api.github.com" + path)!
        if !query.isEmpty { c.queryItems = query }
        var req = URLRequest(url: c.url!)
        req.timeoutInterval = 30
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        req.setValue("StatGithub", forHTTPHeaderField: "User-Agent")
        let (d, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw GitHubFailure.other("Réponse invalide de GitHub.") }
        switch http.statusCode {
        case 200..<300:
            return (d, http)
        case 401:
            unauthorized = true
            throw GitHubFailure.unauthorized
        case 403, 429:
            if http.statusCode == 429 || http.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" {
                rateLimited = true
                throw GitHubFailure.rateLimited
            }
            throw GitHubFailure.notAccessible
        case 404:
            throw GitHubFailure.notAccessible
        default:
            throw GitHubFailure.other("Erreur GitHub (code \(http.statusCode)).")
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, _ path: String, query: [URLQueryItem] = []) async throws -> T {
        let (d, _) = try await response(path, query: query)
        return try JSONDecoder().decode(T.self, from: d)
    }

    /// Variante qui ignore les erreurs d'accès (le drapeau rateLimited reste mémorisé).
    private func tryDecode<T: Decodable>(_ type: T.Type, _ path: String, query: [URLQueryItem] = []) async -> T? {
        try? await decode(type, path, query: query)
    }

    /// Nombre total d'éléments d'une liste paginée, sans tout télécharger
    /// (on lit le numéro de la dernière page avec 1 élément par page).
    private func count(_ path: String, extra: [URLQueryItem] = []) async -> Int? {
        guard let (d, http) = try? await response(path, query: [URLQueryItem(name: "per_page", value: "1")] + extra) else { return nil }
        if let link = http.value(forHTTPHeaderField: "Link"),
           let r = link.range(of: #"page=\d+>; rel="last""#, options: .regularExpression) {
            return Int(link[r].filter(\.isNumber))
        }
        return (try? JSONSerialization.jsonObject(with: d) as? [Any])?.count
    }

    func user() async throws -> String {
        try await decode(UserDTO.self, "/user").login
    }

    /// Tous les dépôts dont l'utilisateur est propriétaire (publics et privés).
    func repos() async throws -> [RepoDTO] {
        var all: [RepoDTO] = []
        var page = 1
        while page <= 30 {
            let q = [URLQueryItem(name: "per_page", value: "100"),
                     URLQueryItem(name: "page", value: String(page)),
                     URLQueryItem(name: "affiliation", value: "owner"),
                     URLQueryItem(name: "sort", value: "pushed")]
            let chunk = try await decode([RepoDTO].self, "/user/repos", query: q)
            all += chunk
            if chunk.count < 100 { break }
            page += 1
        }
        return all
    }

    func fetch(_ r: RepoDTO) async -> RepoFetch {
        let p = "/repos/\(r.fullName)"
        async let v = tryDecode(TrafficDTO.self, p + "/traffic/views")
        async let c = tryDecode(TrafficDTO.self, p + "/traffic/clones")
        async let ref = tryDecode([ReferrerDTO].self, p + "/traffic/popular/referrers")
        async let pa = tryDecode([PathDTO].self, p + "/traffic/popular/paths")
        async let rel = tryDecode([ReleaseDTO].self, p + "/releases", query: [URLQueryItem(name: "per_page", value: "100")])
        async let nCommits = count(p + "/commits")
        async let nContrib = count(p + "/contributors", extra: [URLQueryItem(name: "anon", value: "1")])
        async let nPulls = count(p + "/pulls", extra: [URLQueryItem(name: "state", value: "open")])
        async let weeks = tryDecode([WeekDTO].self, p + "/stats/commit_activity")
        let releases = await rel ?? []
        let downloads = releases.reduce(0) { $0 + $1.assets.reduce(0) { $0 + $1.downloadCount } }
        return RepoFetch(info: r, views: await v, clones: await c,
                         referrers: await ref, paths: await pa, downloads: downloads,
                         commits: await nCommits, contributors: await nContrib,
                         openPulls: await nPulls, weeks: await weeks)
    }
}
