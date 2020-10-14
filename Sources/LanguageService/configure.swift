import Vapor
import Foundation

public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    app.http.server.configuration.serverName = "Language Service Host"
    
    try registerRoutes(on: app)
    
    startProcessingConsoleInput(app: app)
}

func startProcessingConsoleInput(app: Application) {
    app.console.output("👋🏻 Type in commands to configure the language service ⌨️ ...")
    processNextConsoleInput(app: app)
}

func processNextConsoleInput(app: Application) {
    let eventLoop = app.eventLoopGroup.next()
    
    let didReadConsole = app.threadPool.runIfActive(eventLoop: eventLoop) {
        app.console.input()
    }
    
    didReadConsole.whenSuccess { input in
        process(input: input, from: app.console)
        processNextConsoleInput(app: app)
    }
    
    didReadConsole.whenFailure { error in
        app.console.output("Error: \(error.localizedDescription)".consoleText())
    }
}

func process(input: String, from console: Console) {
    console.output("You typed \(input)".consoleText())
}
