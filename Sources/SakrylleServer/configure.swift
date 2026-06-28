import SakrylleShared
import Vapor

public func configure(_ app: Application) throws {
    let config = AppConfig.load(app.environment)
    app.storage[AppConfigKey.self] = config
    app.storage[UpstreamHTTPClientKey.self] = VaporUpstreamHTTPClient()
    app.http.server.configuration.port = config.port

    let cors = CORSMiddleware.Configuration(
        allowedOrigin: config.allowOrigin == "*" ? .all : .custom(config.allowOrigin),
        allowedMethods: [.GET, .POST, .PUT, .PATCH, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, "Idempotency-Key", "x-api-key"],
        allowCredentials: true
    )
    app.middleware.use(CORSMiddleware(configuration: cors))
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.routes.defaultMaxBodySize = "2mb"
    try routes(app)
}
