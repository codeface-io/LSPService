import Vapor
import Foundation
import SwiftyToolz

public class LSPServiceApp: LogObserver {
    
    // MARK: - Life Cycle
    
    public init(useTestEnvironment: Bool = false) throws {
        vaporApp = useTestEnvironment ? Application(.testing) : try Self.makeVaporApp()
        configureVaporApp()
        try RouteConfigurator().registerRoutes(on: vaporApp)
        Log.shared.minimumLevel = .off
        Log.shared.add(observer: self)
        ServerExecutableConfigs.preload()
    }
    
    deinit { vaporApp.shutdown() }
    
    // MARK: - Logging
    
    public func receive(_ entry: Log.Entry) {
        switch entry.level {
        case .info:
            vaporApp.logger.info("\(entry.description)")
        case .warning:
            vaporApp.logger.warning("\(entry.description)")
        case .error:
            vaporApp.logger.error("\(entry.description)")
        case .off:
            break
        }
    }
    
    // MARK: - Vapor App
    
    public func run() throws { try vaporApp.run() }
    
    private static func makeVaporApp() throws -> Application {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        return Application(env)
    }
    
    private func configureVaporApp() {
        // uncomment to serve files from /Public folder
        // vaporApp.middleware.use(FileMiddleware(publicDirectory: vaporApp.directory.publicDirectory))
        vaporApp.http.server.configuration.serverName = "LSPService"
        vaporApp.logger.logLevel = .debug
    }
    
    internal let vaporApp: Application
}
