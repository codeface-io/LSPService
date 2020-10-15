import Vapor
import Foundation

public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    app.logger.logLevel = .warning
    
    app.http.server.configuration.serverName = "Language Service Host"
    
    try registerRoutes(on: app)
    
    ConsoleInputProcessing.start(app: app)
}
