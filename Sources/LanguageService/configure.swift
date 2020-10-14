import Vapor
import Foundation

public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    app.logger.logLevel = .warning
    
    app.http.server.configuration.serverName = "Language Service Host"
    
    try registerRoutes(on: app)
    
    startProcessingConsoleInput(app: app)
}

func startProcessingConsoleInput(app: Application) {
    app.console.output("👋🏻 Type to configure the Language Service:\n⌨️ <language> [<executable path>]\t\tget/set LSP server executable for language")
    let languages = languagesLowercased.map { $0.capitalized }.joined(separator: ", ")
    app.console.output("🗣 Available languages: \(languages)".consoleText())
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
    var argumentsToProcess = arguments(fromInput: input)

    guard argumentsToProcess.count > 0 else {
        console.output("🛑 Could not recognize command".consoleText())
        return
    }
    
    let language = argumentsToProcess.removeFirst()
    
    guard isAvailable(language: language) else {
        console.output("🛑 Language \"\(language.capitalized)\" not supported".consoleText())
        return
    }
    
    guard argumentsToProcess.count > 0 else {
        console.output("✅ \(language.capitalized) is a supported language".consoleText())
        return
    }
    
    let executablePath = argumentsToProcess.removeFirst()
    
    console.output("✅ Will set language server executable path for \(language.capitalized) to \"\(executablePath)\"".consoleText())
    
    if argumentsToProcess.count > 0 {
        console.output("⚠️ Ignoring unexpected remaining arguments: \(argumentsToProcess)".consoleText())
    }
}

func arguments(fromInput input: String) -> [String] {
    input.components(separatedBy: .whitespaces).filter { $0.count > 0 }
}
