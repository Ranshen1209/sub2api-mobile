import Foundation

public enum URLBuilder {
    public static func buildRequestURL(baseURL: String, path: String) throws -> URL {
        var normalizedBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalizedBase.hasSuffix("/") { normalizedBase.removeLast() }

        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        for prefix in ["/api/v1", "/api"] {
            if normalizedBase.hasSuffix(prefix), normalizedPath.hasPrefix("\(prefix)/") {
                let baseWithoutPrefix = String(normalizedBase.dropLast(prefix.count))
                guard let url = URL(string: baseWithoutPrefix + normalizedPath) else {
                    throw APIClientError.invalidURL
                }
                return url
            }
        }

        guard let url = URL(string: normalizedBase + normalizedPath) else {
            throw APIClientError.invalidURL
        }
        return url
    }
}
