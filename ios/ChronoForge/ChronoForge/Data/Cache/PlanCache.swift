import Foundation

/// Caches the last plan response to disk so the app can show stale data during network failures.
actor PlanCache {
    static let shared = PlanCache()

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("last_plan.json")
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func save(_ plan: PlanResponse) {
        guard let data = try? encoder.encode(plan) else { return }
        try? data.write(to: fileURL)
    }

    func load() -> PlanResponse? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(PlanResponse.self, from: data)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
