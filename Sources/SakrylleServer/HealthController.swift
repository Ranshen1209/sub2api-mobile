import Vapor

struct HealthResponse: Content {
    let ok: Bool
    let upstreamConfigured: Bool
    let apiKeyConfigured: Bool
}

struct HealthController {
    func health(req: Request) async throws -> HealthResponse {
        let config = req.application.sakrylleConfig
        return HealthResponse(
            ok: true,
            upstreamConfigured: !config.upstreamBaseURL.isEmpty,
            apiKeyConfigured: !config.adminAPIKey.isEmpty
        )
    }
}
