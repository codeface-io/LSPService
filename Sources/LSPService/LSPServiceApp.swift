import Vapor
import Foundation
import SwiftyToolz

public class LSPServiceApp: LogObserver {
    
    // MARK: - Life Cycle
    
    public init() throws {
        vaporApp = try Self.makeVaporApp()
        configureVaporApp()
        try RouteConfigurator().registerRoutes(on: vaporApp)
        Log.shared.minimumLevel = .off
        Log.shared.add(observer: self)
        ServerExecutableConfigs.preload()
        Self.startProcessingConsoleInput(app: vaporApp)
    }
    
    deinit { vaporApp.shutdown() }
    
    // MARK: - CLI

    private static func startProcessingConsoleInput(app: Application) {
        app.console.output(ConsoleInputProcessor.initialOutput().consoleText())
        processNextConsoleInput(app: app)
    }

    private static func processNextConsoleInput(app: Application) {
        app.console.output(ConsoleInputProcessor.prompt.consoleText(), newLine: false)
        
        let eventLoop = app.eventLoopGroup.next()
        
        let didReadConsole = app.threadPool.runIfActive(eventLoop: eventLoop) {
            app.console.input()
        }
        
        didReadConsole.whenSuccess { input in
            app.console.output(ConsoleInputProcessor.response(forInput: input).consoleText())
            processNextConsoleInput(app: app)
        }
        
        didReadConsole.whenFailure { log($0) }
    }
    
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
    
    private let vaporApp: Application
}
