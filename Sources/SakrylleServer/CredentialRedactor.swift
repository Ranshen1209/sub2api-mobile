import SakrylleShared

enum CredentialRedactor {
    static func redact(_ value: JSONValue) -> JSONValue {
        switch value {
        case .array(let items):
            return .array(items.map(redact))
        case .object(let object):
            var next: [String: JSONValue] = [:]
            for (key, entry) in object {
                if key == "credentials" {
                    next[key] = .object(["redacted": .bool(true)])
                } else {
                    next[key] = redact(entry)
                }
            }
            return .object(next)
        default:
            return value
        }
    }
}
