import Vapor

func routes(_ app: Application) throws {
    app.get("healthz", use: HealthController().health)
    app.get("api", "v1", "keys", use: KeysAggregationController().index)
    app.on(.GET, "api", "v1", "admin", "**", use: AdminProxyController().proxy)
    app.on(.POST, "api", "v1", "admin", "**", use: AdminProxyController().proxy)
    app.on(.PUT, "api", "v1", "admin", "**", use: AdminProxyController().proxy)
    app.on(.PATCH, "api", "v1", "admin", "**", use: AdminProxyController().proxy)
    app.on(.DELETE, "api", "v1", "admin", "**", use: AdminProxyController().proxy)
}
